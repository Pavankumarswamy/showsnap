import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/seat_model.dart';
import '../../../core/models/seat_status_model.dart';
import '../../../core/models/show_model.dart';

class SeatMapWidget extends StatelessWidget {
  final List<SeatModel> seatLayout;
  final ShowModel show;
  final Set<String> selectedSeatIds;
  final Set<String> lockingInProgress;
  final String currentUid;
  final void Function(SeatModel) onSeatTap;

  const SeatMapWidget({
    super.key,
    required this.seatLayout,
    required this.show,
    required this.selectedSeatIds,
    required this.lockingInProgress,
    required this.currentUid,
    required this.onSeatTap,
  });

  @override
  Widget build(BuildContext context) {
    if (seatLayout.isEmpty) {
      return const Center(child: Text('No seat layout configured'));
    }

    final rows = <String, List<SeatModel>>{};
    for (final seat in seatLayout) {
      rows.putIfAbsent(seat.row, () => []).add(seat);
    }
    final sortedRows = rows.keys.toList()..sort();

    return Column(
      children: [
        // Screen indicator with scale entrance animation
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: ShowSnapTheme.appBarGradient,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: const Center(
            child: Text(
              'S C R E E N',
              style: TextStyle(
                letterSpacing: 6,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.black,
              ),
            ),
          ),
        )
            .animate()
            .scaleX(
              begin: 0.6,
              end: 1.0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
            )
            .fadeIn(duration: ShowSnapDuration.normal),

        const SizedBox(height: 12),

        // Legend with stagger
        _Legend(rowCount: sortedRows.length),

        const SizedBox(height: 12),

        // Seat grid
        Expanded(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 2.5,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AnimationLimiter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: AnimationConfiguration.toStaggeredList(
                        duration: const Duration(milliseconds: 250),
                        childAnimationBuilder: (widget) => SlideAnimation(
                          horizontalOffset: -30,
                          child: FadeInAnimation(child: widget),
                        ),
                        children: sortedRows.map((row) {
                          final seats = rows[row]!
                            ..sort((a, b) => a.number.compareTo(b.number));
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: Text(
                                    row,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: ShowSnapColors.grey600,
                                    ),
                                  ),
                                ),
                                ...seats.map((seat) => _AnimatedSeatCell(
                                      seat: seat,
                                      status: show.seats[seat.seatId],
                                      isSelected: selectedSeatIds
                                          .contains(seat.seatId),
                                      isLocking: lockingInProgress
                                          .contains(seat.seatId),
                                      currentUid: currentUid,
                                      onTap: () => onSeatTap(seat),
                                    )),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Animated seat cell ───────────────────────────────────────────────────────

class _AnimatedSeatCell extends StatefulWidget {
  final SeatModel seat;
  final SeatStatusModel? status;
  final bool isSelected;
  final bool isLocking;
  final String currentUid;
  final VoidCallback onTap;

  const _AnimatedSeatCell({
    required this.seat,
    required this.status,
    required this.isSelected,
    required this.isLocking,
    required this.currentUid,
    required this.onTap,
  });

  @override
  State<_AnimatedSeatCell> createState() => _AnimatedSeatCellState();
}

class _AnimatedSeatCellState extends State<_AnimatedSeatCell>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  bool _prevSelected = false;

  @override
  void initState() {
    super.initState();
    _prevSelected = widget.isSelected;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_AnimatedSeatCell old) {
    super.didUpdateWidget(old);
    if (widget.isSelected != _prevSelected) {
      _prevSelected = widget.isSelected;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _color {
    if (widget.isSelected) return SeatColors.selected;
    if (widget.seat.isAccessible) {
      final st = widget.status?.status ?? SeatStatus.available;
      if (st == SeatStatus.booked) return SeatColors.booked;
      if (st == SeatStatus.locked &&
          widget.status?.lockedBy != widget.currentUid) {
        return SeatColors.booked;
      }
      return SeatColors.accessible;
    }
    final st = widget.status?.status ?? SeatStatus.available;
    if (st == SeatStatus.booked) return SeatColors.booked;
    if (st == SeatStatus.locked) {
      if (widget.status?.lockedBy == widget.currentUid) return SeatColors.selected;
      if (widget.status?.isExpiredLock == true) return SeatColors.available;
      return SeatColors.booked;
    }
    return SeatColors.available;
  }

  bool get _isInteractable {
    if (widget.isLocking) return false;
    if (widget.isSelected) return true;
    final st = widget.status?.status ?? SeatStatus.available;
    if (st == SeatStatus.booked) return false;
    if (st == SeatStatus.locked) {
      if (widget.status?.lockedBy == widget.currentUid) return true;
      if (widget.status?.isExpiredLock == true) return true;
      return false;
    }
    return true;
  }

  BorderSide get _border {
    if (widget.isSelected) {
      return const BorderSide(color: ShowSnapColors.primary, width: 2);
    }
    if (widget.seat.isAccessible) {
      return const BorderSide(color: SeatColors.accessible, width: 1.5);
    }
    return const BorderSide(color: SeatColors.availableBorder);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isInteractable ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: ShowSnapDuration.fast,
          curve: Curves.easeOut,
          width: 30,
          height: 30,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: _color,
            borderRadius: BorderRadius.circular(4),
            border: Border.fromBorderSide(_border),
          ),
          child: widget.isLocking
              ? const Padding(
                  padding: EdgeInsets.all(6),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ShowSnapColors.primary,
                  ),
                )
              : Center(
                  child: Text(
                    '${widget.seat.row}${widget.seat.number}',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: widget.isSelected || _color == SeatColors.booked
                          ? Colors.white
                          : ShowSnapColors.onSurface,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

// ─── Legend ───────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  final int rowCount;
  const _Legend({required this.rowCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimationLimiter(
        child: Wrap(
          spacing: 16,
          children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 200),
            childAnimationBuilder: (w) =>
                FadeInAnimation(child: SlideAnimation(
                  horizontalOffset: 10,
                  child: w,
                )),
            children: [
              _LegendItem(
                  color: SeatColors.available,
                  border: SeatColors.availableBorder,
                  label: 'Available'),
              _LegendItem(color: SeatColors.selected, label: 'Selected'),
              _LegendItem(color: SeatColors.booked, label: 'Booked'),
              _LegendItem(
                  color: SeatColors.accessible, label: 'Accessible'),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final Color? border;
  final String label;
  const _LegendItem(
      {required this.color, this.border, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: border ?? color),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
