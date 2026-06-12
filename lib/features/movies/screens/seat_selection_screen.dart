import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/booking_provider.dart';
import '../widgets/seat_map_widget.dart';
import '../../../core/config/router.dart';
import '../../../core/config/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/show_model.dart';
import '../../../core/models/seat_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/extensions.dart';

class SeatSelectionScreen extends ConsumerStatefulWidget {
  final String showId;
  const SeatSelectionScreen({super.key, required this.showId});

  @override
  ConsumerState<SeatSelectionScreen> createState() =>
      _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends ConsumerState<SeatSelectionScreen> {
  Timer? _lockTimer;
  int _secondsLeft = AppConstants.seatLockMinutes * 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showTicketQuantitySelector();
    });
  }

  void _showTicketQuantitySelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TicketQuantityBottomSheet(showId: widget.showId),
    );
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        ref
            .read(seatSelectionProvider(widget.showId).notifier)
            .setTimerExpired();
        _showTimerExpiredDialog();
      }
    });
  }

  void _showTimerExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Session Expired'),
        content: const Text(
            'Your seat locks have expired. Please select seats again.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showAsync = ref.watch(showStreamProvider(widget.showId));
    final selectionState = ref.watch(seatSelectionProvider(widget.showId));
    final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';

    ref.listen(seatSelectionProvider(widget.showId), (prev, next) {
      if (next.error != null) {
        context.showErrorSnackbar(next.error!);
        ref.read(seatSelectionProvider(widget.showId).notifier).clearError();
      }
    });

    return WillPopScope(
      onWillPop: () async {
        await ref
            .read(seatSelectionProvider(widget.showId).notifier)
            .releaseAllLocks();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Select Seats'),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
          ),
          flexibleSpace: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
            child: Container(
              decoration:
                  BoxDecoration(gradient: ShowSnapTheme.appBarGradient),
            ),
          ),

          actions: [
            if (selectionState.selectedSeatIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: _TimerChip(secondsLeft: _secondsLeft),
              ),
          ],
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await ref
                  .read(seatSelectionProvider(widget.showId).notifier)
                  .releaseAllLocks();
              if (mounted) context.pop();
            },
          ),
        ),
        body: showAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (show) {
            final screenAsync = ref.watch(screenProvider(show.screenId));
            return screenAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading screen layout: $e')),
              data: (screen) {
                if (screen == null) {
                  return const Center(child: Text('Screen layout not found'));
                }
                final layout = screen.seatLayout;
                return Column(
                  children: [
                    const SizedBox(height: 24),
                    Expanded(
                      child: SeatMapWidget(
                        seatLayout: layout,
                        show: show,
                        selectedSeatIds: selectionState.selectedSeatIds,
                        lockingInProgress: selectionState.lockInProgress.keys
                            .where((k) =>
                                selectionState.lockInProgress[k] == true)
                            .toSet(),
                        currentUid: uid,
                        onSeatTap: (seat) {
                          final state = ref.read(seatSelectionProvider(widget.showId));
                          final notifier = ref.read(seatSelectionProvider(widget.showId).notifier);

                          bool isAvailable(SeatModel s) {
                            final status = show.seats[s.seatId];
                            if (status == null) return true;
                            if (status.status.name == 'booked') return false;
                            if (status.status.name == 'locked' && status.lockedBy != uid && !status.isExpiredLock) return false;
                            return true;
                          }

                          if (state.requestedTickets == 0) {
                            if (state.selectedSeatIds.contains(seat.seatId)) {
                              notifier.toggleSeat(seat, show);
                            } else {
                              if (isAvailable(seat)) {
                                notifier.toggleSeat(seat, show);
                              }
                            }
                            return;
                          }
                          
                          if (state.selectedSeatIds.contains(seat.seatId)) {
                            notifier.releaseAllLocks();
                            return;
                          }

                          final rowSeats = layout.where((s) => s.row == seat.row).toList();
                          rowSeats.sort((a, b) => a.x.compareTo(b.x));
                          
                          final tappedIndex = rowSeats.indexWhere((s) => s.seatId == seat.seatId);
                          if (tappedIndex == -1) return;

                          List<SeatModel> candidates = [];
                          int needed = state.requestedTickets;
                          
                          // First try right
                          int currentX = seat.x - 1;
                          for (int i = tappedIndex; i < rowSeats.length; i++) {
                            final s = rowSeats[i];
                            if (!isAvailable(s) || s.x != currentX + 1) break;
                            candidates.add(s);
                            currentX = s.x;
                            if (candidates.length == needed) break;
                          }
                          
                          // If not enough, try sliding window around tap
                          if (candidates.length < needed) {
                            candidates = [];
                            for (int start = math.max(0, tappedIndex - needed + 1); start <= tappedIndex; start++) {
                              int end = start + needed - 1;
                              if (end >= rowSeats.length) continue;
                              
                              bool valid = true;
                              List<SeatModel> temp = [];
                              int curX = rowSeats[start].x - 1;
                              for (int j = start; j <= end; j++) {
                                final s = rowSeats[j];
                                if (!isAvailable(s) || s.x != curX + 1) {
                                  valid = false;
                                  break;
                                }
                                temp.add(s);
                                curX = s.x;
                              }
                              
                              if (valid) {
                                candidates = temp;
                                break;
                              }
                            }
                          }
                          
                          if (candidates.isNotEmpty) {
                             notifier.lockSeats(candidates, show);
                          } else {
                             if (mounted) {
                               context.showErrorSnackbar('Not enough contiguous seats available');
                             }
                          }
                        },
                      ),
                    ),
                    if (selectionState.selectedSeatIds.isNotEmpty)
                      _SelectedSeatsPanel(
                        showId: widget.showId,
                        show: show,
                        selectedSeatIds: selectionState.selectedSeatIds,
                        layout: layout,
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _TimerChip extends StatelessWidget {
  final int secondsLeft;
  const _TimerChip({required this.secondsLeft});

  Color get _color {
    if (secondsLeft < 120) return ShowSnapColors.error;
    if (secondsLeft < 240) return Colors.orange;
    return ShowSnapColors.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final mins = secondsLeft ~/ 60;
    final secs = secondsLeft % 60;
    return AnimatedContainer(
      duration: ShowSnapDuration.fast,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '$mins:${secs.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedSeatsPanel extends ConsumerWidget {
  final String showId;
  final ShowModel show;
  final Set<String> selectedSeatIds;
  final List<SeatModel> layout;

  const _SelectedSeatsPanel({
    required this.showId,
    required this.show,
    required this.selectedSeatIds,
    required this.layout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Calculate totals using layout seat info
    int subtotal = 0;
    final seatInfos = <Map<String, dynamic>>[];
    for (final id in selectedSeatIds) {
      SeatModel? seat;
      for (final s in layout) {
        if (s.seatId == id) {
          seat = s;
          break;
        }
      }
      if (seat != null) {
        final price = show.priceForCategory(seat.category.name);
        subtotal += price;
        seatInfos.add({
          'id': id,
          'label': seat.label,
          'category': seat.category.name,
          'price': price,
        });
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: ShowSnapColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: seatInfos.map((info) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: ShowSnapColors.primaryLighter,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(info['label'] as String,
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          Text(
                            (info['category'] as String).toUpperCase(),
                            style: const TextStyle(
                                fontSize: 9,
                                color: Colors.black87),
                          ),
                          Text('₹${info['price']}',
                              style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${selectedSeatIds.length} seat(s)',
                          style: const TextStyle(
                              color: ShowSnapColors.grey600,
                              fontSize: 12)),
                      Text(
                        'Subtotal: ₹$subtotal',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () => context.push(
                      AppRoutes.orderSummary,
                      extra: {
                        'showId': showId,
                        'seatIds': selectedSeatIds.toList(),
                      },
                    ),
                    child: const Text('Proceed'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Ticket Quantity Bottom Sheet ─────────────────────────────────────────────

class _TicketQuantityBottomSheet extends ConsumerWidget {
  final String showId;
  const _TicketQuantityBottomSheet({required this.showId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: ShowSnapColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'How many tickets?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [1, 2, 3, 0].map((count) {
                  final state = ref.watch(seatSelectionProvider(showId));
                  final isSelected = state.requestedTickets == count;
                  final label = count == 0 ? '+4' : '$count';
                  
                  return InkWell(
                    onTap: () {
                      ref.read(seatSelectionProvider(showId).notifier).setRequestedTickets(count);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(ShowSnapRadius.pill),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? ShowSnapColors.primary : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? ShowSnapColors.primary : ShowSnapColors.grey600,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.black87 : Colors.white,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Select a number, then tap a seat to auto-select.',
                style: TextStyle(color: ShowSnapColors.grey600, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
