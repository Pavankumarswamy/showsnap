class MovieModel {
  final String movieId;
  final String title;
  final String language;
  final List<String> genres;
  final int durationMinutes;
  final int releaseDateTs; // epoch ms (Start Date)
  final int endDateTs; // epoch ms (End Date)
  final String certificate; // 'U' | 'UA' | 'A' | 'S'
  final String synopsis;
  final List<String> cast;
  final String director;
  final String posterUrl;
  final String trailerUrl;
  final String status; // 'upcoming' | 'nowShowing' | 'closed'
  final String addedByTm; // UID of TM who added the movie
  final double rating;
  final int bookingCount;

  const MovieModel({
    required this.movieId,
    required this.title,
    this.language = 'Hindi',
    this.genres = const [],
    this.durationMinutes = 120,
    this.releaseDateTs = 0,
    this.endDateTs = 0,
    this.certificate = 'UA',
    this.synopsis = '',
    this.cast = const [],
    this.director = '',
    this.posterUrl = '',
    this.trailerUrl = '',
    this.status = 'nowShowing',
    this.addedByTm = '',
    this.rating = 0,
    this.bookingCount = 0,
  });

  factory MovieModel.fromJson(String movieId, Map<dynamic, dynamic> json) {
    List<String> _list(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      if (v is Map) return v.values.map((e) => e.toString()).toList();
      return [];
    }

    return MovieModel(
      movieId: movieId,
      title: json['title']?.toString() ?? '',
      language: json['language']?.toString() ?? 'Hindi',
      genres: _list(json['genres']),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 120,
      releaseDateTs: (json['releaseDateTs'] as num?)?.toInt() ?? 0,
      endDateTs: (json['endDateTs'] as num?)?.toInt() ?? 0,
      certificate: json['certificate']?.toString() ?? 'UA',
      synopsis: json['synopsis']?.toString() ?? '',
      cast: _list(json['cast']),
      director: json['director']?.toString() ?? '',
      posterUrl: json['posterUrl']?.toString() ?? '',
      trailerUrl: json['trailerUrl']?.toString() ?? '',
      status: json['status']?.toString() ?? 'nowShowing',
      addedByTm: json['addedByTm']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      bookingCount: (json['bookingCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'language': language,
        'genres': genres,
        'durationMinutes': durationMinutes,
        'releaseDateTs': releaseDateTs,
        'endDateTs': endDateTs,
        'certificate': certificate,
        'synopsis': synopsis,
        'cast': cast,
        'director': director,
        'posterUrl': posterUrl,
        'trailerUrl': trailerUrl,
        'status': status,
        'addedByTm': addedByTm,
        'rating': rating,
        'bookingCount': bookingCount,
      };

  bool get isUpcoming =>
      status == 'upcoming' ||
      (releaseDateTs > 0 &&
          releaseDateTs > DateTime.now().millisecondsSinceEpoch);
}
