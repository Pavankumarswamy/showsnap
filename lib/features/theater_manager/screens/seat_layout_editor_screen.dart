import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/screen_model.dart';
import '../../../core/models/seat_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/extensions.dart';

class _GridCell {
  final int x;
  final int y;
  SeatModel? seat;
  bool selected = false;

  _GridCell({required this.x, required this.y});
}

class SeatLayoutEditorScreen extends ConsumerStatefulWidget {
  final String screenId;
  const SeatLayoutEditorScreen({super.key, required this.screenId});

  @override
  ConsumerState<SeatLayoutEditorScreen> createState() =>
      _SeatLayoutEditorScreenState();
}

class _SeatLayoutEditorScreenState extends ConsumerState<SeatLayoutEditorScreen> {
  int _gridRows = 15;
  int _gridCols = 15;
  late List<List<_GridCell>> _grid;
  ScreenModel? _screen;
  bool _loading = true;
  bool _saving = false;
  bool _previewMode = false;

  // Tool settings
  SeatCategory _currentCategory = SeatCategory.silver;
  bool _isAccessible = false;

  @override
  void initState() {
    super.initState();
    _initGrid();
    _loadScreen();
  }

  void _initGrid() {
    _grid = List.generate(
      _gridRows,
      (y) => List.generate(_gridCols, (x) => _GridCell(x: x, y: y)),
    );
  }

  Future<void> _loadScreen() async {
    final screen =
        await ref.read(databaseServiceProvider).getScreen(widget.screenId);
    if (screen == null) {
      setState(() => _loading = false);
      return;
    }
    
    // Determine bounds
    int maxR = 0, maxC = 0;
    for (final seat in screen.seatLayout) {
      if (seat.y > maxR) maxR = seat.y;
      if (seat.x > maxC) maxC = seat.x;
    }
    
    // Resize grid if needed based on loaded seats
    if (screen.seatLayout.isNotEmpty) {
      _gridRows = maxR + 2;
      _gridCols = maxC + 2;
      _initGrid();
    }

    setState(() {
      _screen = screen;
      _loading = false;
    });

    for (final seat in screen.seatLayout) {
      if (seat.y < _gridRows && seat.x < _gridCols) {
        setState(() {
          _grid[seat.y][seat.x].seat = seat;
        });
      }
    }
  }

  String _getRowLabel(int y) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (y < letters.length) return letters[y];
    return '${letters[y ~/ letters.length - 1]}${letters[y % letters.length]}';
  }

  void _generateGrid(int rows, int cols) {
    setState(() {
      _gridRows = rows;
      _gridCols = cols;
      _initGrid();
      
      for (int y = 0; y < rows; y++) {
        final rowStr = _getRowLabel(y);
        for (int x = 0; x < cols; x++) {
          final seatId = '${widget.screenId}_${rowStr}_${x + 1}';
          _grid[y][x].seat = SeatModel(
            seatId: seatId,
            row: rowStr,
            number: x + 1,
            category: _currentCategory,
            x: x,
            y: y,
            isAccessible: _isAccessible,
          );
        }
      }
    });
  }

  Future<void> _showGenerateDialog() async {
    final rCtrl = TextEditingController(text: '$_gridRows');
    final cCtrl = TextEditingController(text: '$_gridCols');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Grid'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'This will completely overwrite the current layout with a solid block of seats. You can then tap seats to create aisles.',
                style: TextStyle(fontSize: 13, color: ShowSnapColors.grey600)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: rCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Rows'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: cCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Columns'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ShowSnapColors.error),
            child: const Text('Overwrite & Generate'),
          ),
        ],
      ),
    );

    if (result == true) {
      final r = int.tryParse(rCtrl.text) ?? 10;
      final c = int.tryParse(cCtrl.text) ?? 15;
      _generateGrid(r, c);
    }
  }

  void _onCellTap(int x, int y) {
    if (_previewMode) return;
    setState(() {
      final cell = _grid[y][x];
      if (cell.seat != null) {
        // Toggle off (create gap/aisle)
        cell.seat = null;
      } else {
        // Toggle on (revive seat)
        final rowStr = _getRowLabel(y);
        int num = 1;
        // Recalculate number based on previous seats in row
        for (int i = 0; i < x; i++) {
          if (_grid[y][i].seat != null) num++;
        }
        
        final seatId = '${widget.screenId}_${rowStr}_$num';
        cell.seat = SeatModel(
          seatId: seatId,
          row: rowStr,
          number: num,
          category: _currentCategory,
          x: x,
          y: y,
          isAccessible: _isAccessible,
        );
      }
      _renumberRow(y);
    });
  }

  void _renumberRow(int y) {
    int num = 1;
    final rowStr = _getRowLabel(y);
    for (int x = 0; x < _gridCols; x++) {
      final cell = _grid[y][x];
      if (cell.seat != null) {
        cell.seat = cell.seat!.copyWith(
          number: num,
          seatId: '${widget.screenId}_${rowStr}_$num',
        );
        num++;
      }
    }
  }

  void _onRowHeaderTap(int y) {
    if (_previewMode) return;
    setState(() {
      for (int x = 0; x < _gridCols; x++) {
        final seat = _grid[y][x].seat;
        if (seat != null) {
          _grid[y][x].seat = seat.copyWith(
            category: _currentCategory,
            isAccessible: _isAccessible,
          );
        }
      }
    });
    context.showSnackbar('Applied category to row ${_getRowLabel(y)}');
  }

  Future<void> _saveLayout() async {
    if (_screen == null) return;
    setState(() => _saving = true);

    final seats = <SeatModel>[];
    for (final row in _grid) {
      for (final cell in row) {
        if (cell.seat != null) seats.add(cell.seat!);
      }
    }

    final layoutMap = <String, dynamic>{};
    for (final s in seats) {
      layoutMap[s.seatId] = s.toJson();
    }

    await ref.read(databaseServiceProvider).updateScreen(
        widget.screenId,
        {'seatLayout': layoutMap, 'totalSeats': seats.length});

    setState(() => _saving = false);
    if (mounted) context.showSnackbar('Layout saved — ${seats.length} seats');
  }

  final TransformationController _transformCtrl = TransformationController();

  void _zoom(double factor) {
    final matrix = _transformCtrl.value.clone();
    // Zoom around the center of the viewport
    // A simple scale works too if we just scale the matrix
    matrix.scale(factor);
    _transformCtrl.value = matrix;
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_previewMode ? 'Preview Layout' : 'Seat Layout Editor'),
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
        actions: [
          IconButton(
            icon: Icon(_previewMode ? Icons.edit_outlined : Icons.visibility_outlined),
            tooltip: 'Toggle Preview',
            onPressed: () =>
                setState(() => _previewMode = !_previewMode),
          ),
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            tooltip: 'Save Layout',
            onPressed: _saving ? null : _saveLayout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_previewMode) _buildToolbar().animate().fadeIn(duration: 300.ms),
                Expanded(
                  child: Stack(
                    children: [
                      InteractiveViewer(
                        transformationController: _transformCtrl,
                        minScale: 0.1,
                        maxScale: 3.0,
                        constrained: false, // Fixes RenderFlex overflow!
                        boundaryMargin: const EdgeInsets.all(200.0), // Allow panning and zooming out freely
                        child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Curved movie screen indicator (attached to seats)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 32),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(width: _previewMode ? 0 : 42.0), // Row header offset
                                SizedBox(
                                  width: _gridCols * 32.0,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: double.infinity,
                                        height: 20,
                                        child: CustomPaint(
                                          painter: _CurvedScreenPainter(
                                            color: ShowSnapColors.primary,
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
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.elasticOut,
                              )
                              .fadeIn(),
                          ...List.generate(_gridRows, (y) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Row Header
                              if (!_previewMode)
                                GestureDetector(
                                  onTap: () => _onRowHeaderTap(y),
                                  child: Container(
                                    width: 30,
                                    height: 28,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: ShowSnapColors.grey300,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _getRowLabel(y),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ),
                              // Seats
                              ...List.generate(_gridCols, (x) {
                                final cell = _grid[y][x];
                                return GestureDetector(
                                  onTap: () => _onCellTap(x, y),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    margin: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: _cellColor(cell),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: cell.seat != null
                                            ? ShowSnapColors.grey600
                                            : (_previewMode ? Colors.transparent : ShowSnapColors.grey300),
                                      ),
                                    ),
                                    child: cell.seat != null
                                        ? Center(
                                            child: Text(
                                              '${cell.seat!.number}',
                                              style: const TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700),
                                            ),
                                          )
                                        : null,
                                  ),
                                );
                              }),
                            ],
                          );
                        }),
                      ],
                    ),
                      ),
                    ),
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Column(
                          children: [
                            FloatingActionButton.small(
                              heroTag: 'zoomIn',
                              backgroundColor: ShowSnapColors.surface,
                              foregroundColor: ShowSnapColors.primary,
                              child: const Icon(Icons.add),
                              onPressed: () => _zoom(1.2),
                            ),
                            const SizedBox(height: 8),
                            FloatingActionButton.small(
                              heroTag: 'zoomOut',
                              backgroundColor: ShowSnapColors.surface,
                              foregroundColor: ShowSnapColors.primary,
                              child: const Icon(Icons.remove),
                              onPressed: () => _zoom(0.8),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStats(),
              ],
            ),
    );
  }

  Color _cellColor(_GridCell cell) {
    if (cell.seat == null) return _previewMode ? Colors.transparent : ShowSnapColors.grey100;
    if (cell.seat!.isAccessible) return SeatColors.accessible;
    switch (cell.seat!.category) {
      case SeatCategory.gold:
        return SeatColors.gold;
      case SeatCategory.platinum:
        return SeatColors.platinum;
      case SeatCategory.silver:
        return SeatColors.silver;
    }
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: ShowSnapColors.grey100,
      child: Row(
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ShowSnapColors.primary,
              foregroundColor: Colors.black,
            ),
            onPressed: _showGenerateDialog,
            icon: const Icon(Icons.grid_on),
            label: const Text('Generate Grid'),
          ),
          const SizedBox(width: 16),
          // Category Tool
          Expanded(
            child: DropdownButtonFormField<SeatCategory>(
              value: _currentCategory,
              decoration: const InputDecoration(
                  labelText: 'Paint Category', 
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true),
              items: SeatCategory.values
                  .map((c) => DropdownMenuItem(
                      value: c, child: Text(c.label)))
                  .toList(),
              onChanged: (v) => setState(() => _currentCategory = v!),
            ),
          ),
          const SizedBox(width: 8),
          // Accessible toggle
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('♿', style: TextStyle(fontSize: 16)),
              SizedBox(
                height: 24,
                child: Switch(
                  value: _isAccessible,
                  activeColor: SeatColors.accessible,
                  onChanged: (v) =>
                      setState(() => _isAccessible = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    int totalSeats = 0;
    int silver = 0, gold = 0, platinum = 0;
    for (final row in _grid) {
      for (final cell in row) {
        if (cell.seat != null) {
          totalSeats++;
          switch (cell.seat!.category) {
            case SeatCategory.silver:
              silver++;
              break;
            case SeatCategory.gold:
              gold++;
              break;
            case SeatCategory.platinum:
              platinum++;
              break;
          }
        }
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: ShowSnapColors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text('Total: $totalSeats', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('Silver: $silver', style: const TextStyle(color: ShowSnapColors.grey600)),
          Text('Gold: $gold', style: TextStyle(color: Colors.amber.shade700)),
          Text('Platinum: $platinum', style: TextStyle(color: Colors.blue.shade700)),
        ],
      ),
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
      ..moveTo(0, 2)
      ..quadraticBezierTo(size.width / 2, size.height, size.width, 2);

    canvas.drawPath(glowPath, glowPaint);

    // 2. Draw curved screen line
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, 2)
      ..quadraticBezierTo(size.width / 2, size.height - 2, size.width, 2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CurvedScreenPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
