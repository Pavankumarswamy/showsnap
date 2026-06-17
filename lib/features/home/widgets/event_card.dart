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
  final double? width;

  const EventCard({super.key, required this.event, this.width});

  @override
  Widget build(BuildContext context) {
    return TappableScale(
      onTap: () => context.push('/event/${event.eventId}'),
      child: Container(
        width: width ?? 200, // Default to 200 for horizontal lists, but GridView can override
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(ShowSnapRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(ShowSnapRadius.lg)),
                    child: event.posterUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: event.posterUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Shimmer.fromColors(
                              baseColor: ShowSnapColors.grey300,
                              highlightColor: ShowSnapColors.grey100,
                              child: Container(color: ShowSnapColors.grey300),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: ShowSnapColors.grey300,
                              child: const Icon(Icons.celebration_outlined,
                                  size: 40, color: ShowSnapColors.grey600),
                            ),
                          )
                        : Container(
                            color: ShowSnapColors.grey300,
                            child: const Icon(Icons.celebration_outlined,
                                size: 40, color: ShowSnapColors.grey600),
                          ),
                  ),
                  // Gradient Overlay for better text readability on the image
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Date Badge (Top Right)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_month, size: 12, color: ShowSnapColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            event.startTs.epochToDateLabel,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Gilroy',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Category Badge (Bottom Left)
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ShowSnapColors.primary.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(ShowSnapRadius.sm),
                      ),
                      child: Text(
                        event.category.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  // Urgency Badge (Bottom Right)
                  if (event.fewTicketsLeft)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: ShowSnapColors.error,
                          borderRadius: BorderRadius.circular(ShowSnapRadius.sm),
                          boxShadow: [
                            BoxShadow(
                              color: ShowSnapColors.error.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_fire_department, color: Colors.white, size: 10),
                            SizedBox(width: 4),
                            Text(
                              'FAST SELLING',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
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
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (event.venueName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: ShowSnapColors.grey600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${event.venueName}, ${event.city}',
                            style: const TextStyle(
                              color: ShowSnapColors.grey600,
                              fontSize: 11,
                              fontFamily: 'Gilroy',
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Starting from',
                            style: TextStyle(
                              color: ShowSnapColors.grey600,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '₹${event.lowestPrice}',
                            style: const TextStyle(
                              color: ShowSnapColors.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Gilroy',
                            ),
                          ),
                        ],
                      ),
                      if (event.totalSeats > 0 && event.availableSeats == 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: ShowSnapColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'SOLD OUT',
                            style: TextStyle(
                              color: ShowSnapColors.error,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      else if (event.totalSeats > 0)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${event.availableSeats} left',
                              style: TextStyle(
                                color: event.fewTicketsLeft
                                    ? ShowSnapColors.error
                                    : Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 60,
                              height: 4,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: (event.totalSeats - event.availableSeats) /
                                      event.totalSeats,
                                  backgroundColor: ShowSnapColors.grey300,
                                  valueColor: AlwaysStoppedAnimation(
                                    event.fewTicketsLeft
                                        ? ShowSnapColors.error
                                        : Colors.green,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
