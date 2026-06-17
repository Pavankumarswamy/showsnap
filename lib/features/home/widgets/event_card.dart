import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/event_model.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/tappable_scale.dart';

class EventCard extends StatelessWidget {
  final EventModel event;

  const EventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return TappableScale(
      onTap: () => context.push('/event/${event.eventId}'),
      child: SizedBox(
        width: 200,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ShowSnapRadius.md),
            boxShadow: ShowSnapShadow.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Expanded(
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(ShowSnapRadius.md)),
                        child: event.posterUrl.isNotEmpty ? CachedNetworkImage(
                          imageUrl: event.posterUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Shimmer.fromColors(
                            baseColor: ShowSnapColors.grey300,
                            highlightColor: ShowSnapColors.grey100,
                            child: Container(
                                width: double.infinity,
                                height: double.infinity,
                                color: ShowSnapColors.grey300),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: ShowSnapColors.grey300,
                            child: const Icon(Icons.event_outlined,
                                size: 40, color: ShowSnapColors.grey600),
                          ),
                        ) : Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: ShowSnapColors.grey300,
                            child: const Icon(Icons.event_outlined,
                                size: 40, color: ShowSnapColors.grey600),
                        ),
                      ),
                      // Category Badge
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(ShowSnapRadius.sm),
                          ),
                          child: Text(
                            event.category.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      // Urgency Badge
                      if (event.fewTicketsLeft)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: ShowSnapColors.error.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(ShowSnapRadius.sm),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_fire_department, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'Few Left',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 12, color: ShowSnapColors.grey600),
                        const SizedBox(width: 4),
                        Text(
                          event.startTs.epochToDateLabel,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: ShowSnapColors.grey600),
                        ),
                      ],
                    ),
                    if (event.venueName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: ShowSnapColors.grey600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.venueName,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: ShowSnapColors.grey600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'From ₹${event.lowestPrice}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: ShowSnapColors.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (event.totalSeats > 0 && event.availableSeats == 0)
                           Text('SOLD OUT', style: TextStyle(color: ShowSnapColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (event.totalSeats > 0) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: (event.totalSeats - event.availableSeats) / event.totalSeats,
                          backgroundColor: ShowSnapColors.grey300,
                          valueColor: AlwaysStoppedAnimation(
                            event.fewTicketsLeft ? ShowSnapColors.error : ShowSnapColors.primary,
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
