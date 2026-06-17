import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/seat_model.dart';
import '../../../core/models/seat_status_model.dart';
import '../../../core/models/show_model.dart';

class SeatMapWidget extends StatefulWidget {
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
  State<SeatMapWidget> createState() => _SeatMapWidgetState();
}

class _SeatMapWidgetState extends State<SeatMapWidget> {
  late TransformationController _transformationController;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      int maxCol = 0;
      for (final seat in widget.seatLayout) {
        if (seat.x > maxCol) maxCol = seat.x;
      }
      final layoutWidth = (maxCol + 1) * 34.0 + 64.0 + 24.0;
      if (layoutWidth > size.width) {
        final scale = size.width / layoutWidth;
        _transformationController.value = Matrix4.identity()..scale(scale);
      }
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.seatLayout.isEmpty) {
      return const Center(child: Text('No seat layout configured'));
    }

    final rows = <String, List<SeatModel>>{};
    for (final seat in widget.seatLayout) {
      rows.putIfAbsent(seat.row, () => []).add(seat);
    }
    final sortedRows = rows.keys.toList()..sort();

    int maxCol = 0;
    for (final seat in widget.seatLayout) {
      if (seat.x > maxCol) maxCol = seat.x;
    }

    return Column(
      children: [


        // Seat grid
        Expanded(
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.1,
            maxScale: 2.5,
            constrained: false, // Allows child to be larger than screen (perfect for desktop)
            boundaryMargin: const EdgeInsets.all(200.0), // Allow panning and zooming out freely
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Curved movie screen indicator (attached to seats)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 24), // Offset for row header
                        SizedBox(
                          width: (maxCol + 1) * 34.0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: (maxCol + 1) * 34.0,
                                height: 20,
                                child: CustomPaint(
                                  painter: _CurvedScreenPainter(
                                    color: ShowSnapColors.grey300,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Center(
                                child: Text(
                                  'SCREEN',
                                  style: TextStyle(
                                    letterSpacing: 8,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    color: ShowSnapColors.grey600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

                  ...sortedRows.map((row) {
                    final seatsInRow = rows[row]!;
                    final seatMap = {for (final s in seatsInRow) s.x: s};
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min, // Hug content
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
                          ...List.generate(maxCol + 1, (x) {
                            final seat = seatMap[x];
                            if (seat == null) {
                              return const SizedBox(width: 34, height: 34);
                            }
                            return _AnimatedSeatCell(
                              seat: seat,
                              status: widget.show.seats[seat.seatId],
                              isSelected: widget.selectedSeatIds.contains(seat.seatId),
                              isLocking: widget.lockingInProgress.contains(seat.seatId),
                              currentUid: widget.currentUid,
                              onTap: () => widget.onSeatTap(seat),
                            );
                          }),
                        ],
                      ),
                    );
                  }).toList(),
                ],
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

  Color get _availableColor {
    switch (widget.seat.category) {
      case SeatCategory.silver:
        return SeatColors.silver;
      case SeatCategory.gold:
        return SeatColors.gold;
      case SeatCategory.platinum:
        return SeatColors.platinum;
    }
  }

  Color get _color {
    if (widget.isSelected) return SeatColors.selected;
    final st = widget.status?.status ?? SeatStatus.available;
    if (st == SeatStatus.booked) return SeatColors.booked;
    if (st == SeatStatus.locked) {
      if (widget.status?.lockedBy == widget.currentUid) return SeatColors.selected;
      if (widget.status?.isExpiredLock == true) return _availableColor;
      return SeatColors.booked;
    }
    return _availableColor;
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
                    '${widget.seat.number}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _color == SeatColors.booked
                          ? Colors.white
                          : Colors.black,
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
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _LegendItem(
              color: SeatColors.silver,
              border: SeatColors.availableBorder,
              label: 'Silver'),
          _LegendItem(color: SeatColors.gold, label: 'Gold'),
          _LegendItem(color: SeatColors.platinum, label: 'Platinum'),
          _LegendItem(color: SeatColors.selected, label: 'Selected'),
          _LegendItem(color: SeatColors.booked, label: 'Booked'),
        ],
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

class _CurvedScreenPainter extends CustomPainter {
  final Color color;
  _CurvedScreenPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw curved projection glow
    final glowPaint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final glowPath = Path()
      ..moveTo(0, size.height - 2)
      ..quadraticBezierTo(size.width / 2, 2, size.width, size.height - 2);

    canvas.drawPath(glowPath, glowPaint);

    // 2. Draw curved screen line
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height - 2)
      ..quadraticBezierTo(size.width / 2, 4, size.width, size.height - 2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CurvedScreenPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
