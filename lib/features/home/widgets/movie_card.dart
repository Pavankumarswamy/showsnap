import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/movie_model.dart';
import '../../../core/widgets/tappable_scale.dart';

class MovieCard extends StatelessWidget {
  final MovieModel movie;
  final double width;
  final String? heroTagSuffix;

  const MovieCard({
    super.key,
    required this.movie,
    this.width = 150,
    this.heroTagSuffix,
  });

  @override
  Widget build(BuildContext context) {
    final heroTag = 'movie_poster_${movie.movieId}${heroTagSuffix != null ? '_$heroTagSuffix' : ''}';
    return TappableScale(
      onTap: () => context.push('/movie/${movie.movieId}', extra: heroTag),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: heroTag,
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(ShowSnapRadius.sm),
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: CachedNetworkImage(
                    imageUrl: movie.posterUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Shimmer.fromColors(
                      baseColor: ShowSnapColors.grey300,
                      highlightColor: ShowSnapColors.grey100,
                      child: Container(
                        color: ShowSnapColors.grey300,
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: ShowSnapColors.grey300,
                      child: const Icon(Icons.movie_outlined,
                          size: 40, color: ShowSnapColors.grey600),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              movie.title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: ShowSnapColors.grey300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    movie.certificate,
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    movie.genres.take(2).join(' • '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ShowSnapColors.grey600,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (movie.rating > 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star,
                      size: 14, color: ShowSnapColors.primary),
                  const SizedBox(width: 2),
                  Text(
                    movie.rating.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
