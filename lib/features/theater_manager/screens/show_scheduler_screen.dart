import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/config/router.dart';
import '../../../core/config/staff_theme.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/movie_model.dart';
import '../../../core/models/screen_model.dart';
import '../../../core/models/seat_status_model.dart';
import '../../../core/models/show_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/showsnap_toast.dart';

final _schedulerDataProvider = FutureProvider<
    ({
      List<MovieModel> movies,
      List<ScreenModel> screens,
      List<ShowModel> shows,
      String theaterId,
    })>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) {
    return (
      movies: <MovieModel>[],
      screens: <ScreenModel>[],
      shows: <ShowModel>[],
      theaterId: ''
    );
  }
  final db = ref.watch(databaseServiceProvider);
  final theaters = await db.getAllTheaters();
  final theater = theaters
      .cast<dynamic>()
      .firstWhere((t) => t.managerId == uid, orElse: () => null);
  if (theater == null) {
    return (
      movies: <MovieModel>[],
      screens: <ScreenModel>[],
      shows: <ShowModel>[],
      theaterId: ''
    );
  }

  final movies = await db.getAllMovies();
  final screens = await db.getScreensForTheater(theater.theaterId);
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

    return PushDrawerLayout(
      backgroundColor: TMColors.background,
      drawer: TMDrawer(
        currentRoute: AppRoutes.showScheduler,
        onNavigateTo: (route) => context.push(route),
        theaterName: 'My Theater',
      ),
      appBar: AppBar(
        backgroundColor: TMColors.surface,
        foregroundColor: TMColors.textPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: TMColors.border),
        ),
        title: const Text(
          'Show Scheduler',
          style: TextStyle(
              color: TMColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => dataAsync.whenData(
          (data) => _showAddShowBottomSheet(
              context, ref, data.movies, data.screens, data.theaterId),
        ),
        label:
            const Text('Add Show', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
        backgroundColor: TMColors.primary,
        foregroundColor: Colors.black,
      ).animate().scale(delay: 300.ms, duration: 400.ms, curve: Curves.elasticOut),
      body: dataAsync.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 3,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: StaffShimmerCard(
              height: 130,
              baseColor: TMColors.surface,
              highlightColor: TMColors.surfaceElevated,
            ),
          ),
        ),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: AdminColors.error))),
        data: (data) {
          if (data.screens.isEmpty) {
            return StaffEmptyState(
              icon: Icons.theaters_outlined,
              message: 'Add screens before scheduling shows.',
            );
          }
          return _ShowGrid(
            shows: data.shows,
            screens: data.screens,
            movies: data.movies,
          ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.05, end: 0);
        },
      ),
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
      backgroundColor: TMColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddShowForm(
          movies: movies, screens: screens, theaterId: theaterId, ref: ref),
    );
  }
}

// ─── Show grid ────────────────────────────────────────────────────────────────

class _ShowGrid extends StatefulWidget {
  final List<ShowModel> shows;
  final List<ScreenModel> screens;
  final List<MovieModel> movies;

  const _ShowGrid(
      {required this.shows, required this.screens, required this.movies});

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
      return StaffEmptyState(
        icon: Icons.event_available_outlined,
        message: 'No shows scheduled yet.\nTap + to add a show.',
      );
    }

    final dateShows = widget.shows.where((s) {
      final dt = DateTime.fromMillisecondsSinceEpoch(s.startTs);
      return dt.year == _selectedDate.year &&
          dt.month == _selectedDate.month &&
          dt.day == _selectedDate.day;
    }).toList();

    return Column(
      children: [
        _DateStrip(
          dates: _dates,
          selected: _selectedDate,
          onSelect: (d) => setState(() => _selectedDate = d),
        ),
        Expanded(
          child: dateShows.isEmpty
              ? StaffEmptyState(
                  icon: Icons.event_busy_outlined,
                  message: 'No shows on ${_selectedDate.dateLabel}',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: widget.screens.length,
                  itemBuilder: (_, si) {
                    final screen = widget.screens[si];
                    final screenShows = dateShows
                        .where((s) => s.screenId == screen.screenId)
                        .toList()
                      ..sort((a, b) => a.startTs.compareTo(b.startTs));

                    if (screenShows.isEmpty) return const SizedBox.shrink();

                    final movieShows = <String, List<ShowModel>>{};
                    for (final s in screenShows) {
                      movieShows.putIfAbsent(s.movieId, () => []).add(s);
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            screen.name,
                            style: const TextStyle(
                                color: TMColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.5),
                          ),
                        ),
                        ...movieShows.entries.map((entry) {
                          final movieId = entry.key;
                          final shows = entry.value;
                          final movie = widget.movies.firstWhere(
                              (m) => m.movieId == movieId,
                              orElse: () =>
                                  MovieModel(movieId: movieId, title: 'Unknown'));
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: TMColors.surface,
                              borderRadius:
                                  BorderRadius.circular(ShowSnapRadius.md),
                              border: Border.all(color: TMColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  movie.title,
                                  style: const TextStyle(
                                      color: TMColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: shows.map((s) {
                                    final dt = DateTime.fromMillisecondsSinceEpoch(
                                        s.startTs);
                                    final noLayout = s.seats.isEmpty;
                                    final soldOut =
                                        s.isSoldOut && !noLayout;
                                    Color bg, fg;

                                    if (!s.bookingOpen || soldOut || noLayout) {
                                      bg = TMColors.surfaceElevated;
                                      fg = TMColors.textMuted;
                                    } else if (s.seatsAvailable < 20) {
                                      bg = const Color(0xFFFF8F00).withOpacity(0.15);
                                      fg = const Color(0xFFFF8F00);
                                    } else {
                                      bg = TMColors.primary.withOpacity(0.12);
                                      fg = TMColors.primary;
                                    }

                                    return GestureDetector(
                                      onTap: () => context.push(
                                          '/tm/show-details/${s.showId}'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: bg,
                                          borderRadius: BorderRadius.circular(
                                              ShowSnapRadius.sm),
                                          border: Border.all(
                                              color: fg.withOpacity(0.3)),
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
                                                  color: fg, fontSize: 10),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          );
                        }),
                        const Divider(color: TMColors.border, height: 1),
                        const SizedBox(height: 4),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Date strip ───────────────────────────────────────────────────────────────

class _DateStrip extends StatelessWidget {
  final List<DateTime> dates;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  const _DateStrip({
    required this.dates,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      color: TMColors.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                color: isSelected ? TMColors.primary : TMColors.surfaceElevated,
                borderRadius: BorderRadius.circular(ShowSnapRadius.sm),
                border: Border.all(
                  color: isSelected ? TMColors.primary : TMColors.border,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    d.dayShort,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? Colors.black : TMColors.textMuted,
                    ),
                  ),
                  Text(
                    d.dayNum,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.black : TMColors.textPrimary,
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

// ─── Add show form ────────────────────────────────────────────────────────────

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
      final endDt =
          startDt.add(Duration(minutes: _selectedMovie!.durationMinutes + 15));

      final db = ref.read(databaseServiceProvider);
      final existingShows = await db.getShowsForTheaterScreen(
          widget.theaterId, _selectedScreen!.screenId);
      for (final existing in existingShows) {
        final existStart = DateTime.fromMillisecondsSinceEpoch(existing.startTs);
        final existEnd = DateTime.fromMillisecondsSinceEpoch(existing.endTs);
        if (startDt.isBefore(existEnd) && endDt.isAfter(existStart)) {
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
      if (mounted) {
        Navigator.pop(context);
        ShowSnapToast.success(context, 'Show scheduled');
      }
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
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: TMColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Add Show',
              style: TextStyle(
                  color: TMColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _tmDropdown<MovieModel>(
              label: 'Movie',
              value: _selectedMovie,
              items: widget.movies,
              labelOf: (m) => m.title,
              onChanged: (v) => setState(() => _selectedMovie = v),
            ),
            const SizedBox(height: 12),
            _tmDropdown<ScreenModel>(
              label: 'Screen',
              value: _selectedScreen,
              items: widget.screens,
              labelOf: (s) => s.name,
              onChanged: (v) => setState(() => _selectedScreen = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DarkPickerButton(
                    icon: Icons.calendar_today,
                    label: DateFormat('dd MMM').format(_selectedDate),
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
                  child: _DarkPickerButton(
                    icon: Icons.access_time_outlined,
                    label: _startTime.format(context),
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
            const Text(
              'Pricing',
              style: TextStyle(
                  color: TMColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: _pricingCtrls.entries.map((e) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextField(
                      controller: e.value,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: TMColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: e.key.capitalize,
                        labelStyle:
                            const TextStyle(color: TMColors.textSecondary),
                        prefixText: '₹',
                        prefixStyle:
                            const TextStyle(color: TMColors.textSecondary),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(ShowSnapRadius.sm),
                          borderSide:
                              const BorderSide(color: TMColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(ShowSnapRadius.sm),
                          borderSide:
                              const BorderSide(color: TMColors.primary),
                        ),
                        filled: true,
                        fillColor: TMColors.surfaceElevated,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_conflictError != null) ...[
              const SizedBox(height: 8),
              Text(
                _conflictError!,
                style: const TextStyle(
                    color: AdminColors.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: TMColors.primary,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ShowSnapRadius.md)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Text('Schedule Show',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

DropdownButtonFormField<T> _tmDropdown<T>({
  required String label,
  required T? value,
  required List<T> items,
  required String Function(T) labelOf,
  required void Function(T?) onChanged,
}) {
  return DropdownButtonFormField<T>(
    value: value,
    hint: Text(label, style: const TextStyle(color: TMColors.textMuted)),
    dropdownColor: TMColors.surfaceElevated,
    style: const TextStyle(color: TMColors.textPrimary),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: TMColors.textSecondary),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        borderSide: const BorderSide(color: TMColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        borderSide: const BorderSide(color: TMColors.primary),
      ),
      filled: true,
      fillColor: TMColors.surfaceElevated,
    ),
    items:
        items.map((t) => DropdownMenuItem(value: t, child: Text(labelOf(t)))).toList(),
    onChanged: onChanged,
  );
}

class _DarkPickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _DarkPickerButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 16, color: TMColors.textSecondary),
      label: Text(label,
          style: const TextStyle(color: TMColors.textPrimary, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        backgroundColor: TMColors.surfaceElevated,
        side: const BorderSide(color: TMColors.border),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ShowSnapRadius.md)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onPressed: onPressed,
    );
  }
}
