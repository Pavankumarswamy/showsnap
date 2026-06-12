import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/movie_model.dart';
import '../../../core/models/screen_model.dart';
import '../../../core/models/show_model.dart';
import '../../../core/models/seat_status_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/extensions.dart';
import '../../movies/providers/booking_provider.dart';

final _schedulerDataProvider = FutureProvider<
    ({
      List<MovieModel> movies,
      List<ScreenModel> screens,
      List<ShowModel> shows,
      String theaterId,
    })>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) {
    return (movies: <MovieModel>[], screens: <ScreenModel>[], shows: <ShowModel>[], theaterId: '');
  }
  final db = ref.watch(databaseServiceProvider);
  final theaters = await db.getAllTheaters();
  final theater =
      theaters.cast<dynamic>().firstWhere((t) => t.managerId == uid, orElse: () => null);
  if (theater == null) {
    return (movies: <MovieModel>[], screens: <ScreenModel>[], shows: <ShowModel>[], theaterId: '');
  }

  final movies = await db.getAllMovies();
  final screens = await db.getScreensForTheater(theater.theaterId);

  // Get all shows for this theater's screens
  final allShows = <ShowModel>[];
  for (final screen in screens) {
    final shows = await db.getShowsForTheaterScreen(
        theater.theaterId, screen.screenId);
    allShows.addAll(shows);
  }

  return (
    movies: movies.where((m) => m.status == 'nowShowing').toList(),
    screens: screens,
    shows: allShows,
    theaterId: theater.theaterId as String,
  );
});

class ShowSchedulerScreen extends ConsumerWidget {
  const ShowSchedulerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_schedulerDataProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Show Scheduler'),
        toolbarHeight: 70,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        flexibleSpace: Container(
          decoration:
              BoxDecoration(gradient: ShowSnapTheme.appBarGradient),
        ),
      ),
      body: dataAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data.screens.isEmpty) {
            return const Center(
                child: Text('Add screens first before scheduling shows'));
          }
          final showsStream = ref.watch(theaterShowsStreamProvider(data.theaterId));
          return showsStream.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading shows: $e')),
            data: (realTimeShows) => Column(
              children: [
                Expanded(
                  child: _ShowGrid(
                      shows: realTimeShows, screens: data.screens, movies: data.movies)
                    .animate()
                    .fadeIn(duration: 450.ms)
                    .slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => dataAsync.whenData(
          (data) => _showAddShowBottomSheet(context, ref, data.movies,
              data.screens, data.theaterId),
        ),
        label: const Text('Add Show'),
        icon: const Icon(Icons.add),
        backgroundColor: ShowSnapColors.primary,
      ).animate().scale(delay: 300.ms, duration: 400.ms, curve: Curves.elasticOut),
    );
  }

  void _showAddShowBottomSheet(
    BuildContext context,
    WidgetRef ref,
    List<MovieModel> movies,
    List<ScreenModel> screens,
    String theaterId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _AddShowForm(
          movies: movies, screens: screens, theaterId: theaterId, ref: ref),
    );
  }
}



class _ShowGrid extends StatefulWidget {
  final List<ShowModel> shows;
  final List<ScreenModel> screens;
  final List<MovieModel> movies;
  const _ShowGrid({required this.shows, required this.screens, required this.movies});

  @override
  State<_ShowGrid> createState() => _ShowGridState();
}

class _ShowGridState extends State<_ShowGrid> {
  late DateTime _selectedDate;
  final _dates = <DateTime>[];

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _selectedDate = today;
    for (var i = 0; i < 30; i++) {
      _dates.add(today.add(Duration(days: i)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.shows.isEmpty) {
      return const Center(child: Text('No shows scheduled yet'));
    }

    final dateShows = widget.shows.where((s) {
      final dt = DateTime.fromMillisecondsSinceEpoch(s.startTs);
      return dt.year == _selectedDate.year &&
          dt.month == _selectedDate.month &&
          dt.day == _selectedDate.day;
    }).toList();

    return Column(
      children: [
        const SizedBox(height: 8),
        _DateSelector(
          dates: _dates,
          selected: _selectedDate,
          onSelect: (d) => setState(() => _selectedDate = d),
        ),
        Expanded(
          child: dateShows.isEmpty
              ? Center(child: Text('No shows on ${_selectedDate.dateLabel}'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.screens.length,
                  itemBuilder: (_, si) {
                    final screen = widget.screens[si];
                    final screenShows = dateShows
                        .where((s) => s.screenId == screen.screenId)
                        .toList()
                      ..sort((a, b) => a.startTs.compareTo(b.startTs));

                    if (screenShows.isEmpty) return const SizedBox.shrink();

                    // Group by movieId
                    final movieShows = <String, List<ShowModel>>{};
                    for (final s in screenShows) {
                      movieShows.putIfAbsent(s.movieId, () => []).add(s);
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(screen.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ),
                        ...movieShows.entries.map((entry) {
                          final movieId = entry.key;
                          final shows = entry.value;
                          final movie = widget.movies.firstWhere((m) => m.movieId == movieId, orElse: () => MovieModel(movieId: movieId, title: 'Unknown Movie'));
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    movie.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: shows.map((s) {
                                      final dt = DateTime.fromMillisecondsSinceEpoch(s.startTs);
                                      Color bg;
                                      Color fg;
                                      
                                      final noLayout = s.seats.isEmpty;
                                      final soldOut = s.isSoldOut && !noLayout;

                                      if (!s.bookingOpen || soldOut || noLayout) {
                                        bg = ShowSnapColors.grey300;
                                        fg = ShowSnapColors.grey600;
                                      } else if (s.seatsAvailable < 20) {
                                        bg = Colors.orange.shade100;
                                        fg = Colors.orange.shade800;
                                      } else {
                                        bg = Colors.green.shade100;
                                        fg = Colors.green.shade800;
                                      }
                                      return GestureDetector(
                                        onTap: () => context.push('/tm/show-details/${s.showId}'),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: bg,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                DateFormat('h:mm a').format(dt),
                                                style: TextStyle(
                                                  color: fg,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Text(
                                                noLayout
                                                    ? 'NO LAYOUT'
                                                    : soldOut
                                                        ? 'SOLD OUT'
                                                        : !s.bookingOpen
                                                            ? 'CLOSED'
                                                            : '${s.seatsAvailable} left',
                                                style: TextStyle(
                                                  color: fg,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const Divider(),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DateSelector extends StatelessWidget {
  final List<DateTime> dates;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  const _DateSelector({
    required this.dates,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      color: ShowSnapColors.grey100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: dates.length,
        itemBuilder: (_, i) {
          final d = dates[i];
          final isSelected = d.year == selected.year &&
              d.month == selected.month &&
              d.day == selected.day;
          return GestureDetector(
            onTap: () => onSelect(d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? ShowSnapColors.primary
                    : ShowSnapColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? ShowSnapColors.primary
                      : ShowSnapColors.grey300,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    d.dayShort,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? ShowSnapColors.onPrimary
                          : ShowSnapColors.grey600,
                    ),
                  ),
                  Text(
                    d.dayNum,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? ShowSnapColors.onPrimary
                          : ShowSnapColors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AddShowForm extends ConsumerStatefulWidget {
  final List<MovieModel> movies;
  final List<ScreenModel> screens;
  final String theaterId;
  final WidgetRef ref;

  const _AddShowForm({
    required this.movies,
    required this.screens,
    required this.theaterId,
    required this.ref,
  });

  @override
  ConsumerState<_AddShowForm> createState() => _AddShowFormState();
}

class _AddShowFormState extends ConsumerState<_AddShowForm> {
  MovieModel? _selectedMovie;
  ScreenModel? _selectedScreen;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  final Map<String, TextEditingController> _pricingCtrls = {
    'silver': TextEditingController(text: '200'),
    'gold': TextEditingController(text: '300'),
    'platinum': TextEditingController(text: '500'),
  };
  bool _saving = false;
  String? _conflictError;

  @override
  void dispose() {
    for (final c in _pricingCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedMovie == null || _selectedScreen == null) {
      setState(() => _conflictError = 'Please select a movie and screen');
      return;
    }
    setState(() {
      _saving = true;
      _conflictError = null;
    });

    try {
      final startDt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      final endDt = startDt.add(
          Duration(minutes: _selectedMovie!.durationMinutes + 15));

      // Conflict check
      final db = ref.read(databaseServiceProvider);
      final existingShows = await db.getShowsForTheaterScreen(
          widget.theaterId, _selectedScreen!.screenId);
      for (final existing in existingShows) {
        final existStart =
            DateTime.fromMillisecondsSinceEpoch(existing.startTs);
        final existEnd =
            DateTime.fromMillisecondsSinceEpoch(existing.endTs);
        if (startDt.isBefore(existEnd) &&
            endDt.isAfter(existStart)) {
          setState(() {
            _conflictError =
                'Conflict with show at ${existing.startTs.epochToTimeLabel}';
            _saving = false;
          });
          return;
        }
      }

      final pricing = <String, int>{};
      _pricingCtrls.forEach((cat, ctrl) {
        pricing[cat] = int.tryParse(ctrl.text) ?? 0;
      });

      // Initialise seat statuses from screen layout
      final screen = _selectedScreen!;
      final seats = <String, SeatStatusModel>{};
      for (final seat in screen.seatLayout) {
        seats[seat.seatId] = const SeatStatusModel();
      }

      await db.createShow(ShowModel(
        showId: '',
        movieId: _selectedMovie!.movieId,
        theaterId: widget.theaterId,
        screenId: screen.screenId,
        startTs: startDt.millisecondsSinceEpoch,
        endTs: endDt.millisecondsSinceEpoch,
        pricing: pricing,
        bookingOpen: true,
        seats: seats,
        seatsAvailable: screen.seatLayout.length,
      ));

      widget.ref.invalidate(_schedulerDataProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _conflictError = 'Failed: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Add Show',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            DropdownButtonFormField<MovieModel>(
              value: _selectedMovie,
              hint: const Text('Select Movie'),
              decoration: const InputDecoration(labelText: 'Movie'),
              items: widget.movies
                  .map((m) => DropdownMenuItem(
                      value: m, child: Text(m.title)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedMovie = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ScreenModel>(
              value: _selectedScreen,
              hint: const Text('Select Screen'),
              decoration: const InputDecoration(labelText: 'Screen'),
              items: widget.screens
                  .map((s) => DropdownMenuItem(
                      value: s, child: Text(s.name)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedScreen = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(DateFormat('dd MMM').format(_selectedDate)),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (d != null) setState(() => _selectedDate = d);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text(_startTime.format(context)),
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: _startTime,
                      );
                      if (t != null) setState(() => _startTime = t);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Pricing',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: _pricingCtrls.entries.map((e) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextFormField(
                      controller: e.value,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: e.key.capitalize,
                          prefixText: '₹'),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_conflictError != null) ...[
              const SizedBox(height: 8),
              Text(_conflictError!,
                  style: const TextStyle(color: ShowSnapColors.error)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child:
                          CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Schedule Show'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
