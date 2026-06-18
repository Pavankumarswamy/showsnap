import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/config/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/models/event_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/file_save_helper.dart'
    if (dart.library.html) '../../../core/utils/file_save_helper_web.dart'
    if (dart.library.io) '../../../core/utils/file_save_helper_native.dart';
import '../../../core/utils/url_launcher_helper.dart'
    if (dart.library.html) '../../../core/utils/url_launcher_helper_web.dart'
    if (dart.library.io) '../../../core/utils/url_launcher_helper_native.dart';
import '../../../core/widgets/showsnap_toast.dart';
import '../../../core/widgets/tappable_scale.dart';


// ─── Provider ─────────────────────────────────────────────────────────────────

final _eventDetailProvider =
    FutureProvider.family<EventModel?, String>((ref, eventId) async {
  return await ref.watch(databaseServiceProvider).getEvent(eventId);
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  // Map: tier index → quantity selected
  final Map<int, int> _tierQuantities = {};
  bool _booking = false;

  int get _totalTickets =>
      _tierQuantities.values.fold(0, (s, q) => s + q);

  int _totalPrice(EventModel event) {
    int sum = 0;
    for (final entry in _tierQuantities.entries) {
      if (entry.key < event.ticketTiers.length) {
        sum += event.ticketTiers[entry.key].price * entry.value;
      }
    }
    return sum;
  }

  void _adjustQuantity(int tierIndex, int delta, int maxAvailable) {
    final current = _tierQuantities[tierIndex] ?? 0;
    final newVal = (current + delta).clamp(0, maxAvailable.clamp(0, 6));
    setState(() {
      if (newVal == 0) {
        _tierQuantities.remove(tierIndex);
      } else {
        _tierQuantities[tierIndex] = newVal;
      }
    });
    if (delta > 0) HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(_eventDetailProvider(widget.eventId));
    return eventAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Error: $e'))),
      data: (event) {
        if (event == null) {
          return const Scaffold(
              body: Center(child: Text('Event not found')));
        }
        return _buildContent(event);
      },
    );
  }

  Widget _buildContent(EventModel event) {
    final total = _totalPrice(event);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.width / (4 / 3),
            pinned: true,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            leading: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
            ),
            actions: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final message =
                      '🎉 Check out *${event.name}*!\n\n'
                      '📍 ${event.venueName}, ${event.city}\n'
                      '📅 ${event.startTs.epochToDateTimeLabel}\n'
                      '🎟️ Tickets from ₹${event.lowestPrice}\n\n'
                      'Book now on ShowSnap: https://showsnap.web.app/event/${event.eventId}';
                  Share.share(message);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share, color: Colors.white, size: 20),
                ),
              ),
            ],
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: false,
              titlePadding:
                  const EdgeInsets.only(left: 16, bottom: 16, right: 16),
              title: Text(
                event.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'event_poster_${event.eventId}',
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
                                child: const Icon(Icons.celebration_outlined, size: 80),
                              ),
                            )
                          : Container(
                              color: ShowSnapColors.grey300,
                              child: const Icon(Icons.celebration_outlined, size: 80),
                            ),
                    ),
                    IgnorePointer(
                      child: Stack(
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 120,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.6),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date/time/venue
                  _InfoCard(event: event),

                  const SizedBox(height: 16),

                  // Description
                  if (event.description.isNotEmpty) ...[
                    Text('About',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(event.description,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                                color: ShowSnapColors.grey600,
                                height: 1.6)),
                    const SizedBox(height: 20),
                  ],

                  // Ticket tiers
                  Text('Select Tickets',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  if (event.ticketTiers.isEmpty)
                    const Text('No ticket tiers available',
                        style: TextStyle(color: ShowSnapColors.grey600))
                  else
                    ...event.ticketTiers.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final tier = entry.value;
                      final qty = _tierQuantities[idx] ?? 0;
                      return _TierRow(
                        tier: tier,
                        quantity: qty,
                        onAdd: tier.availableSeats > 0
                            ? () => _adjustQuantity(
                                idx, 1, tier.availableSeats)
                            : null,
                        onRemove: qty > 0
                            ? () => _adjustQuantity(idx, -1,
                                tier.availableSeats)
                            : null,
                      )
                          .animate()
                          .fadeIn(
                              duration: ShowSnapDuration.normal,
                              delay: Duration(milliseconds: 50 * idx))
                          .slideX(
                              begin: 0.05,
                              end: 0,
                              delay: Duration(milliseconds: 50 * idx));
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _totalTickets > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TappableScale(
                  onTap: _booking ? null : () => _handleBook(event),
                  child: Container(
                    height: 56,
                    decoration: ShowSnapTheme.primaryButtonDecoration,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(ShowSnapRadius.md),
                        onTap: _booking ? null : () => _handleBook(event),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_booking)
                              const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                            else ...[
                              const Icon(Icons.local_activity_outlined,
                                  color: Colors.black87),
                              const SizedBox(width: 8),
                              Text(
                                'Book $_totalTickets Ticket${_totalTickets > 1 ? 's' : ''} — ₹$total',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black87),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.local_activity_outlined),
                  label: const Text('Select Tickets Above'),
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(ShowSnapRadius.md)),
                  ),
                ),
              ),
            ),
    );
  }

  void _handleBook(EventModel event) {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) {
      ShowSnapToast.show(context, message: 'Please log in first', type: ToastType.error);
      return;
    }

    context.push('/event-summary', extra: {
      'eventId': event.eventId,
      'tierQuantities': Map<int, int>.from(_tierQuantities),
    });
  }
}


// ─── Info Card ────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final EventModel event;
  const _InfoCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ShowSnapColors.surface,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        boxShadow: ShowSnapShadow.card,
      ),
      child: Column(
        children: [
          _Row(Icons.calendar_today_outlined,
              event.startTs.epochToDateTimeLabel),
          if (event.venueName.isNotEmpty)
            _Row(Icons.location_on_outlined, event.venueName),
          if (event.organizer.isNotEmpty)
            _Row(Icons.business_outlined,
                'Organized by ${event.organizer}'),
          _Row(Icons.category_outlined,
              event.category[0].toUpperCase() +
                  event.category.substring(1)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Row(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: ShowSnapColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

// ─── Tier Row ─────────────────────────────────────────────────────────────────

class _TierRow extends StatefulWidget {
  final TicketTier tier;
  final int quantity;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;
  const _TierRow({
    required this.tier,
    required this.quantity,
    this.onAdd,
    this.onRemove,
  });

  @override
  State<_TierRow> createState() => _TierRowState();
}

class _TierRowState extends State<_TierRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceCtrl;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  void _onAdd() {
    widget.onAdd?.call();
    _bounceCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isSoldOut = widget.tier.availableSeats <= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ShowSnapColors.surface,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        boxShadow: ShowSnapShadow.card,
        border: widget.quantity > 0
            ? Border.all(color: ShowSnapColors.primary)
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.tier.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  isSoldOut
                      ? 'Sold Out'
                      : '${widget.tier.availableSeats} available',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSoldOut
                        ? ShowSnapColors.error
                        : ShowSnapColors.grey600,
                  ),
                ),
              ],
            ),
          ),
          Text('₹${widget.tier.price}',
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: ShowSnapColors.primary)),
          const SizedBox(width: 12),
          // Stepper
          if (isSoldOut)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ShowSnapColors.grey300,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Sold Out',
                  style: TextStyle(
                      fontSize: 11, color: ShowSnapColors.grey600)),
            )
          else
            Row(
              children: [
                _StepBtn(
                  icon: Icons.remove,
                  onTap: widget.onRemove,
                  enabled: widget.quantity > 0,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 1.3)
                        .chain(CurveTween(curve: Curves.elasticOut))
                        .animate(_bounceCtrl),
                    child: Text(
                      '${widget.quantity}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
                _StepBtn(
                  icon: Icons.add,
                  onTap: _onAdd,
                  enabled: widget.onAdd != null &&
                      widget.quantity < 6,
                  isPrimary: true,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  final bool isPrimary;
  const _StepBtn({
    required this.icon,
    this.onTap,
    this.enabled = true,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: ShowSnapDuration.fast,
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled
              ? (isPrimary
                  ? ShowSnapColors.primary
                  : ShowSnapColors.grey100)
              : ShowSnapColors.grey300,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? (isPrimary ? Colors.black87 : Colors.black87)
              : ShowSnapColors.grey600,
        ),
      ),
    );
  }
}
