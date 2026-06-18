import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/movie_model.dart';
import '../../../core/models/theater_model.dart';
import '../../../core/services/database_service.dart';
import '../../home/widgets/movie_card.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _theaterDetailProvider =
    FutureProvider.family<TheaterModel?, String>((ref, theaterId) =>
        ref.watch(databaseServiceProvider).getTheater(theaterId));

final _theaterMoviesProvider =
    FutureProvider.family<List<MovieModel>, String>((ref, theaterId) async {
  final db = ref.watch(databaseServiceProvider);
  final shows = await db.getShowsForTheater(theaterId);
  final movieIds = shows.map((s) => s.movieId).toSet().toList();
  
  final List<MovieModel> movies = [];
  for (final mId in movieIds) {
    final m = await db.getMovie(mId);
    if (m != null && m.status == 'nowShowing') {
      movies.add(m);
    }
  }
  return movies;
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class TheaterDetailScreen extends ConsumerWidget {
  final String theaterId;
  const TheaterDetailScreen({super.key, required this.theaterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theaterAsync = ref.watch(_theaterDetailProvider(theaterId));
    return theaterAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (theater) {
        if (theater == null) {
          return const Scaffold(
              body: Center(child: Text('Theater not found')));
        }
        return _TheaterDetailContent(theater: theater);
      },
    );
  }
}

// ─── Content ──────────────────────────────────────────────────────────────────

class _TheaterDetailContent extends ConsumerWidget {
  final TheaterModel theater;
  const _TheaterDetailContent({required this.theater});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ShowSnapColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                theater.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (theater.logoUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: theater.logoUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        decoration: BoxDecoration(gradient: ShowSnapTheme.splashGradient),
                        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(gradient: ShowSnapTheme.splashGradient),
                        child: const Center(
                          child: Icon(Icons.theaters_rounded, size: 80, color: Colors.white30),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(gradient: ShowSnapTheme.splashGradient),
                      child: const Center(
                        child: Icon(Icons.theaters_rounded, size: 80, color: Colors.white30),
                      ),
                    ),
                  // Dark overlay for text readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ShowSnapColors.surface,
                      borderRadius:
                          BorderRadius.circular(ShowSnapRadius.md),
                      boxShadow: ShowSnapShadow.card,
                    ),
                    child: Column(
                      children: [
                        _InfoTile(
                          icon: Icons.location_on_rounded,
                          label: theater.address.isNotEmpty
                              ? theater.address
                              : theater.city,
                        ),
                        if (theater.address.isNotEmpty &&
                            theater.city.isNotEmpty)
                          _InfoTile(
                            icon: Icons.location_city_rounded,
                            label: theater.city,
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.directions_rounded,
                                size: 16),
                            label: const Text('Get Directions'),
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      ShowSnapRadius.md)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: ShowSnapDuration.normal)
                      .slideY(begin: 0.05, end: 0),

                  const SizedBox(height: 20),
                  const Text('Now Showing Here',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 12),

                  _NowShowingSection(theaterId: theater.theaterId),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: ShowSnapColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _NowShowingSection extends ConsumerWidget {
  final String theaterId;
  const _NowShowingSection({required this.theaterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(_theaterMoviesProvider(theaterId));
    return moviesAsync.when(
      loading: () => const Center(
          child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      )),
      error: (e, _) =>
          Text('Error: $e', style: const TextStyle(color: Colors.red)),
      data: (movies) {
        if (movies.isEmpty) {
          return const Text('No movies currently showing',
              style: TextStyle(color: ShowSnapColors.grey600));
        }
        return SizedBox(
          height: 310,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: movies.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => MovieCard(movie: movies[i], heroTagSuffix: 'theater_detail'),
          ),
        );
      },
    );
  }
}
