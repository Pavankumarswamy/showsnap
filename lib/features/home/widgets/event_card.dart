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
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(ShowSnapRadius.md)),
                child: CachedNetworkImage(
                  imageUrl: event.posterUrl,
                  width: 200,
                  height: 120,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Shimmer.fromColors(
                    baseColor: ShowSnapColors.grey300,
                    highlightColor: ShowSnapColors.grey100,
                    child: Container(
                        width: 200,
                        height: 120,
                        color: ShowSnapColors.grey300),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 200,
                    height: 120,
                    color: ShowSnapColors.grey300,
                    child: const Icon(Icons.event_outlined,
                        size: 40, color: ShowSnapColors.grey600),
                  ),
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
                    Text(
                      'From ₹${event.lowestPrice}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: ShowSnapColors.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
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
