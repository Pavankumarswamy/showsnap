import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/show_model.dart';
import '../../../core/models/seat_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';

// ─── Show Stream Provider ─────────────────────────────────────────────────────

final showStreamProvider =
    StreamProvider.family<ShowModel, String>((ref, showId) {
  return ref.watch(databaseServiceProvider).streamShow(showId);
});

// ─── Seat Selection State ─────────────────────────────────────────────────────

class SeatSelectionState {
  final Set<String> selectedSeatIds;
  final Map<String, bool> lockInProgress; // seatId → loading
  final String? error;
  final bool timerExpired;

  const SeatSelectionState({
    this.selectedSeatIds = const {},
    this.lockInProgress = const {},
    this.error,
    this.timerExpired = false,
  });

  SeatSelectionState copyWith({
    Set<String>? selectedSeatIds,
    Map<String, bool>? lockInProgress,
    String? error,
    bool? timerExpired,
    bool clearError = false,
  }) =>
      SeatSelectionState(
        selectedSeatIds: selectedSeatIds ?? this.selectedSeatIds,
        lockInProgress: lockInProgress ?? this.lockInProgress,
        error: clearError ? null : error ?? this.error,
        timerExpired: timerExpired ?? this.timerExpired,
      );
}

class SeatSelectionNotifier extends StateNotifier<SeatSelectionState> {
  final DatabaseService _db;
  final String _showId;
  final String _uid;

  SeatSelectionNotifier(this._db, this._showId, this._uid)
      : super(const SeatSelectionState());

  Future<void> toggleSeat(SeatModel seat, ShowModel show) async {
    final seatId = seat.seatId;
    final isSelected = state.selectedSeatIds.contains(seatId);

    if (isSelected) {
      // Unlock
      final newSelected = Set<String>.from(state.selectedSeatIds)
        ..remove(seatId);
      state = state.copyWith(
        selectedSeatIds: newSelected,
        clearError: true,
      );
      await _db.unlockSeat(_showId, seatId, _uid);
      return;
    }

    // Check max seats
    if (state.selectedSeatIds.length >= 6) {
      state = state.copyWith(error: 'Maximum 6 seats per booking');
      return;
    }

    // Check current status
    final seatStatus = show.seats[seatId];
    if (seatStatus != null) {
      if (seatStatus.status.name == 'booked') {
        state = state.copyWith(error: 'This seat is already booked');
        return;
      }
      if (seatStatus.status.name == 'locked' &&
          seatStatus.lockedBy != _uid &&
          !seatStatus.isExpiredLock) {
        state = state.copyWith(error: 'This seat was just taken');
        return;
      }
    }

    // Show lock in progress
    final newProgress = Map<String, bool>.from(state.lockInProgress)
      ..[seatId] = true;
    state = state.copyWith(lockInProgress: newProgress, clearError: true);

    final success = await _db.lockSeat(_showId, seatId, _uid);

    final clearedProgress = Map<String, bool>.from(state.lockInProgress)
      ..remove(seatId);

    if (success) {
      final newSelected = Set<String>.from(state.selectedSeatIds)..add(seatId);
      state = state.copyWith(
        selectedSeatIds: newSelected,
        lockInProgress: clearedProgress,
      );
    } else {
      state = state.copyWith(
        lockInProgress: clearedProgress,
        error: 'Seat just taken — please choose another',
      );
    }
  }

  Future<void> releaseAllLocks() async {
    final seats = Set<String>.from(state.selectedSeatIds);
    state = const SeatSelectionState();
    if (seats.isNotEmpty) {
      await _db.unlockSeats(_showId, seats.toList(), _uid);
    }
  }

  void setTimerExpired() {
    state = state.copyWith(timerExpired: true);
    releaseAllLocks();
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final seatSelectionProvider = StateNotifierProvider.autoDispose
    .family<SeatSelectionNotifier, SeatSelectionState, String>(
        (ref, showId) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
  final db = ref.watch(databaseServiceProvider);
  return SeatSelectionNotifier(db, showId, uid);
});

// ─── Shows for Movie ──────────────────────────────────────────────────────────

final showsForMovieProvider = FutureProvider.family<
    Map<String, List<ShowModel>>,
    String>((ref, movieId) async {
  // Returns a map of theaterId → shows sorted by startTs
  final db = ref.watch(databaseServiceProvider);
  final theaters = await db.getAllTheaters();
  final result = <String, List<ShowModel>>{};
  await Future.wait(theaters.map((t) async {
    final shows = await db.getShowsForMovie(movieId, t.theaterId);
    if (shows.isNotEmpty) {
      shows.sort((a, b) => a.startTs.compareTo(b.startTs));
      result[t.theaterId] = shows;
    }
  }));
  return result;
});
