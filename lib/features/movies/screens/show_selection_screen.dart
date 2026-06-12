import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/booking_provider.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/show_model.dart';
import '../../../core/models/theater_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/extensions.dart';

class ShowSelectionScreen extends ConsumerStatefulWidget {
  final String movieId;
  const ShowSelectionScreen({super.key, required this.movieId});

  @override
  ConsumerState<ShowSelectionScreen> createState() =>
      _ShowSelectionScreenState();
}

class _ShowSelectionScreenState extends ConsumerState<ShowSelectionScreen> {
  late DateTime _selectedDate;
  final _dates = <DateTime>[];

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _selectedDate = today;
    for (var i = 0; i < 7; i++) {
      _dates.add(today.add(Duration(days: i)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final showsAsync = ref.watch(showsForMovieProvider(widget.movieId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Show'),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: ShowSnapTheme.appBarGradient),
        ),
      ),
      body: Column(
        children: [
          _DateSelector(
            dates: _dates,
            selected: _selectedDate,
            onSelect: (d) => setState(() => _selectedDate = d),
          ),
          Expanded(
            child: showsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Error: $e')),
              data: (theaterShows) {
                if (theaterShows.isEmpty) {
                  return const Center(
                    child: Text('No shows available for this movie'),
                  );
                }
                // Filter shows for selected date
                final filtered = <String, List<ShowModel>>{};
                theaterShows.forEach((tid, shows) {
                  final day = shows.where((s) {
                    final dt =
                        DateTime.fromMillisecondsSinceEpoch(s.startTs);
                    return dt.year == _selectedDate.year &&
                        dt.month == _selectedDate.month &&
                        dt.day == _selectedDate.day;
                  }).toList();
                  if (day.isNotEmpty) filtered[tid] = day;
                });

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                        'No shows on ${_selectedDate.dateLabel}'),
                  );
                }

                return _TheaterShowList(
                    theaterShows: filtered);
              },
            ),
          ),
        ],
      ),
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
      height: 72,
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
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

class _TheaterShowList extends ConsumerWidget {
  final Map<String, List<ShowModel>> theaterShows;
  const _TheaterShowList({required this.theaterShows});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<TheaterModel>>(
      future: ref.read(databaseServiceProvider).getAllTheaters(),
      builder: (context, snap) {
        final theaters = snap.data ?? [];
        final theaterMap = {for (final t in theaters) t.theaterId: t};

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: theaterShows.length,
          itemBuilder: (_, i) {
            final theaterId = theaterShows.keys.elementAt(i);
            final shows = theaterShows[theaterId]!;
            final theater = theaterMap[theaterId];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      theater?.name ?? theaterId,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (theater?.address.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        theater!.address,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: ShowSnapColors.grey600),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: shows.map((s) {
                        final dt =
                            DateTime.fromMillisecondsSinceEpoch(s.startTs);
                        Color bg;
                        Color fg;
                        if (!s.bookingOpen || s.isSoldOut) {
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
                          onTap: s.bookingOpen && !s.isSoldOut
                              ? () => context
                                  .push('/seat-selection/${s.showId}')
                              : null,
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
                                  s.isSoldOut
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
          },
        );
      },
    );
  }
}
