import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/show_model.dart';
import '../../../core/models/seat_model.dart';
import '../../../core/models/screen_model.dart';
import '../../../core/models/movie_model.dart';
import '../../../core/models/theater_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';

// ─── Show Stream Provider ─────────────────────────────────────────────────────

final showStreamProvider =
    StreamProvider.family<ShowModel, String>((ref, showId) {
  return ref.watch(databaseServiceProvider).streamShow(showId);
});

final screenProvider = StreamProvider.family<ScreenModel?, String>((ref, screenId) {
  return ref.watch(databaseServiceProvider).streamScreen(screenId);
});

// ─── Seat Selection State ─────────────────────────────────────────────────────

class SeatSelectionState {
  final Set<String> selectedSeatIds;
  final Map<String, bool> lockInProgress; // seatId → loading
  final String? error;
  final bool timerExpired;
  final int requestedTickets;

  const SeatSelectionState({
    this.selectedSeatIds = const {},
    this.lockInProgress = const {},
    this.error,
    this.timerExpired = false,
    this.requestedTickets = 1,
  });

  SeatSelectionState copyWith({
    Set<String>? selectedSeatIds,
    Map<String, bool>? lockInProgress,
    String? error,
    bool? timerExpired,
    int? requestedTickets,
    bool clearError = false,
  }) =>
      SeatSelectionState(
        selectedSeatIds: selectedSeatIds ?? this.selectedSeatIds,
        lockInProgress: lockInProgress ?? this.lockInProgress,
        error: clearError ? null : error ?? this.error,
        timerExpired: timerExpired ?? this.timerExpired,
        requestedTickets: requestedTickets ?? this.requestedTickets,
      );
}

class SeatSelectionNotifier extends StateNotifier<SeatSelectionState> {
  final DatabaseService _db;
  final String _showId;
  final String _uid;

  SeatSelectionNotifier(this._db, this._showId, this._uid)
      : super(const SeatSelectionState());

  void setRequestedTickets(int count) {
    state = state.copyWith(requestedTickets: count);
  }

  Future<void> lockSeats(List<SeatModel> seatsToLock, ShowModel show) async {
    // Check max seats overall
    if (seatsToLock.length > 10) {
      state = state.copyWith(error: 'Maximum 10 seats per booking');
      return;
    }

    // Release all current locks before making new ones
    await releaseAllLocks();

    // Re-verify availability for all requested seats first
    for (final seat in seatsToLock) {
      final seatStatus = show.seats[seat.seatId];
      if (seatStatus != null) {
        if (seatStatus.status.name == 'booked') {
          state = state.copyWith(error: 'Some seats are already booked');
          return;
        }
        if (seatStatus.status.name == 'locked' &&
            seatStatus.lockedBy != _uid &&
            !seatStatus.isExpiredLock) {
          state = state.copyWith(error: 'Some seats were just taken');
          return;
        }
      }
    }

    // Show lock in progress for all
    final newProgress = Map<String, bool>.from(state.lockInProgress);
    for (final seat in seatsToLock) {
      newProgress[seat.seatId] = true;
    }
    state = state.copyWith(lockInProgress: newProgress, clearError: true);

    // Try to lock all seats in parallel
    final results = await Future.wait(
      seatsToLock.map((s) => _db.lockSeat(_showId, s.seatId, _uid))
    );

    final clearedProgress = Map<String, bool>.from(state.lockInProgress);
    for (final seat in seatsToLock) {
      clearedProgress.remove(seat.seatId);
    }

    final allSuccess = !results.contains(false);

    if (allSuccess) {
      final newSelected = Set<String>.from(seatsToLock.map((s) => s.seatId));
      state = state.copyWith(
        selectedSeatIds: newSelected,
        lockInProgress: clearedProgress,
      );
    } else {
      // If any failed, release the ones that succeeded
      final successfulSeats = <String>[];
      for (int i = 0; i < seatsToLock.length; i++) {
        if (results[i]) {
          successfulSeats.add(seatsToLock[i].seatId);
        }
      }
      if (successfulSeats.isNotEmpty) {
        await _db.unlockSeats(_showId, successfulSeats, _uid);
      }

      state = state.copyWith(
        lockInProgress: clearedProgress,
        error: 'One or more seats just taken — please choose another set',
      );
    }
  }

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
    state = state.copyWith(
      selectedSeatIds: const {},
      lockInProgress: const {},
      clearError: true,
    );
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

final movieProvider = FutureProvider.family<MovieModel?, String>((ref, movieId) {
  return ref.watch(databaseServiceProvider).getMovie(movieId);
});

final theaterProvider = FutureProvider.family<TheaterModel?, String>((ref, theaterId) {
  return ref.watch(databaseServiceProvider).getTheater(theaterId);
});

final theaterShowsStreamProvider = StreamProvider.family<List<ShowModel>, String>((ref, theaterId) {
  return ref.watch(databaseServiceProvider).streamShowsForTheater(theaterId);
});
