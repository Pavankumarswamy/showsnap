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

// ─── Providers ────────────────────────────────────────────────────────────────

final _allMoviesProvider = FutureProvider<List<MovieModel>>((ref) =>
    ref.watch(databaseServiceProvider).getAllMovies());

final _allEventsProvider = FutureProvider<List<EventModel>>((ref) =>
    ref.watch(databaseServiceProvider).getAllEvents());

final _allTheatersProvider = FutureProvider<List<TheaterModel>>((ref) =>
    ref.watch(databaseServiceProvider).getAllTheaters());

// Filter state
class _MovieFilters {
  final List<String> genres;
  final List<String> languages;
  final List<String> certificates;
  final String sortBy;
  const _MovieFilters({
    this.genres = const [],
    this.languages = const [],
    this.certificates = const [],
    this.sortBy = 'Relevance',
  });
  _MovieFilters copyWith({
    List<String>? genres,
    List<String>? languages,
    List<String>? certificates,
    String? sortBy,
  }) =>
      _MovieFilters(
        genres: genres ?? this.genres,
        languages: languages ?? this.languages,
        certificates: certificates ?? this.certificates,
        sortBy: sortBy ?? this.sortBy,
      );
  bool get hasFilters =>
      genres.isNotEmpty ||
      languages.isNotEmpty ||
      certificates.isNotEmpty ||
      sortBy != 'Relevance';
}

final _movieFiltersProvider =
    StateProvider<_MovieFilters>((ref) => const _MovieFilters());

// ─── ExploreScreen ────────────────────────────────────────────────────────────

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

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
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShowSnapColors.grey100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: _searchActive
            ? _SearchBar(
                ctrl: _searchCtrl,
                onClose: () {
                  setState(() {
                    _searchActive = false;
                    _searchCtrl.clear();
                  });
                },
              )
            : const Text('Explore',
                style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (!_searchActive)
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () => setState(() => _searchActive = true),
            ),
        ],
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
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.55,
          ),
          itemCount: results.length,
          itemBuilder: (_, i) => MovieCard(movie: results[i]),
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
    final filters = ref.watch(_movieFiltersProvider);

    return Column(
      children: [
        // Filter bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              TappableScale(
                onTap: () => _showFilterSheet(context, ref, filters),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: filters.hasFilters
                        ? ShowSnapColors.primaryLighter
                        : ShowSnapColors.grey100,
                    borderRadius:
                        BorderRadius.circular(ShowSnapRadius.pill),
                    border: Border.all(
                        color: filters.hasFilters
                            ? ShowSnapColors.primary
                            : ShowSnapColors.grey300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        filters.hasFilters
                            ? 'Filters (${_filterCount(filters)})'
                            : 'Filter',
                        style:
                            const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: moviesAsync.when(
            loading: () => _GridShimmer(),
            error: (e, _) =>
                Center(child: Text('Error loading movies: $e')),
            data: (movies) {
              final filtered = _applyFilters(movies, filters);
              if (filtered.isEmpty) {
                return const Center(
                  child: Text('No movies match your filters',
                      style: TextStyle(color: ShowSnapColors.grey600)),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.55,
                ),
                itemCount: filtered.length,
                itemBuilder: (_, i) => MovieCard(movie: filtered[i])
                    .animate()
                    .fadeIn(
                        duration: ShowSnapDuration.normal,
                        delay: Duration(milliseconds: 30 * i))
                    .slideY(begin: 0.05, end: 0,
                        delay: Duration(milliseconds: 30 * i)),
              );
            },
          ),
        ),
      ],
    );
  }

  int _filterCount(_MovieFilters f) =>
      f.genres.length +
      f.languages.length +
      f.certificates.length +
      (f.sortBy != 'Relevance' ? 1 : 0);

  List<MovieModel> _applyFilters(List<MovieModel> movies, _MovieFilters f) {
    var list = movies.toList();
    if (f.genres.isNotEmpty) {
      list = list.where((m) => m.genres.any(f.genres.contains)).toList();
    }
    if (f.languages.isNotEmpty) {
      list = list.where((m) => f.languages.contains(m.language)).toList();
    }
    if (f.certificates.isNotEmpty) {
      list = list
          .where((m) => f.certificates.contains(m.certificate))
          .toList();
    }
    switch (f.sortBy) {
      case 'Rating':
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'Release Date':
        list.sort(
            (a, b) => b.releaseDateTs.compareTo(a.releaseDateTs));
        break;
    }
    return list;
  }

  void _showFilterSheet(
      BuildContext context, WidgetRef ref, _MovieFilters current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(ShowSnapRadius.lg))),
      builder: (_) => _MovieFilterSheet(
        current: current,
        onApply: (f) =>
            ref.read(_movieFiltersProvider.notifier).state = f,
      ),
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
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: events.length,
          itemBuilder: (_, i) => EventCard(event: events[i])
              .animate()
              .fadeIn(
                  duration: ShowSnapDuration.normal,
                  delay: Duration(milliseconds: 30 * i)),
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
          padding: const EdgeInsets.all(16),
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
          color: Colors.white,
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

// ─── Movie Filter Sheet ───────────────────────────────────────────────────────

class _MovieFilterSheet extends StatefulWidget {
  final _MovieFilters current;
  final void Function(_MovieFilters) onApply;
  const _MovieFilterSheet(
      {required this.current, required this.onApply});

  @override
  State<_MovieFilterSheet> createState() => _MovieFilterSheetState();
}

class _MovieFilterSheetState extends State<_MovieFilterSheet> {
  late _MovieFilters _draft;
  static const _genres = [
    'Action', 'Drama', 'Comedy', 'Thriller',
    'Horror', 'Romance', 'Sci-Fi',
  ];
  static const _langs = [
    'Telugu', 'Hindi', 'English', 'Tamil', 'Malayalam',
  ];
  static const _certs = ['U', 'UA', 'A'];
  static const _sorts = [
    'Relevance', 'Release Date', 'Rating',
  ];

  @override
  void initState() {
    super.initState();
    _draft = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(
                  color: ShowSnapColors.grey300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Filter Movies',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 18)),
                TextButton(
                    onPressed: () {
                      setState(() => _draft = const _MovieFilters());
                    },
                    child: const Text('Clear All')),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(16),
              children: [
                _FilterSection(
                    title: 'Genre',
                    items: _genres,
                    selected: _draft.genres,
                    onToggle: (g) => setState(() {
                          final l = List<String>.from(_draft.genres);
                          l.contains(g) ? l.remove(g) : l.add(g);
                          _draft = _draft.copyWith(genres: l);
                        })),
                const SizedBox(height: 16),
                _FilterSection(
                    title: 'Language',
                    items: _langs,
                    selected: _draft.languages,
                    onToggle: (l) => setState(() {
                          final list =
                              List<String>.from(_draft.languages);
                          list.contains(l) ? list.remove(l) : list.add(l);
                          _draft = _draft.copyWith(languages: list);
                        })),
                const SizedBox(height: 16),
                _FilterSection(
                    title: 'Certificate',
                    items: _certs,
                    selected: _draft.certificates,
                    onToggle: (c) => setState(() {
                          final l =
                              List<String>.from(_draft.certificates);
                          l.contains(c) ? l.remove(c) : l.add(c);
                          _draft = _draft.copyWith(certificates: l);
                        })),
                const SizedBox(height: 16),
                const Text('Sort By',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _sorts.map((s) {
                    final isActive = _draft.sortBy == s;
                    return ChoiceChip(
                      label: Text(s),
                      selected: isActive,
                      selectedColor: ShowSnapColors.primaryLighter,
                      onSelected: (_) =>
                          setState(() => _draft = _draft.copyWith(sortBy: s)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: DecoratedBox(
                decoration: ShowSnapTheme.primaryButtonDecoration,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            ShowSnapRadius.md)),
                  ),
                  onPressed: () {
                    widget.onApply(_draft);
                    Navigator.pop(context);
                  },
                  child: const Text('Apply Filters',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  final String title;
  final List<String> items;
  final List<String> selected;
  final void Function(String) onToggle;
  const _FilterSection(
      {required this.title,
      required this.items,
      required this.selected,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            final isSelected = selected.contains(item);
            return FilterChip(
              label: Text(item),
              selected: isSelected,
              selectedColor: ShowSnapColors.primaryLighter,
              checkmarkColor: ShowSnapColors.primary,
              onSelected: (_) => onToggle(item),
            );
          }).toList(),
        ),
      ],
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
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.55,
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
