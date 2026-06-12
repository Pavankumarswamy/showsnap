import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class _SeatLayoutEditorScreenState
    extends ConsumerState<SeatLayoutEditorScreen> {
  static const int gridRows = 20;
  static const int gridCols = 20;
  late List<List<_GridCell>> _grid;
  ScreenModel? _screen;
  bool _loading = true;
  bool _saving = false;
  bool _previewMode = false;

  // Current tool settings
  String _currentRow = 'A';
  int _currentNum = 1;
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
      gridRows,
      (y) => List.generate(
        gridCols,
        (x) => _GridCell(x: x, y: y),
      ),
    );
  }

  Future<void> _loadScreen() async {
    final screen =
        await ref.read(databaseServiceProvider).getScreen(widget.screenId);
    if (screen == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _screen = screen;
      _loading = false;
    });
    // Populate grid from existing layout
    for (final seat in screen.seatLayout) {
      if (seat.y < gridRows && seat.x < gridCols) {
        setState(() {
          _grid[seat.y][seat.x].seat = seat;
        });
      }
    }
    // Set next available row/num
    if (screen.seatLayout.isNotEmpty) {
      final sorted = List<SeatModel>.from(screen.seatLayout)
        ..sort((a, b) {
          final rowCmp = a.row.compareTo(b.row);
          return rowCmp != 0 ? rowCmp : a.number.compareTo(b.number);
        });
      _currentRow = sorted.last.row;
      _currentNum = sorted.last.number + 1;
    }
  }

  void _onCellTap(int x, int y) {
    if (_previewMode) return;
    setState(() {
      final cell = _grid[y][x];
      if (cell.seat != null) {
        // Remove seat
        cell.seat = null;
      } else {
        // Add seat
        final seatId =
            '${_screen?.screenId ?? 'screen'}_$_currentRow$_currentNum';
        cell.seat = SeatModel(
          seatId: seatId,
          row: _currentRow,
          number: _currentNum,
          category: _currentCategory,
          x: x,
          y: y,
          isAccessible: _isAccessible,
        );
        _currentNum++;
      }
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_previewMode ? 'Preview Layout' : 'Seat Layout Editor'),
        flexibleSpace: Container(
          decoration:
              BoxDecoration(gradient: ShowSnapTheme.appBarGradient),
        ),
        actions: [
          IconButton(
            icon: Icon(_previewMode ? Icons.edit_outlined : Icons.visibility_outlined),
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
            onPressed: _saving ? null : _saveLayout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_previewMode) _buildToolbar(),
                // Screen indicator
                Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 4),
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: ShowSnapTheme.appBarGradient,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: const Center(
                    child: Text('SCREEN',
                        style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 4,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(gridRows, (y) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(gridCols, (x) {
                                final cell = _grid[y][x];
                                return GestureDetector(
                                  onTap: () => _onCellTap(x, y),
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    margin: const EdgeInsets.all(1),
                                    decoration: BoxDecoration(
                                      color: _cellColor(cell),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                      border: Border.all(
                                        color: cell.seat != null
                                            ? ShowSnapColors.grey600
                                            : ShowSnapColors.grey300,
                                      ),
                                    ),
                                    child: cell.seat != null
                                        ? Center(
                                            child: Text(
                                              '${cell.seat!.row}${cell.seat!.number}',
                                              style: const TextStyle(
                                                  fontSize: 6,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          )
                                        : null,
                                  ),
                                );
                              }),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
                _buildStats(),
              ],
            ),
    );
  }

  Color _cellColor(_GridCell cell) {
    if (cell.seat == null) return ShowSnapColors.grey100;
    if (cell.seat!.isAccessible) return SeatColors.accessible;
    switch (cell.seat!.category) {
      case SeatCategory.gold:
        return Colors.amber.shade200;
      case SeatCategory.platinum:
        return Colors.blue.shade200;
      default:
        return ShowSnapColors.grey300;
    }
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: ShowSnapColors.grey100,
      child: Row(
        children: [
          // Row letter
          SizedBox(
            width: 60,
            child: TextFormField(
              initialValue: _currentRow,
              decoration: const InputDecoration(
                  labelText: 'Row', contentPadding: EdgeInsets.all(8)),
              onChanged: (v) => setState(
                  () => _currentRow = v.toUpperCase().isNotEmpty ? v.toUpperCase() : 'A'),
            ),
          ),
          const SizedBox(width: 8),
          // Category
          Expanded(
            child: DropdownButtonFormField<SeatCategory>(
              value: _currentCategory,
              decoration: const InputDecoration(
                  labelText: 'Category', contentPadding: EdgeInsets.all(8)),
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
            children: [
              const Text('♿', style: TextStyle(fontSize: 18)),
              Switch(
                value: _isAccessible,
                activeColor: SeatColors.accessible,
                onChanged: (v) =>
                    setState(() => _isAccessible = v),
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
