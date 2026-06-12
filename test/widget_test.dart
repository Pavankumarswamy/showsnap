import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:showsnap/core/models/seat_model.dart';
import 'package:showsnap/core/models/seat_status_model.dart';
import 'package:showsnap/core/models/show_model.dart';
import 'package:showsnap/features/movies/widgets/seat_map_widget.dart';

void main() {
  group('SeatMapWidget', () {
    final seats = [
      const SeatModel(
          seatId: 'A1',
          row: 'A',
          number: 1,
          category: SeatCategory.silver,
          x: 0,
          y: 0),
      const SeatModel(
          seatId: 'A2',
          row: 'A',
          number: 2,
          category: SeatCategory.gold,
          x: 1,
          y: 0),
      const SeatModel(
          seatId: 'B1',
          row: 'B',
          number: 1,
          category: SeatCategory.platinum,
          x: 0,
          y: 1,
          isAccessible: true),
    ];

    final show = ShowModel(
      showId: 'show1',
      movieId: 'movie1',
      theaterId: 'theater1',
      screenId: 'screen1',
      startTs: 0,
      endTs: 0,
      seats: {
        'A1': const SeatStatusModel(status: SeatStatus.available),
        'A2': const SeatStatusModel(status: SeatStatus.booked),
        'B1': SeatStatusModel(
            status: SeatStatus.locked,
            lockedBy: 'other-user',
            lockedAt: DateTime.now().millisecondsSinceEpoch),
      },
    );

    testWidgets('renders without error and shows SCREEN label',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SeatMapWidget(
                seatLayout: seats,
                show: show,
                selectedSeatIds: const {},
                lockingInProgress: const {},
                currentUid: 'test-uid',
                onSeatTap: (_) {},
              ),
            ),
          ),
        ),
      );

      // Let animations start
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SeatMapWidget), findsOneWidget);
      expect(find.text('S C R E E N'), findsOneWidget);
    });

    testWidgets('renders legend items', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SeatMapWidget(
                seatLayout: seats,
                show: show,
                selectedSeatIds: const {},
                lockingInProgress: const {},
                currentUid: 'test-uid',
                onSeatTap: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Selected'), findsOneWidget);
      expect(find.text('Booked'), findsOneWidget);
    });
  });
}
