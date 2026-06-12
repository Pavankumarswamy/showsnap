import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/booking_provider.dart';
import '../widgets/seat_map_widget.dart';
import '../../../core/config/router.dart';
import '../../../core/config/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/screen_model.dart';
import '../../../core/models/show_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';
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
          flexibleSpace: Container(
            decoration:
                BoxDecoration(gradient: ShowSnapTheme.appBarGradient),
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
                        onSeatTap: (seat) => ref
                            .read(seatSelectionProvider(widget.showId).notifier)
                            .toggleSeat(seat, show),
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
    return Colors.green.shade600;
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
  final List<dynamic> layout;

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
      final seat = layout.firstWhere(
          (s) => s.seatId == id,
          orElse: () => null);
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
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          Text(
                            (info['category'] as String).toUpperCase(),
                            style: const TextStyle(
                                fontSize: 9,
                                color: ShowSnapColors.grey600),
                          ),
                          Text('₹${info['price']}',
                              style: const TextStyle(fontSize: 11)),
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
