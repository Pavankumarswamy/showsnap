import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../widgets/web_video_player.dart'
    if (dart.library.html) '../widgets/web_video_player_web.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/models/movie_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/showsnap_toast.dart';
import '../../../core/widgets/tappable_scale.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _movieDetailProvider =
    FutureProvider.family<MovieModel?, String>((ref, movieId) {
  return ref.watch(databaseServiceProvider).getMovie(movieId);
});

final _userBookingsForMovieProvider =
    FutureProvider.family<List<BookingModel>, String>((ref, movieId) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return [];
  final db = ref.watch(databaseServiceProvider);
  final all = await db.getUserBookings(uid);
  return all
      .where((b) =>
          b.movieId == movieId &&
          b.status == BookingStatus.redeemed)
      .toList();
});

final _userMovieRatingProvider =
    FutureProvider.family<double, String>((ref, movieId) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return 0;
  return ref.watch(databaseServiceProvider).getUserMovieRating(movieId, uid);
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class MovieDetailScreen extends ConsumerWidget {
  final String movieId;
  final String? heroTag;
  const MovieDetailScreen({super.key, required this.movieId, this.heroTag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movieAsync = ref.watch(_movieDetailProvider(movieId));
    return movieAsync.when(
      loading: () => Scaffold(
        backgroundColor: ShowSnapColors.grey100,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Shimmer.fromColors(
                  baseColor: ShowSnapColors.grey300,
                  highlightColor: ShowSnapColors.grey100,
                  child: Container(color: ShowSnapColors.grey300),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Center(
                  child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              )),
            ),
          ],
        ),
      ),
      error: (e, _) => Scaffold(
          body: Center(child: Text('Error loading movie: $e'))),
      data: (movie) {
        if (movie == null) {
          return const Scaffold(
              body: Center(child: Text('Movie not found')));
        }
        return _MovieDetailContent(movie: movie, heroTag: heroTag);
      },
    );
  }
}

// ─── Content ──────────────────────────────────────────────────────────────────

class _MovieDetailContent extends ConsumerStatefulWidget {
  final MovieModel movie;
  final String? heroTag;
  const _MovieDetailContent({required this.movie, this.heroTag});

  @override
  ConsumerState<_MovieDetailContent> createState() =>
      _MovieDetailContentState();
}

class _MovieDetailContentState extends ConsumerState<_MovieDetailContent> {
  YoutubePlayerController? _ytCtrl;
  bool _playTrailer = false;
  Timer? _trailerTimer;
  bool _timerStarted = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      final url = widget.movie.trailerUrl;
      if (url.isNotEmpty) {
        final videoId = YoutubePlayer.convertUrlToId(url) ?? url;
        _ytCtrl = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: true,
            mute: true,
            enableCaption: false,
            hideControls: true,
            hideThumbnail: true,
          ),
        );
        _ytCtrl!.addListener(_onYtListener);
      }
    }
  }

  void _onYtListener() {
    if (_ytCtrl?.value.playerState == PlayerState.playing && !_playTrailer && !_timerStarted) {
      _timerStarted = true;
      _trailerTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          _ytCtrl?.unMute();
          setState(() {
            _playTrailer = true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _trailerTimer?.cancel();
    _ytCtrl?.removeListener(_onYtListener);
    _ytCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final videoId = YoutubePlayer.convertUrlToId(movie.trailerUrl) ?? movie.trailerUrl;

    if (kIsWeb) {
      return _buildScaffold(context, buildWebVideoPlayer(videoId));
    }

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _ytCtrl ?? YoutubePlayerController(
          initialVideoId: '',
          flags: const YoutubePlayerFlags(autoPlay: false),
        ),
      ),
      builder: (context, player) => _buildScaffold(context, player),
    );
  }

  Widget _buildScaffold(BuildContext context, Widget playerWidget) {
    final movie = widget.movie;
    return Scaffold(
        backgroundColor: ShowSnapColors.background,
        bottomNavigationBar: movie.status == 'nowShowing'
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: ShowSnapColors.background,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: TappableScale(
                    onTap: () async {
                      _ytCtrl?.pause();
                      await context.push('/show-selection/${movie.movieId}');
                    },
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      decoration: ShowSnapTheme.primaryButtonDecoration,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                          onTap: () async {
                            _ytCtrl?.pause();
                            await context.push('/show-selection/${movie.movieId}');
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.local_activity_outlined, color: Colors.black87),
                              SizedBox(width: 8),
                              Text(
                                'Book Tickets',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : null,
        body: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: CustomScrollView(
            slivers: [
            SliverAppBar(
              expandedHeight: MediaQuery.of(context).size.width / (4 / 3),
              pinned: true,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              leading: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
              ),
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: false,
                titlePadding:
                    const EdgeInsets.only(left: 16, bottom: 16, right: 16),
                title: Text(
                  movie.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                background: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                    if (kIsWeb ? (movie.trailerUrl.isNotEmpty && _playTrailer) : _ytCtrl != null)
                      SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: 1600,
                            height: 900,
                            child: Transform.scale(
                              scale: 1.45,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (!kIsWeb && _playTrailer && _ytCtrl != null) {
                                    if (_ytCtrl!.value.isPlaying) {
                                      _ytCtrl!.pause();
                                    } else {
                                      _ytCtrl!.play();
                                    }
                                  }
                                },
                                child: IgnorePointer(
                                  ignoring: true,
                                  child: playerWidget,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (!_playTrailer) ...[
                      Hero(
                        tag: widget.heroTag ?? 'movie_poster_${movie.movieId}',
                        child: movie.posterUrl.isNotEmpty ? CachedNetworkImage(
                          imageUrl: movie.posterUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Shimmer.fromColors(
                            baseColor: ShowSnapColors.grey300,
                            highlightColor: ShowSnapColors.grey100,
                            child: Container(color: ShowSnapColors.grey300),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: ShowSnapColors.grey300,
                            child: const Icon(Icons.movie_outlined, size: 80),
                          ),
                        ) : Container(
                            color: ShowSnapColors.grey300,
                            child: const Icon(Icons.movie_outlined, size: 80),
                        ),
                      ),
                    ],
                    IgnorePointer(
                      child: Stack(
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 120,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.6),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_playTrailer && (kIsWeb ? movie.trailerUrl.isNotEmpty : _ytCtrl != null))
                      Center(
                        child: TappableScale(
                          onTap: () {
                            if (kIsWeb) {
                              setState(() {
                                _playTrailer = true;
                              });
                            } else {
                              _trailerTimer?.cancel();
                              _ytCtrl?.unMute();
                              _ytCtrl?.play();
                              setState(() {
                                _playTrailer = true;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                              border: Border.all(color: ShowSnapColors.primary, width: 2),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: ShowSnapColors.primary,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badges
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Badge(movie.certificate,
                            color: ShowSnapColors.primary),
                        _Badge(movie.language),
                        _Badge('${movie.durationMinutes} min'),
                        ...movie.genres.take(3).map((g) => _Badge(g)),
                      ],
                    )
                        .animate()
                        .fadeIn(duration: ShowSnapDuration.normal)
                        .slideY(begin: 0.08, end: 0),

                    const SizedBox(height: 16),

                    // Rating
                    if (movie.rating > 0)
                      _RatingRow(rating: movie.rating)
                          .animate()
                          .fadeIn(
                              duration: ShowSnapDuration.normal,
                              delay: const Duration(milliseconds: 80))
                          .slideY(
                              begin: 0.08,
                              end: 0,
                              delay: const Duration(milliseconds: 80)),

                    const SizedBox(height: 16),

                    // Synopsis
                    if (movie.synopsis.isNotEmpty) ...[
                      Text(
                        'Synopsis',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      )
                          .animate()
                          .fadeIn(
                              duration: ShowSnapDuration.normal,
                              delay: const Duration(milliseconds: 160))
                          .slideY(
                              begin: 0.08,
                              end: 0,
                              delay: const Duration(milliseconds: 160)),
                      const SizedBox(height: 8),
                      _ExpandableSynopsis(text: movie.synopsis)
                          .animate()
                          .fadeIn(
                              duration: ShowSnapDuration.normal,
                              delay: const Duration(milliseconds: 200)),
                      const SizedBox(height: 16),
                    ],

                    // Director & release
                    if (movie.director.isNotEmpty)
                      _InfoRow(
                              label: 'Director', value: movie.director)
                          .animate()
                          .fadeIn(
                              duration: ShowSnapDuration.normal,
                              delay: const Duration(milliseconds: 240)),

                    const SizedBox(height: 8),

                    // Cast
                    if (movie.cast.isNotEmpty) ...[
                      Text(
                        'Cast',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      )
                          .animate()
                          .fadeIn(
                              duration: ShowSnapDuration.normal,
                              delay: const Duration(milliseconds: 280)),
                      const SizedBox(height: 8),
                      _CastList(cast: movie.cast, movieName: movie.title)
                          .animate()
                          .fadeIn(
                              duration: ShowSnapDuration.normal,
                              delay: const Duration(milliseconds: 320)),
                      const SizedBox(height: 16),
                    ],

                    if (movie.releaseDateTs > 0) ...[
                      _InfoRow(
                        label: 'Release',
                        value: movie.releaseDateTs.epochToDateLabel,
                      )
                          .animate()
                          .fadeIn(
                              duration: ShowSnapDuration.normal,
                              delay: const Duration(milliseconds: 360)),
                    ],

                    const SizedBox(height: 20),

                    // User rating section
                    _UserRatingSection(movieId: movie.movieId)
                        .animate()
                        .fadeIn(
                            duration: ShowSnapDuration.normal,
                            delay: const Duration(milliseconds: 400)),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── User Rating Section ─────────────────────────────────────────────────────

class _UserRatingSection extends ConsumerStatefulWidget {
  final String movieId;
  const _UserRatingSection({required this.movieId});

  @override
  ConsumerState<_UserRatingSection> createState() =>
      _UserRatingSectionState();
}

class _UserRatingSectionState extends ConsumerState<_UserRatingSection> {
  bool _submitting = false;
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    final bookingsAsync =
        ref.watch(_userBookingsForMovieProvider(widget.movieId));
    final existingRatingAsync =
        ref.watch(_userMovieRatingProvider(widget.movieId));

    final hasPastBooking =
        bookingsAsync.valueOrNull?.isNotEmpty == true;

    if (!hasPastBooking) return const SizedBox.shrink();

    final existing = existingRatingAsync.valueOrNull ?? 0;
    if (existing > 0 && !_submitted) {
      return _RatingDisplay(rating: existing);
    }
    if (_submitted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ShowSnapColors.secondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          border: Border.all(color: ShowSnapColors.secondary),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: ShowSnapColors.secondary),
            SizedBox(width: 8),
            Text('Thanks for your rating!',
                style: TextStyle(color: ShowSnapColors.secondary,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ShowSnapColors.primaryLighter.withOpacity(0.5),
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        border: Border.all(color: ShowSnapColors.primary.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rate This Movie',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('You\'ve watched this! Share your experience.',
              style: TextStyle(
                  fontSize: 12, color: ShowSnapColors.grey600)),
          const SizedBox(height: 12),
          RatingBar.builder(
            initialRating: 0,
            minRating: 1,
            direction: Axis.horizontal,
            itemCount: 5,
            itemSize: 36,
            itemPadding:
                const EdgeInsets.symmetric(horizontal: 4),
            itemBuilder: (_, __) =>
                const Icon(Icons.star_rounded, color: ShowSnapColors.primary),
            onRatingUpdate: (r) => _submitRating(r * 2), // 5-star → 10-point
          ),
        ],
      ),
    );
  }

  Future<void> _submitRating(double rating) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid == null) return;
      await ref
          .read(databaseServiceProvider)
          .submitMovieRating(widget.movieId, uid, rating);
      setState(() {
        _submitting = false;
        _submitted = true;
      });
      if (mounted) {
        ShowSnapToast.show(context, message: 'Rating submitted!');
      }
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ShowSnapToast.show(context,
            message: 'Failed to submit rating', type: ToastType.error);
      }
    }
  }
}

class _RatingDisplay extends StatelessWidget {
  final double rating;
  const _RatingDisplay({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ShowSnapColors.grey100,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: ShowSnapColors.primary),
          const SizedBox(width: 8),
          Text('Your rating: ${rating.toStringAsFixed(1)} / 10',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Rating row ───────────────────────────────────────────────────────────────

class _RatingRow extends StatelessWidget {
  final double rating;
  const _RatingRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    final starCount = (rating / 2).round().clamp(0, 5);
    return Row(
      children: [
        ...List.generate(
          5,
          (i) => Icon(
            i < starCount ? Icons.star_rounded : Icons.star_outline_rounded,
            color: ShowSnapColors.primary,
            size: 20,
          )
              .animate(delay: Duration(milliseconds: 60 * i))
              .scale(
                begin: const Offset(0.4, 0.4),
                end: const Offset(1, 1),
                duration: const Duration(milliseconds: 300),
                curve: Curves.elasticOut,
              ),
        ),
        const SizedBox(width: 8),
        Text(
          '${rating.toStringAsFixed(1)} / 10',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ─── Expandable synopsis ──────────────────────────────────────────────────────

class _ExpandableSynopsis extends StatefulWidget {
  final String text;
  const _ExpandableSynopsis({required this.text});

  @override
  State<_ExpandableSynopsis> createState() => _ExpandableSynopsisState();
}

class _ExpandableSynopsisState extends State<_ExpandableSynopsis> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedCrossFade(
            firstChild: Text(
              widget.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ShowSnapColors.grey600,
                    height: 1.6,
                  ),
            ),
            secondChild: Text(
              widget.text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ShowSnapColors.grey600,
                    height: 1.6,
                  ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: ShowSnapDuration.fast,
          ),
          const SizedBox(height: 4),
          Text(
            _expanded ? 'Show less' : 'Read more',
            style: const TextStyle(
              color: ShowSnapColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color? color;
  const _Badge(this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? ShowSnapColors.grey600).withOpacity(0.1),
        border: Border.all(color: color ?? ShowSnapColors.grey300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color ?? ShowSnapColors.grey600,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: ShowSnapColors.grey600),
          ),
        ),
      ],
    );
  }
}

// ─── Cast List ───────────────────────────────────────────────────────────────

class _CastList extends StatelessWidget {
  final List<String> cast;
  final String movieName;
  const _CastList({required this.cast, required this.movieName});

  @override
  Widget build(BuildContext context) {
    if (cast.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 220, // Height for 2 rows of avatars + text
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        scrollDirection: Axis.horizontal,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 90,
        ),
        itemCount: cast.length,
        itemBuilder: (context, index) {
          return _CastAvatar(name: cast[index], movieName: movieName);
        },
      ),
    );
  }
}

class _CastAvatar extends StatefulWidget {
  final String name;
  final String movieName;
  const _CastAvatar({required this.name, required this.movieName});

  @override
  State<_CastAvatar> createState() => _CastAvatarState();
}

class _CastAvatarState extends State<_CastAvatar> {
  String? _imageUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchImage();
  }

  Future<void> _fetchImage() async {
    try {
      final nameQuery = Uri.encodeComponent(widget.name.replaceAll(' ', '_'));
      final url = Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/$nameQuery');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['thumbnail'] != null && data['thumbnail']['source'] != null) {
          if (mounted) {
            setState(() {
              _imageUrl = data['thumbnail']['source'];
              _loading = false;
            });
          }
          return;
        }
      }
    } catch (_) {}
    
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _launchSearch() async {
    final query = Uri.encodeComponent('${widget.name} ${widget.movieName}');
    final url = Uri.parse('https://www.google.com/search?q=$query');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _launchSearch,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: ShowSnapColors.grey300,
            backgroundImage: _imageUrl != null ? CachedNetworkImageProvider(_imageUrl!) : null,
            child: _loading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                : (_imageUrl == null ? const Icon(Icons.person, color: Colors.white, size: 30) : null),
          ),
          const SizedBox(height: 8),
          Text(
            widget.name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
