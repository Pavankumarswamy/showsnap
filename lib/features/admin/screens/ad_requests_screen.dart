import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/router.dart';
import '../../../core/config/staff_theme.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/ad_request_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/showsnap_toast.dart';

final _adRequestsProvider = FutureProvider<List<AdRequestModel>>((ref) {
  return ref.watch(databaseServiceProvider).getAdRequests();
});

final _adStatusTabProvider =
    StateProvider<AdRequestStatus>((ref) => AdRequestStatus.pending);
final _adTypeFilterProvider = StateProvider<AdRequestType?>((ref) => null);

class AdRequestsScreen extends ConsumerWidget {
  const AdRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(_adRequestsProvider);
    final tabStatus = ref.watch(_adStatusTabProvider);
    final typeFilter = ref.watch(_adTypeFilterProvider);

    return DefaultTabController(
      length: 3,
      child: PushDrawerLayout(
        backgroundColor: AdminColors.background,
        drawer: AdminDrawer(
          currentRoute: AppRoutes.adRequests,
          onNavigateTo: (route) => context.push(route),
          onSignOut: () {},
        ),
        appBar: AppBar(
          backgroundColor: AdminColors.surface,
          foregroundColor: AdminColors.textPrimary,
          elevation: 0,
          title: const Text(
            'Ad Requests',
            style: TextStyle(
                color: AdminColors.textPrimary,
                fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            labelColor: AdminColors.primary,
            unselectedLabelColor: AdminColors.textSecondary,
            indicatorColor: AdminColors.primary,
            indicatorWeight: 2,
            dividerColor: AdminColors.border,
            onTap: (i) {
              ref.read(_adStatusTabProvider.notifier).state =
                  AdRequestStatus.values[i];
            },
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Rejected'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Type filter
            Container(
              color: AdminColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const Text('Type:',
                      style: TextStyle(
                          color: AdminColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                  const SizedBox(width: 8),
                  _TypeChip(
                    label: 'All',
                    selected: typeFilter == null,
                    color: AdminColors.primary,
                    onTap: () => ref
                        .read(_adTypeFilterProvider.notifier)
                        .state = null,
                  ),
                  const SizedBox(width: 6),
                  _TypeChip(
                    label: 'Influencer',
                    selected: typeFilter == AdRequestType.influencer,
                    color: Colors.deepPurple,
                    onTap: () => ref
                        .read(_adTypeFilterProvider.notifier)
                        .state = AdRequestType.influencer,
                  ),
                  const SizedBox(width: 6),
                  _TypeChip(
                    label: 'Theater',
                    selected: typeFilter == AdRequestType.theater,
                    color: Colors.teal,
                    onTap: () => ref
                        .read(_adTypeFilterProvider.notifier)
                        .state = AdRequestType.theater,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),
            const Divider(color: AdminColors.border, height: 1),
            // Content
            Expanded(
              child: requestsAsync.when(
                loading: () => ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 4,
                  itemBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: StaffShimmerCard(
                      height: 180,
                      baseColor: AdminColors.surface,
                      highlightColor: AdminColors.surfaceElevated,
                    ),
                  ),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(color: AdminColors.error)),
                ),
                data: (requests) {
                  var filtered =
                      requests.where((r) => r.status == tabStatus).toList();
                  if (typeFilter != null) {
                    filtered = filtered
                        .where((r) => r.requestType == typeFilter)
                        .toList();
                  }

                  if (filtered.isEmpty) {
                    return StaffEmptyState(
                      icon: Icons.campaign_outlined,
                      message:
                          'No ${tabStatus.label.toLowerCase()} requests',
                    );
                  }

                  return RefreshIndicator(
                    color: AdminColors.primary,
                    backgroundColor: AdminColors.surface,
                    onRefresh: () async =>
                        ref.invalidate(_adRequestsProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (_, i) =>
                          _AdRequestCard(request: filtered[i])
                              .animate()
                              .fadeIn(
                                  duration: 400.ms,
                                  delay: (i % 6 * 60).ms)
                              .slideY(begin: 0.08, end: 0),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 150.ms,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : AdminColors.surface,
          borderRadius: BorderRadius.circular(ShowSnapRadius.pill),
          border: Border.all(
              color: selected ? color : AdminColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    selected ? color : AdminColors.textSecondary)),
      ),
    );
  }
}

class _AdRequestCard extends ConsumerWidget {
  final AdRequestModel request;
  const _AdRequestCard({required this.request});

  Color get _typeColor => request.requestType == AdRequestType.theater
      ? Colors.teal
      : Colors.deepPurple;

  Color get _statusColor {
    switch (request.status) {
      case AdRequestStatus.approved:
        return AdminColors.success;
      case AdRequestStatus.rejected:
        return AdminColors.error;
      default:
        return AdminColors.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.brandName,
                  style: const TextStyle(
                      color: AdminColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StaffBadge(label: request.requestType.label, color: _typeColor),
              const SizedBox(width: 6),
              StaffBadge(label: request.status.label, color: _statusColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            request.campaignTitle,
            style: const TextStyle(
                color: AdminColors.textSecondary,
                fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Budget: ${request.budgetRange}',
            style: const TextStyle(
                color: AdminColors.textMuted, fontSize: 12),
          ),
          Text(
            'Dates: ${request.startDateTs.epochToDateLabel} — ${request.endDateTs.epochToDateLabel}',
            style: const TextStyle(
                color: AdminColors.textMuted, fontSize: 12),
          ),
          // Creatives
          if (request.creativeUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: request.creativeUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(ShowSnapRadius.sm),
                  child: CachedNetworkImage(
                    imageUrl: request.creativeUrls[i],
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      color: AdminColors.surfaceElevated,
                      child: const Icon(Icons.image_outlined,
                          color: AdminColors.textMuted),
                    ),
                  ),
                ),
              ),
            ),
          ],
          // Admin note
          if (request.adminNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AdminColors.surfaceElevated,
                borderRadius:
                    BorderRadius.circular(ShowSnapRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.note_rounded,
                      color: AdminColors.textMuted, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      request.adminNote,
                      style: const TextStyle(
                          color: AdminColors.textSecondary,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Actions for pending
          if (request.status == AdRequestStatus.pending) ...[
            const SizedBox(height: 12),
            const Divider(color: AdminColors.border, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close,
                        color: AdminColors.error, size: 16),
                    label: const Text('Reject',
                        style: TextStyle(color: AdminColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AdminColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(ShowSnapRadius.md),
                      ),
                    ),
                    onPressed: () =>
                        _showRejectDialog(context, ref),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminColors.success,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(ShowSnapRadius.md),
                      ),
                    ),
                    onPressed: () => _approve(context, ref),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    await ref.read(databaseServiceProvider).updateAdRequest(
        request.requestId,
        {'status': AdRequestStatus.approved.name});
    ref.invalidate(_adRequestsProvider);
    if (context.mounted) {
      ShowSnapToast.success(context, 'Request approved');
    }
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AdminColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          side: const BorderSide(color: AdminColors.border),
        ),
        title: const Text('Reject Request',
            style: TextStyle(
                color: AdminColors.textPrimary,
                fontWeight: FontWeight.bold)),
        content: TextField(
          controller: noteCtrl,
          style: const TextStyle(color: AdminColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Rejection reason (optional)',
            labelStyle:
                const TextStyle(color: AdminColors.textSecondary),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ShowSnapRadius.md),
              borderSide: const BorderSide(color: AdminColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ShowSnapRadius.md),
              borderSide:
                  const BorderSide(color: AdminColors.primary),
            ),
            filled: true,
            fillColor: AdminColors.surfaceElevated,
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AdminColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ShowSnapRadius.md),
              ),
            ),
            onPressed: () async {
              await ref.read(databaseServiceProvider).updateAdRequest(
                request.requestId,
                {
                  'status': AdRequestStatus.rejected.name,
                  'adminNote': noteCtrl.text.trim(),
                },
              );
              ref.invalidate(_adRequestsProvider);
              if (context.mounted) {
                Navigator.pop(context);
                ShowSnapToast.error(context, 'Request rejected');
              }
            },
            child: const Text('Reject',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
