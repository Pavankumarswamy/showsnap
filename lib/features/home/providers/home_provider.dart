import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/banner_model.dart';
import '../../../core/models/event_model.dart';
import '../../../core/models/movie_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';

final bannersProvider = FutureProvider<List<BannerModel>>((ref) =>
    ref.watch(databaseServiceProvider).getBanners());

class HomeData {
  final List<MovieModel> recommended;
  final List<MovieModel> nowShowing;
  final List<MovieModel> upcoming;
  final List<EventModel> events;
  final List<MovieModel> trending;

  const HomeData({
    this.recommended = const [],
    this.nowShowing = const [],
    this.upcoming = const [],
    this.events = const [],
    this.trending = const [],
  });
}

final homeFeedProvider = FutureProvider<HomeData>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  final userAsync = ref.watch(currentUserModelProvider);
  final user = userAsync.valueOrNull;

  final allMovies = await db.getAllMovies();
  final allEvents = await db.getAllEvents();

  final now = DateTime.now().millisecondsSinceEpoch;
  final nowShowing =
      allMovies.where((m) => m.status == 'nowShowing').toList();
  final upcoming = allMovies
      .where((m) =>
          m.status != 'nowShowing' &&
          (m.status == 'upcoming' ||
              (m.releaseDateTs > 0 && m.releaseDateTs > now)))
      .toList();

  // Trending: sort by bookingCount descending, take top 10
  final trending = List<MovieModel>.from(nowShowing)
    ..sort((a, b) => b.bookingCount.compareTo(a.bookingCount));
  final trendingTop =
      trending.take(AppConstants.homeSectionLimit).toList();

  // Personalised: score each movie by affinity + recency + trending rank
  List<MovieModel> recommended;
  if (user != null && user.affinityScores.isNotEmpty) {
    final scores = <String, double>{};
    for (final movie in nowShowing) {
      double genreScore = 0;
      for (final g in movie.genres) {
        genreScore += user.affinityScores[g] ?? 0;
      }
      genreScore = movie.genres.isEmpty ? 0 : genreScore / movie.genres.length;

      final trendingIdx = trendingTop.indexWhere((m) => m.movieId == movie.movieId);
      final trendingScore = trendingIdx >= 0
          ? 1.0 - (trendingIdx / AppConstants.homeSectionLimit)
          : 0.0;

      // Recency: movies released in last 30 days get boost
      final ageMs = now - movie.releaseDateTs;
      final recencyScore =
          ageMs < 30 * 24 * 3600 * 1000 ? 1.0 : 0.3;

      scores[movie.movieId] = genreScore * AppConstants.genreAffinityWeight +
          recencyScore * AppConstants.recencyBoostWeight +
          trendingScore * AppConstants.trendingScoreWeight;
    }
    recommended = List<MovieModel>.from(nowShowing)
      ..sort((a, b) => (scores[b.movieId] ?? 0)
          .compareTo(scores[a.movieId] ?? 0));
    recommended = recommended.take(AppConstants.homeSectionLimit).toList();
  } else if (user?.preferredGenres.isNotEmpty == true) {
    // Cold start: filter by signup preferences
    recommended = nowShowing
        .where((m) =>
            m.genres.any((g) => user!.preferredGenres.contains(g)))
        .take(AppConstants.homeSectionLimit)
        .toList();
    if (recommended.isEmpty) recommended = nowShowing.take(AppConstants.homeSectionLimit).toList();
  } else {
    recommended = trendingTop;
  }

  return HomeData(
    recommended: recommended,
    nowShowing: nowShowing,
    upcoming: upcoming,
    events: allEvents,
    trending: trendingTop,
  );
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<MovieModel>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  if (query.isEmpty) return [];
  final db = ref.watch(databaseServiceProvider);
  final all = await db.getAllMovies();
  return all
      .where((m) =>
          m.title.toLowerCase().contains(query) ||
          m.genres.any((g) => g.toLowerCase().contains(query)) ||
          m.language.toLowerCase().contains(query) ||
          m.director.toLowerCase().contains(query))
      .toList();
});
