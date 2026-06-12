import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
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
  const MovieDetailScreen({super.key, required this.movieId});

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
        return _MovieDetailContent(movie: movie);
      },
    );
  }
}

// ─── Content ──────────────────────────────────────────────────────────────────

class _MovieDetailContent extends ConsumerStatefulWidget {
  final MovieModel movie;
  const _MovieDetailContent({required this.movie});

  @override
  ConsumerState<_MovieDetailContent> createState() =>
      _MovieDetailContentState();
}

class _MovieDetailContentState extends ConsumerState<_MovieDetailContent> {
  YoutubePlayerController? _ytCtrl;

  @override
  void initState() {
    super.initState();
    final url = widget.movie.trailerUrl;
    if (url.isNotEmpty) {
      final videoId = YoutubePlayer.convertUrlToId(url) ?? url;
      _ytCtrl = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
      );
    }
  }

  @override
  void dispose() {
    _ytCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _ytCtrl ?? YoutubePlayerController(
          initialVideoId: '',
          flags: const YoutubePlayerFlags(autoPlay: false),
        ),
      ),
      builder: (context, player) => Scaffold(
        backgroundColor: Colors.white,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 340,
              pinned: true,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding:
                    const EdgeInsets.only(left: 56, bottom: 16, right: 16),
                title: Text(
                  movie.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'movie_poster_${movie.movieId}',
                      child: CachedNetworkImage(
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
                      ),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.0, 0.5, 1.0],
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black87,
                          ],
                        ),
                      ),
                    ),
                  ],
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

                    // Trailer
                    if (_ytCtrl != null) ...[
                      Text('Trailer',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold))
                          .animate()
                          .fadeIn(duration: ShowSnapDuration.normal),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(ShowSnapRadius.md),
                        child: player,
                      )
                          .animate()
                          .fadeIn(
                              duration: ShowSnapDuration.normal,
                              delay: const Duration(milliseconds: 60))
                          .slideY(begin: 0.05, end: 0),
                      const SizedBox(height: 16),
                    ],

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
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: movie.cast.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (_, i) => Chip(
                            label: Text(movie.cast[i],
                                style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      )
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

                    // Book Tickets CTA
                    if (movie.status == 'nowShowing') ...[
                      const SizedBox(height: 24),
                      TappableScale(
                        onTap: () =>
                            context.push('/show-selection/${movie.movieId}'),
                        child: Container(
                          width: double.infinity,
                          height: 54,
                          decoration: ShowSnapTheme.primaryButtonDecoration,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(
                                  ShowSnapRadius.md),
                              onTap: () => context
                                  .push('/show-selection/${movie.movieId}'),
                              child: const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.local_activity_outlined,
                                      color: Colors.black87),
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
                      )
                          .animate()
                          .fadeIn(
                              duration: ShowSnapDuration.normal,
                              delay: const Duration(milliseconds: 440))
                          .slideY(begin: 0.1, end: 0),
                    ],
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
