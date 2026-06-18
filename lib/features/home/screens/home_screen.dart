import 'dart:async';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../providers/home_provider.dart';
import '../providers/location_provider.dart';
import '../widgets/location_bottom_sheet.dart';
import '../../../core/models/banner_model.dart';
import '../widgets/movie_card.dart';
import '../widgets/event_card.dart';
import '../../../core/config/router.dart';
import '../../../core/config/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/tappable_scale.dart';
import '../../onboarding/feature_walkthrough.dart';
import '../../explore/screens/explore_screen.dart';
import '../../../core/widgets/main_app_bar.dart';

// (City preferences removed in favor of LocationProvider)

// ─── HomeScreen ───────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _bannerCtrl = PageController(initialPage: 10000);
  Timer? _bannerTimer;
  int _bannerPage = 0;

  bool _isSearchVisible = false;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _startBannerAuto();
    _loadCity();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FeatureWalkthroughWrapper.startIfFirstLaunch(context);
    });
  }

  void _startBannerAuto() {
    _bannerTimer =
        Timer.periodic(const Duration(seconds: 4), (_) {
      if (_bannerCtrl.hasClients) {
        final current = _bannerCtrl.page?.round() ?? 10000;
        _bannerCtrl.animateToPage(
          current + 1,
          duration: ShowSnapDuration.normal,
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadCity() async {
    // Left empty since LocationProvider handles loading
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final address = ref.watch(selectedAddressProvider);
    final user = ref.watch(currentUserModelProvider).valueOrNull;

    return Scaffold(
      backgroundColor: ShowSnapColors.grey100,
      appBar: MainAppBar(
        title: 'It All Starts Here !',
        enableShowcase: true,
        onSearchTap: () {
          setState(() {
            _isSearchVisible = !_isSearchVisible;
            if (_isSearchVisible) {
              _searchFocus.requestFocus();
            } else {
              _searchCtrl.clear();
            }
          });
        },
        bottom: _isSearchVisible
            ? PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search movies...',
                      prefixIcon: const Icon(Icons.search, color: ShowSnapColors.grey600, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: ShowSnapColors.grey600, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: ShowSnapColors.grey100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ShowSnapRadius.pill),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ShowSnapRadius.pill),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ShowSnapRadius.pill),
                        borderSide: const BorderSide(color: ShowSnapColors.primary, width: 2),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              )
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(bannersProvider);
          return ref.refresh(homeFeedProvider.future);
        },
        child: CustomScrollView(
          slivers: [


            // ── Body content ──────────────────────────────────────────────
            SliverToBoxAdapter(
                child: _HomeBody(
                    bannerCtrl: _bannerCtrl,
                    searchQuery: _searchCtrl.text)),
          ],
        ),
      ),
    );
  }

  void _showCityPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: const LocationBottomSheet(),
      ),
    );
  }
}

// ─── Home Body ────────────────────────────────────────────────────────────────

class _HomeBody extends ConsumerStatefulWidget {
  final PageController bannerCtrl;
  final String searchQuery;
  const _HomeBody({required this.bannerCtrl, this.searchQuery = ''});

  @override
  ConsumerState<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends ConsumerState<_HomeBody> {
  String _activeCategory = 'Movies';
  final _categories = ['Movies', 'Events'];

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(homeFeedProvider);

    return feedAsync.when(
      loading: () => _buildLoadingShell(),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: ShowSnapColors.grey600),
            const SizedBox(height: 12),
            Text('Failed to load: $err',
                textAlign: TextAlign.center,
                style: const TextStyle(color: ShowSnapColors.grey600)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.refresh(homeFeedProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (feed) {
        if (widget.searchQuery.isNotEmpty) {
          final allMovies = [...feed.nowShowing, ...feed.upcoming, ...feed.recommended];
          final Map<String, dynamic> uniqueMovies = {};
          for (var m in allMovies) {
            uniqueMovies[m.movieId] = m;
          }
          final results = uniqueMovies.values
              .where((m) =>
                  m.title.toLowerCase().contains(widget.searchQuery.toLowerCase()))
              .toList();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Search Results',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 16),
                if (results.isEmpty)
                  const Text('No movies found.',
                      style: TextStyle(color: ShowSnapColors.grey600))
                else
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: results
                        .map((m) => MovieCard(movie: m, heroTagSuffix: 'search'))
                        .toList(),
                  ),
                const SizedBox(height: 100),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const _QuickActionIcons(),
            const SizedBox(height: 16),
            // Promo Banner
          _PromoBanner(controller: widget.bannerCtrl),
          const SizedBox(height: 16),

          // Category pills
          ShowcaseTarget(
            showcaseKey: walkthroughCategoryKey,
            title: 'Categories',
            description: 'Filter by Movies, Events, Plays, and more.',
            child: _CategoryPills(
              categories: _categories,
              active: _activeCategory,
              onSelect: (c) => setState(() => _activeCategory = c),
            ),
          ),
          const SizedBox(height: 16),

          if (_activeCategory == 'Movies') ...[


            // Now Showing
            _SectionHeader(
              title: 'Now Showing',
              onSeeAll: () => context.push('/explore?tab=movies'),
            ),
            _HorizontalMovieList(movies: feed.nowShowing
                .map((m) => MovieCard(movie: m, heroTagSuffix: 'now_showing')).toList())
                .animate()
                .fadeIn(
                    duration: ShowSnapDuration.normal,
                    delay: const Duration(milliseconds: 100))
                .slideY(begin: 0.04, end: 0, delay: const Duration(milliseconds: 100)),
            const SizedBox(height: 16),

            // Upcoming
            if (feed.upcoming.isNotEmpty) ...[
              _SectionHeader(
                title: 'Upcoming',
                onSeeAll: () => context.push('/explore?tab=movies'),
              ),
              _HorizontalMovieList(movies: feed.upcoming
                  .map((m) => MovieCard(movie: m, heroTagSuffix: 'upcoming')).toList())
                  .animate()
                  .fadeIn(
                      duration: ShowSnapDuration.normal,
                      delay: const Duration(milliseconds: 200))
                  .slideY(begin: 0.04, end: 0, delay: const Duration(milliseconds: 200)),
              const SizedBox(height: 16),
            ],


          ] else if (_activeCategory == 'Events') ...[
            // Events
            if (feed.events.isNotEmpty) ...[
              Builder(builder: (context) {
                final now = DateTime.now().millisecondsSinceEpoch;
                final upcomingEvents = feed.events.where((e) => e.startTs > now).toList()
                  ..sort((a, b) => a.startTs.compareTo(b.startTs));
                if (upcomingEvents.isEmpty) return const SizedBox.shrink();
                
                final nearest = upcomingEvents.first;
                final diff = DateTime.fromMillisecondsSinceEpoch(nearest.startTs).difference(DateTime.now());
                if (diff.inDays > 7) return const SizedBox.shrink(); // Only show if within a week

                String timeStr;
                if (diff.inDays > 0) {
                  timeStr = '${diff.inDays} days';
                } else if (diff.inHours > 0) {
                  timeStr = '${diff.inHours} hours';
                } else {
                  timeStr = '${diff.inMinutes} mins';
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [ShowSnapColors.primary.withValues(alpha: 0.9), ShowSnapColors.primary.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                      boxShadow: ShowSnapShadow.card,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                          child: const Icon(Icons.timer_outlined, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Starting in $timeStr!', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(nearest.name, style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: ShowSnapColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ShowSnapRadius.pill)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => context.push('/event/${nearest.eventId}'),
                          child: const Text('Book', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn().slideY(begin: 0.1, end: 0);
              }),
              _SectionHeader(
                title: 'Events Near You',
                onSeeAll: () => context.push('/explore?tab=events'),
              ),
              SizedBox(
                height: 200, // Adjusted to remove bottom gap
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: feed.events.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => EventCard(event: feed.events[i]),
                ),
              )
                  .animate()
                  .fadeIn(
                      duration: ShowSnapDuration.normal,
                      delay: const Duration(milliseconds: 300))
                  .slideY(begin: 0.04, end: 0, delay: const Duration(milliseconds: 300)),
              const SizedBox(height: 16),
            ] else ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No events found near you',
                    style: TextStyle(color: ShowSnapColors.grey600),
                  ),
                ),
              ),
            ],
          ],

          const SizedBox(height: 100), // FAB clearance
        ],
      );
      },
    );
  }

  Widget _buildLoadingShell() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner shimmer
        Padding(
          padding: const EdgeInsets.all(16),
          child: Shimmer.fromColors(
            baseColor: ShowSnapColors.grey300,
            highlightColor: ShowSnapColors.grey100,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: ShowSnapColors.grey300,
                borderRadius: BorderRadius.circular(ShowSnapRadius.md),
              ),
            ),
          ),
        ),
        // Movie card shimmer row
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                  3,
                  (i) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Shimmer.fromColors(
                          baseColor: ShowSnapColors.grey300,
                          highlightColor: ShowSnapColors.grey100,
                          child: Container(
                            width: 120,
                            height: 200,
                            decoration: BoxDecoration(
                              color: ShowSnapColors.grey300,
                              borderRadius:
                                  BorderRadius.circular(ShowSnapRadius.sm),
                            ),
                          ),
                        ),
                      )),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Promo Banner ─────────────────────────────────────────────────────────────

// ─── Promo Banner ─────────────────────────────────────────────────────────────

// Fallback banners shown while RTDB loads or when admin has added none yet
const _kDefaultBanners = [
  BannerModel(
      bannerId: 'd1',
      imageUrl: 'https://image.tmdb.org/t/p/w780/8b8R8l88ILGWXv7Z31GO80ReOU.jpg',
  ),
  BannerModel(
      bannerId: 'd2',
      imageUrl: 'https://image.tmdb.org/t/p/w780/9l1eZiJHmhr5jIlthMdJN5WYoff.jpg',
  ),
  BannerModel(
      bannerId: 'd3',
      imageUrl: 'https://image.tmdb.org/t/p/w780/rktDFPbfHfUbArZ6OOOKsXcv0Bm.jpg',
  ),
  BannerModel(
      bannerId: 'd4',
      imageUrl: 'https://image.tmdb.org/t/p/w780/zfbjgQE1uSd9wiPTX4VzsLi0rGG.jpg',
  ),
  BannerModel(
      bannerId: 'd5',
      imageUrl: 'https://image.tmdb.org/t/p/w780/7gKI9hpEMcZUQpNgKrkDzJpbnc0.jpg',
  ),
];

class _PromoBanner extends ConsumerWidget {
  final PageController controller;
  const _PromoBanner({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(bannersProvider);
    final banners = bannersAsync.valueOrNull?.isNotEmpty == true
        ? bannersAsync.value!
        : _kDefaultBanners;

    return Column(
      children: [
        SizedBox(
          height: 165,
          child: PageView.builder(
            controller: controller,
            itemBuilder: (_, i) {
              final banner = banners[i % banners.length];
              return _BannerCard(
                banner: banner,
                onTap: banner.ctaRoute.isNotEmpty
                    ? () {
                        final route = banner.ctaRoute.startsWith('/')
                            ? banner.ctaRoute
                            : '/${banner.ctaRoute}';
                        context.push(route);
                      }
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  final BannerModel banner;
  final VoidCallback? onTap;
  const _BannerCard({required this.banner, this.onTap});

  static const _gradients = [
    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFFFF8E1), Color(0xFFFFE082)]),
    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFE8F5E9), Color(0xFFA5D6A7)]),
    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFE3F2FD), Color(0xFF90CAF9)]),
  ];

  @override
  Widget build(BuildContext context) {
    final idx = banner.bannerId.hashCode.abs() % _gradients.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TappableScale(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background: image if available, else gradient
              Container(decoration: BoxDecoration(gradient: _gradients[idx])),
              if (banner.imageUrl.isNotEmpty)
                Positioned.fill(
                  child: Image.network(
                    banner.imageUrl.replaceFirst('http://', 'https://'),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 30)),
                  ),
                ),

              // Gradient overlay so text is always readable on images
              if (banner.imageUrl.isNotEmpty && (banner.title.isNotEmpty || banner.subtitle.isNotEmpty))
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [Colors.transparent, Colors.black54],
                    ),
                  ),
                ),

              // Text content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (banner.ctaText.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: ShowSnapColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(banner.ctaText.toUpperCase(),
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      banner.title,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: banner.imageUrl.isNotEmpty
                              ? Colors.white
                              : Colors.black87),
                    ),
                    if (banner.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        banner.subtitle,
                        style: TextStyle(
                            fontSize: 13,
                            color: banner.imageUrl.isNotEmpty
                                ? Colors.white70
                                : Colors.black54),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Category Pills ───────────────────────────────────────────────────────────

class _CategoryPills extends StatelessWidget {
  final List<String> categories;
  final String active;
  final void Function(String) onSelect;

  const _CategoryPills({
    required this.categories,
    required this.active,
    required this.onSelect,
  });

  IconData _iconFor(String c) {
    switch (c) {
      case 'Events':
        return Icons.celebration_rounded;
      case 'Plays':
        return Icons.theater_comedy_rounded;
      case 'Concerts':
        return Icons.music_note_rounded;
      case 'Sports':
        return Icons.sports_soccer_rounded;
      default:
        return Icons.movie_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: categories.map((cat) {
          final isActive = cat == active;
          return Expanded(
            child: TappableScale(
              onTap: () => onSelect(cat),
              child: AnimatedContainer(
                duration: ShowSnapDuration.fast,
                height: 44,
                margin: EdgeInsets.only(
                  right: cat == categories.first ? 6 : 0,
                  left: cat == categories.last && categories.length > 1 ? 6 : 0,
                ),
                decoration: BoxDecoration(
                  color: isActive ? ShowSnapColors.primary : ShowSnapColors.surface,
                  borderRadius: BorderRadius.circular(ShowSnapRadius.pill),
                  border: Border.all(
                      color: isActive ? ShowSnapColors.primary : ShowSnapColors.grey300),
                  boxShadow: isActive ? ShowSnapShadow.card : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_iconFor(cat),
                        size: 16, color: isActive ? Colors.black87 : Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      cat,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isActive ? Colors.black87 : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16)),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Text('See all',
                  style: TextStyle(
                    color: ShowSnapColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
            ),
        ],
      ),
    );
  }
}

// ─── Horizontal movie list ────────────────────────────────────────────────────

class _HorizontalMovieList extends StatelessWidget {
  final List<Widget> movies;
  const _HorizontalMovieList({required this.movies});

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('Nothing here yet.',
            style: TextStyle(color: ShowSnapColors.grey600)),
      );
    }
    return SizedBox(
      height: 310,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: movies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => movies[i],
      ),
    );
  }
}

// ─── Quick Action Icons ───────────────────────────────────────────────────────

class _QuickActionIcons extends ConsumerWidget {
  const _QuickActionIcons();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void navigateToExploreTab(int tabIndex) {
      ref.read(exploreTabIndexProvider.notifier).state = tabIndex;
      context.go('/explore');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActionIcon(
            icon: Icons.movie_filter_rounded,
            label: 'Movies',
            onTap: () => navigateToExploreTab(0),
          ),
          const SizedBox(width: 8),
          _ActionIcon(
            icon: Icons.ondemand_video_rounded,
            label: 'Stream',
            onTap: () => navigateToExploreTab(1),
          ),
          const SizedBox(width: 8),
          _ActionIcon(
            icon: Icons.theater_comedy_rounded,
            label: 'Comedy Shows',
            onTap: () => navigateToExploreTab(1),
          ),
          const SizedBox(width: 8),
          _ActionIcon(
            icon: Icons.music_note_rounded,
            label: 'Music Shows',
            onTap: () => navigateToExploreTab(1),
          ),
          const SizedBox(width: 8),
          _ActionIcon(
            icon: Icons.attractions_rounded,
            label: 'Amusement Parks',
            onTap: () => navigateToExploreTab(1),
          ),
          const SizedBox(width: 8),
          _ActionIcon(
            icon: Icons.explore_rounded,
            label: 'Adventure',
            onTap: () => navigateToExploreTab(1),
          ),
          const SizedBox(width: 8),
          _ActionIcon(
            icon: Icons.handyman_rounded,
            label: 'Workshops',
            onTap: () => navigateToExploreTab(1),
          ),
          const SizedBox(width: 8),
          _ActionIcon(
            icon: Icons.toys_rounded,
            label: 'Kids Zone',
            onTap: () => navigateToExploreTab(1),
          ),
          const SizedBox(width: 8),
          _ActionIcon(
            icon: Icons.map_rounded,
            label: 'Unique Tours',
            onTap: () => navigateToExploreTab(1),
          ),
          const SizedBox(width: 8),
          _ActionIcon(
            icon: Icons.star_rounded,
            label: 'Performances',
            onTap: () => navigateToExploreTab(1),
          ),
          const SizedBox(width: 8),
          _ActionIcon(
            icon: Icons.museum_rounded,
            label: 'Tourist Attractions',
            onTap: () => navigateToExploreTab(1),
          ),
          const SizedBox(width: 8),
          _ActionIcon(
            icon: Icons.grid_view_rounded,
            label: 'Explore More',
            onTap: () => navigateToExploreTab(1),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionIcon({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TappableScale(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: ShowSnapColors.surface,
                shape: BoxShape.circle,
                boxShadow: ShowSnapShadow.card,
                border: Border.all(color: ShowSnapColors.grey300.withOpacity(0.1)),
              ),
              child: Icon(icon, color: ShowSnapColors.primary, size: 24),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
