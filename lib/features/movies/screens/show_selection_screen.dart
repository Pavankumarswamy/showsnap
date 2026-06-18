import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/booking_provider.dart';

import '../../../core/config/theme.dart';
import '../../../core/models/show_model.dart';
import '../../../core/models/theater_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/extensions.dart';

final _userLocationProvider = FutureProvider.autoDispose<Position?>((ref) async {
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }
    return await Geolocator.getLastKnownPosition() ?? await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
  } catch (_) {
    return null;
  }
});

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
    
    List<DateTime> displayDates = [];
    if (showsAsync.hasValue && showsAsync.value != null) {
      final theaterShows = showsAsync.value!;
      final Set<String> validDateStrings = {};
      for (final shows in theaterShows.values) {
        for (final s in shows) {
          if (s.seats.isNotEmpty && s.startTs > DateTime.now().millisecondsSinceEpoch) {
            final dt = DateTime.fromMillisecondsSinceEpoch(s.startTs);
            validDateStrings.add('${dt.year}-${dt.month}-${dt.day}');
          }
        }
      }
      displayDates = _dates.where((d) => validDateStrings.contains('${d.year}-${d.month}-${d.day}')).toList();
      
      // Auto-select the first available date if the current selection is invalid
      if (displayDates.isNotEmpty) {
        final currentValid = displayDates.any((d) => d.year == _selectedDate.year && d.month == _selectedDate.month && d.day == _selectedDate.day);
        if (!currentValid) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedDate = displayDates.first);
          });
        }
      }
    } else {
      displayDates = _dates;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Show'),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
        ),
        flexibleSpace: ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
          child: Container(
            decoration: BoxDecoration(gradient: ShowSnapTheme.appBarGradient),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: _DateSelector(
            dates: displayDates,
            selected: _selectedDate,
            onSelect: (d) => setState(() => _selectedDate = d),
          ),
        ),
      ),
      body: Column(
        children: [
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
                    if (s.seats.isEmpty) return false; // Hide unconfigured shows
                    final dt =
                        DateTime.fromMillisecondsSinceEpoch(s.startTs);
                    final isSameDay = dt.year == _selectedDate.year &&
                        dt.month == _selectedDate.month &&
                        dt.day == _selectedDate.day;
                    final isFuture = s.startTs > DateTime.now().millisecondsSinceEpoch;
                    return isSameDay && isFuture;
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
      color: Colors.transparent,
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
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? ShowSnapColors.primary
                    : ShowSnapColors.surface.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ShowSnapRadius.pill),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: ShowSnapColors.primary.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
                border: Border.all(
                  color: isSelected
                      ? ShowSnapColors.primary
                      : ShowSnapColors.grey300.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    d.dayShort,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : Colors.white70,
                    ),
                  ),
                  Text(
                    d.dayNum,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : Colors.white,
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
    final locationAsync = ref.watch(_userLocationProvider);
    final userPos = locationAsync.valueOrNull;
    final theatersAsync = ref.watch(allTheatersProvider);

    return theatersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (theaters) {
        final theaterMap = {for (final t in theaters) t.theaterId: t};

        // Sort theater IDs by distance from user (nearest first)
        final sortedTheaterIds = theaterShows.keys.toList()
          ..sort((a, b) {
            if (userPos == null) return 0;
            final tA = theaterMap[a];
            final tB = theaterMap[b];
            if (tA == null || tA.lat == 0) return 1;
            if (tB == null || tB.lat == 0) return -1;
            final distA = Geolocator.distanceBetween(userPos.latitude, userPos.longitude, tA.lat, tA.lng);
            final distB = Geolocator.distanceBetween(userPos.latitude, userPos.longitude, tB.lat, tB.lng);
            return distA.compareTo(distB);
          });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedTheaterIds.length,
          itemBuilder: (_, i) {
            final theaterId = sortedTheaterIds[i];
            final shows = theaterShows[theaterId]!;
            final theater = theaterMap[theaterId];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            (theater?.name ?? theaterId).toUpperCase(),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (theater != null && userPos != null && theater.lat != 0 && theater.lng != 0)
                          Builder(
                            builder: (context) {
                              final dist = Geolocator.distanceBetween(
                                userPos.latitude, userPos.longitude,
                                theater.lat, theater.lng,
                              );
                              final distKm = (dist / 1000).toStringAsFixed(1);
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ShowSnapColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: ShowSnapColors.primary.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on, size: 10, color: ShowSnapColors.primary),
                                    const SizedBox(width: 2),
                                    Text(
                                      '$distKm km',
                                      style: const TextStyle(fontSize: 10, color: ShowSnapColors.primary, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              );
                            }
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Builder(
                      builder: (context) {
                        final screenIds = shows.map((s) => s.screenId).toSet().toList();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                for (int idx = 0; idx < screenIds.length; idx++)
                                  Consumer(
                                    builder: (context, ref, child) {
                                      final sid = screenIds[idx];
                                      final screenAsync = ref.watch(screenProvider(sid));
                                      final name = (screenAsync.valueOrNull?.name ?? sid).toUpperCase();
                                      final suffix = idx < screenIds.length - 1 ? ',' : '  •  ${(theater?.city ?? '').toUpperCase()}';
                                      return Text(
                                        '$name$suffix',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: ShowSnapColors.grey600, fontWeight: FontWeight.w500),
                                      );
                                    },
                                  ),
                              ],
                            ),
                            if (theater?.address.isNotEmpty == true) ...[
                              const SizedBox(height: 2),
                              Text(
                                theater!.address,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: ShowSnapColors.grey600.withOpacity(0.7), fontSize: 10),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: shows.map((s) {
                        final dt =
                            DateTime.fromMillisecondsSinceEpoch(s.startTs);
                        Color bg;
                        Color fg;
                        Border? border;
                        Gradient? gradient;
                        if (!s.bookingOpen || s.isSoldOut) {
                          bg = ShowSnapColors.grey300;
                          fg = ShowSnapColors.grey600;
                          gradient = null;
                        } else if (s.seatsAvailable < 20) {
                          bg = Colors.orange.shade100;
                          fg = Colors.orange.shade800;
                          gradient = null;
                        } else {
                          bg = Colors.transparent;
                          fg = const Color(0xFF1B7A3E);
                          gradient = const LinearGradient(
                            colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          );
                          border = Border.all(color: const Color(0xFF66BB6A).withOpacity(0.6), width: 1.5);
                        }
                        return GestureDetector(
                          onTap: s.bookingOpen && !s.isSoldOut
                              ? () => context
                                  .push('/seat-selection/${s.showId}', extra: s)
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: bg,
                              gradient: gradient,
                              borderRadius: BorderRadius.circular(8),
                              border: border,
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
