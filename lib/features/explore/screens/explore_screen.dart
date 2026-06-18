import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/event_model.dart';
import '../../../core/models/movie_model.dart';
import '../../../core/models/theater_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/widgets/tappable_scale.dart';
import '../../home/widgets/movie_card.dart';
import '../../home/widgets/event_card.dart';
import '../../../core/widgets/main_app_bar.dart';
import '../../../core/constants/app_constants.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _allMoviesProvider = FutureProvider<List<MovieModel>>((ref) =>
    ref.watch(databaseServiceProvider).getAllMovies());

final _allEventsProvider = StreamProvider<List<EventModel>>((ref) =>
    ref.watch(databaseServiceProvider).streamAllEvents());

final _allTheatersProvider = FutureProvider<List<TheaterModel>>((ref) =>
    ref.watch(databaseServiceProvider).getAllTheaters());

final exploreTabIndexProvider = StateProvider<int>((ref) => 0);



// ─── ExploreScreen ────────────────────────────────────────────────────────────

class ExploreScreen extends ConsumerStatefulWidget {
  final String? initialTab;
  const ExploreScreen({super.key, this.initialTab});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  bool _searchActive = false;

  @override
  void initState() {
    super.initState();
    int initialIndex = ref.read(exploreTabIndexProvider);
    if (widget.initialTab == 'events') initialIndex = 1;
    else if (widget.initialTab == 'theaters') initialIndex = 2;
    
    _tabCtrl = TabController(length: 3, vsync: this, initialIndex: initialIndex);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        ref.read(exploreTabIndexProvider.notifier).state = _tabCtrl.index;
      }
    });
  }

  @override
  void didUpdateWidget(ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      if (widget.initialTab == 'events') _tabCtrl.animateTo(1);
      else if (widget.initialTab == 'theaters') _tabCtrl.animateTo(2);
      else if (widget.initialTab == 'movies') _tabCtrl.animateTo(0);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(exploreTabIndexProvider, (prev, next) {
      if (_tabCtrl.index != next) {
        _tabCtrl.animateTo(next);
      }
    });

    return Scaffold(
      backgroundColor: ShowSnapColors.grey100,
      appBar: MainAppBar(
        title: 'Explore',
        showSearch: !_searchActive,
        onSearchTap: () => setState(() => _searchActive = true),
        customTitle: _searchActive
            ? _SearchBar(
                ctrl: _searchCtrl,
                onClose: () {
                  setState(() {
                    _searchActive = false;
                    _searchCtrl.clear();
                  });
                },
              )
            : null,
        bottom: _searchActive
            ? null
            : TabBar(
                controller: _tabCtrl,
                labelColor: ShowSnapColors.primary,
                unselectedLabelColor: ShowSnapColors.grey600,
                indicatorColor: ShowSnapColors.primary,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'Movies'),
                  Tab(text: 'Events'),
                  Tab(text: 'Theaters'),
                ],
              ),
      ),
      body: _searchActive
          ? _SearchResults(query: _searchCtrl.text)
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _MoviesTab(),
                _EventsTab(),
                _TheatersTab(),
              ],
            ),
    );
  }
}

// ─── Search Bar ───────────────────────────────────────────────────────────────

class _SearchBar extends ConsumerStatefulWidget {
  final TextEditingController ctrl;
  final VoidCallback onClose;
  const _SearchBar({required this.ctrl, required this.onClose});

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  @override
  Widget build(BuildContext context) {
    return TypeAheadField<String>(
      controller: widget.ctrl,
      suggestionsCallback: (pattern) async {
        if (pattern.isEmpty) return [];
        final movies = ref.read(_allMoviesProvider).valueOrNull ?? [];
        return movies
            .where((m) =>
                m.title.toLowerCase().contains(pattern.toLowerCase()))
            .map((m) => m.title)
            .take(5)
            .toList();
      },
      itemBuilder: (_, suggestion) => ListTile(
        leading: const Icon(Icons.movie_outlined, size: 18),
        title: Text(suggestion, style: const TextStyle(fontSize: 13)),
        dense: true,
      ),
      onSelected: (suggestion) {
        widget.ctrl.text = suggestion;
        setState(() {});
      },
      builder: (context, ctrl, focusNode) => TextField(
        controller: ctrl,
        focusNode: focusNode,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search movies, events, theaters...',
          hintStyle: const TextStyle(fontSize: 13),
          border: InputBorder.none,
          suffixIcon: IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onClose,
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  final String query;
  const _SearchResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.isEmpty) {
      return const Center(
        child: Text('Start typing to search',
            style: TextStyle(color: ShowSnapColors.grey600)),
      );
    }
    final moviesAsync = ref.watch(_allMoviesProvider);
    return moviesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (movies) {
        final results = movies
            .where((m) =>
                m.title.toLowerCase().contains(query.toLowerCase()))
            .toList();
        if (results.isEmpty) {
          return const Center(
            child: Text('No results found',
                style: TextStyle(color: ShowSnapColors.grey600)),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 66),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.48,
          ),
          itemCount: results.length,
          itemBuilder: (_, i) => MovieCard(movie: results[i], heroTagSuffix: 'explore_search'),
        );
      },
    );
  }
}

// ─── Movies Tab ───────────────────────────────────────────────────────────────

class _MoviesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(_allMoviesProvider);

    return moviesAsync.when(
      loading: () => _GridShimmer(),
      error: (e, _) => Center(child: Text('Error loading movies: $e')),
      data: (movies) {
        if (movies.isEmpty) {
          return const Center(
            child: Text('No movies available',
                style: TextStyle(color: ShowSnapColors.grey600)),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 66),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.46,
          ),
          itemCount: movies.length,
          itemBuilder: (_, i) => MovieCard(movie: movies[i], heroTagSuffix: 'explore_movies')
              .animate()
              .fadeIn(
                  duration: ShowSnapDuration.normal,
                  delay: Duration(milliseconds: 30 * i))
              .slideY(begin: 0.05, end: 0,
                  delay: Duration(milliseconds: 30 * i)),
        );
      },
    );
  }
}

// ─── Events Tab ───────────────────────────────────────────────────────────────

class _EventsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(_allEventsProvider);
    return eventsAsync.when(
      loading: () => _GridShimmer(),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (events) {
        if (events.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.celebration_outlined,
                    size: 64, color: ShowSnapColors.grey300),
                SizedBox(height: 12),
                Text('No events available right now',
                    style: TextStyle(color: ShowSnapColors.grey600)),
              ],
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            if (events.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text('No events available',
                      style: TextStyle(color: ShowSnapColors.grey600)),
                ),
              )
            else
              ...AppConstants.eventCategories.map((category) {
                final catEvents = events.where((e) => e.category.toLowerCase() == category.toLowerCase()).toList();
                if (catEvents.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                return SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Text(category, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(
                        height: 218,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: catEvents.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (_, i) => EventCard(event: catEvents[i])
                              .animate()
                              .fadeIn(delay: Duration(milliseconds: 30 * i)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              }),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }
}

// ─── Theaters Tab ─────────────────────────────────────────────────────────────

class _TheatersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theatersAsync = ref.watch(_allTheatersProvider);
    return theatersAsync.when(
      loading: () => ListView.builder(
        itemCount: 4,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 8),
          child: Shimmer.fromColors(
            baseColor: ShowSnapColors.grey300,
            highlightColor: ShowSnapColors.grey100,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: ShowSnapColors.grey300,
                borderRadius:
                    BorderRadius.circular(ShowSnapRadius.md),
              ),
            ),
          ),
        ),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (theaters) {
        if (theaters.isEmpty) {
          return const Center(
            child: Text('No theaters found',
                style: TextStyle(color: ShowSnapColors.grey600)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 66),
          itemCount: theaters.length,
          itemBuilder: (_, i) => _TheaterRow(theater: theaters[i])
              .animate()
              .fadeIn(
                  duration: ShowSnapDuration.normal,
                  delay: Duration(milliseconds: 50 * i))
              .slideX(
                  begin: 0.05,
                  end: 0,
                  delay: Duration(milliseconds: 50 * i)),
        );
      },
    );
  }
}

class _TheaterRow extends StatelessWidget {
  final TheaterModel theater;
  const _TheaterRow({required this.theater});

  @override
  Widget build(BuildContext context) {
    return TappableScale(
      onTap: () => context.push('/theater/${theater.theaterId}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ShowSnapColors.surface,
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          boxShadow: ShowSnapShadow.card,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: ShowSnapColors.primaryLighter,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.theaters_rounded,
                  color: ShowSnapColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(theater.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(theater.city,
                      style: const TextStyle(
                          color: ShowSnapColors.grey600, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: ShowSnapColors.grey600),
          ],
        ),
      ),
    );
  }
}



// ─── Grid Shimmer ─────────────────────────────────────────────────────────────

class _GridShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.48,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: ShowSnapColors.grey300,
        highlightColor: ShowSnapColors.grey100,
        child: Container(
          decoration: BoxDecoration(
            color: ShowSnapColors.grey300,
            borderRadius: BorderRadius.circular(ShowSnapRadius.sm),
          ),
        ),
      ),
    );
  }
}
