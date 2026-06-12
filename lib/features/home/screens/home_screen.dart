import 'dart:async';
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
import '../../../core/models/banner_model.dart';
import '../widgets/movie_card.dart';
import '../widgets/event_card.dart';
import '../../../core/config/router.dart';
import '../../../core/config/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/tappable_scale.dart';
import '../../onboarding/feature_walkthrough.dart';

// ─── City preference ─────────────────────────────────────────────────────────

final selectedCityProvider = StateProvider<String>((ref) => 'Hyderabad');

final _kMajorCities = [
  'Hyderabad', 'Mumbai', 'Delhi', 'Bengaluru',
  'Chennai', 'Kolkata', 'Pune', 'Ahmedabad',
];

// ─── HomeScreen ───────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _bannerCtrl = PageController();
  Timer? _bannerTimer;
  int _bannerPage = 0;

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
        _bannerPage = (_bannerPage + 1) % 3;
        _bannerCtrl.animateToPage(
          _bannerPage,
          duration: ShowSnapDuration.normal,
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadCity() async {
    final prefs = await SharedPreferences.getInstance();
    final city = prefs.getString('selectedCity') ?? 'Hyderabad';
    ref.read(selectedCityProvider.notifier).state = city;
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final city = ref.watch(selectedCityProvider);
    final user = ref.watch(currentUserModelProvider).valueOrNull;

    return Scaffold(
      backgroundColor: ShowSnapColors.grey100,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(homeFeedProvider.future),
        child: CustomScrollView(
          slivers: [
            // ── App Bar ───────────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              titleSpacing: 0,
              title: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // City selector
                    ShowcaseTarget(
                      showcaseKey: walkthroughCityKey,
                      title: 'Your City',
                      description: 'Tap to switch city and see local shows.',
                      child: GestureDetector(
                        onTap: () => _showCityPicker(context),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded,
                                color: ShowSnapColors.primary, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              city,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded,
                              size: 18, color: Colors.black54),
                        ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Search bar
                    Expanded(
                      child: ShowcaseTarget(
                        showcaseKey: walkthroughSearchKey,
                        title: 'Search',
                        description:
                            'Find movies, events, and theaters near you.',
                        shape: const StadiumBorder(),
                        child: GestureDetector(
                          onTap: () => context.push('/explore'),
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: ShowSnapColors.grey100,
                              borderRadius:
                                  BorderRadius.circular(ShowSnapRadius.pill),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(width: 12),
                                Icon(Icons.search,
                                    color: ShowSnapColors.grey600,
                                    size: 18),
                                SizedBox(width: 8),
                                Text('Movies, events, theaters...',
                                    style: TextStyle(
                                      color: ShowSnapColors.grey600,
                                      fontSize: 12,
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Notification bell
                    GestureDetector(
                      onTap: () {},
                      child: const Icon(Icons.notifications_outlined,
                          color: Colors.black87),
                    ),
                    const SizedBox(width: 8),
                    // Avatar
                    GestureDetector(
                      onTap: () => context.push(AppRoutes.userDashboard),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: ShowSnapColors.primaryLighter,
                        backgroundImage: (user?.avatarUrl.isNotEmpty ?? false)
                            ? CachedNetworkImageProvider(user!.avatarUrl)
                            : null,
                        child: (user?.avatarUrl.isEmpty ?? true)
                            ? Text(
                                user?.displayName.isNotEmpty == true
                                    ? user!.displayName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: ShowSnapColors.primary),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Body content ──────────────────────────────────────────────
            SliverToBoxAdapter(child: _HomeBody(bannerCtrl: _bannerCtrl)),
          ],
        ),
      ),
    );
  }

  void _showCityPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(ShowSnapRadius.lg)),
      ),
      builder: (_) => _CityPickerSheet(),
    );
  }
}

// ─── Home Body ────────────────────────────────────────────────────────────────

class _HomeBody extends ConsumerStatefulWidget {
  final PageController bannerCtrl;
  const _HomeBody({required this.bannerCtrl});

  @override
  ConsumerState<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends ConsumerState<_HomeBody> {
  String _activeCategory = 'Movies';
  final _categories = ['Movies', 'Events', 'Plays', 'Concerts', 'Sports'];

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
      data: (feed) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          // Recommended
          if (feed.recommended.isNotEmpty)
            _SectionHeader(
              title: 'Recommended for You',
              onSeeAll: () => context.push('/explore?tab=movies'),
            ),
          if (feed.recommended.isNotEmpty)
            _HorizontalMovieList(movies: feed.recommended
                .map((m) => MovieCard(movie: m)).toList())
                .animate()
                .fadeIn(duration: ShowSnapDuration.normal)
                .slideY(begin: 0.04, end: 0),
          const SizedBox(height: 16),

          // Now Showing
          _SectionHeader(
            title: 'Now Showing',
            onSeeAll: () => context.push('/explore?tab=movies'),
          ),
          _HorizontalMovieList(movies: feed.nowShowing
              .map((m) => MovieCard(movie: m)).toList())
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
                .map((m) => MovieCard(movie: m)).toList())
                .animate()
                .fadeIn(
                    duration: ShowSnapDuration.normal,
                    delay: const Duration(milliseconds: 200))
                .slideY(begin: 0.04, end: 0, delay: const Duration(milliseconds: 200)),
            const SizedBox(height: 16),
          ],

          // Events
          if (feed.events.isNotEmpty) ...[
            _SectionHeader(
              title: 'Events Near You',
              onSeeAll: () => context.push('/explore?tab=events'),
            ),
            SizedBox(
              height: 210,
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
          ],

          // Trending (ranked list style)
          if (feed.trending.isNotEmpty) ...[
            _SectionHeader(title: 'Trending This Week'),
            ...feed.trending.take(5).toList().asMap().entries.map((e) {
              final rank = e.key + 1;
              final movie = e.value;
              return TappableScale(
                onTap: () => context.push('/movie/${movie.movieId}'),
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                    boxShadow: ShowSnapShadow.card,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '$rank',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: rank == 1
                              ? ShowSnapColors.primary
                              : ShowSnapColors.grey300,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: movie.posterUrl,
                          width: 44,
                          height: 60,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 44,
                            height: 60,
                            color: ShowSnapColors.grey300,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(movie.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(
                              movie.genres.take(2).join(' • '),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: ShowSnapColors.grey600),
                            ),
                          ],
                        ),
                      ),
                      if (movie.rating > 0) ...[
                        const Icon(Icons.star_rounded,
                            size: 14, color: ShowSnapColors.primary),
                        const SizedBox(width: 2),
                        Text(movie.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(
                      duration: ShowSnapDuration.normal,
                      delay: Duration(milliseconds: 400 + 50 * e.key))
                  .slideX(
                      begin: 0.05,
                      end: 0,
                      delay: Duration(milliseconds: 400 + 50 * e.key));
            }),
          ],

          const SizedBox(height: 100), // FAB clearance
        ],
      ),
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
      title: 'Book Early, Save More',
      subtitle: 'Use code EARLY20 for 20% off',
      ctaText: 'Explore'),
  BannerModel(
      bannerId: 'd2',
      title: 'Weekend Special',
      subtitle: 'Family packages from ₹599',
      ctaText: 'Book Now'),
  BannerModel(
      bannerId: 'd3',
      title: 'IMAX Experience',
      subtitle: 'Now available at 12 theaters',
      ctaText: 'View Theaters'),
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
            itemCount: banners.length,
            itemBuilder: (_, i) => _BannerCard(
              banner: banners[i],
              onTap: banners[i].ctaRoute.isNotEmpty
                  ? () => context.push(banners[i].ctaRoute)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SmoothPageIndicator(
          controller: controller,
          count: banners.length,
          effect: const WormEffect(
            dotWidth: 8,
            dotHeight: 8,
            activeDotColor: ShowSnapColors.primary,
            dotColor: ShowSnapColors.grey300,
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
              if (banner.imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: banner.imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    decoration: BoxDecoration(gradient: _gradients[idx]),
                  ),
                )
              else
                Container(decoration: BoxDecoration(gradient: _gradients[idx])),

              // Gradient overlay so text is always readable on images
              if (banner.imageUrl.isNotEmpty)
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
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final isActive = cat == active;
          return TappableScale(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: ShowSnapDuration.fast,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isActive ? ShowSnapColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(ShowSnapRadius.pill),
                border: Border.all(
                    color: isActive
                        ? ShowSnapColors.primary
                        : ShowSnapColors.grey300),
                boxShadow: isActive ? ShowSnapShadow.card : [],
              ),
              child: Row(
                children: [
                  Icon(_iconFor(cat),
                      size: 16,
                      color:
                          isActive ? Colors.black87 : ShowSnapColors.grey600),
                  const SizedBox(width: 6),
                  Text(cat,
                      style: TextStyle(
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.normal,
                        fontSize: 13,
                        color: isActive
                            ? Colors.black87
                            : ShowSnapColors.grey600,
                      )),
                ],
              ),
            ),
          );
        },
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
      height: 240,
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

// ─── City Picker Sheet ────────────────────────────────────────────────────────

class _CityPickerSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ShowSnapColors.grey300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Select City',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              itemCount: _kMajorCities.length,
              itemBuilder: (_, i) {
                final city = _kMajorCities[i];
                return ListTile(
                  leading: const Icon(Icons.location_city_rounded,
                      color: ShowSnapColors.primary),
                  title: Text(city),
                  onTap: () async {
                    ref.read(selectedCityProvider.notifier).state = city;
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('selectedCity', city);
                    if (context.mounted) Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
