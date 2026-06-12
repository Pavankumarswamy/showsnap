import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/ad_request_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/extensions.dart';

final _adRequestsProvider = FutureProvider<List<AdRequestModel>>((ref) {
  return ref.watch(databaseServiceProvider).getAdRequests();
});

final _adStatusTabProvider = StateProvider<AdRequestStatus>((ref) =>
    AdRequestStatus.pending);

final _adTypeFilterProvider = StateProvider<AdRequestType?>(
    (ref) => null); // null = all types

class AdRequestsScreen extends ConsumerWidget {
  const AdRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(_adRequestsProvider);
    final tabStatus = ref.watch(_adStatusTabProvider);
    final typeFilter = ref.watch(_adTypeFilterProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ad Requests'),
          flexibleSpace: Container(
            decoration:
                BoxDecoration(gradient: ShowSnapTheme.appBarGradient),
          ),
          bottom: TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.black,
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
            // ── Type filter chips ─────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  const Text('Type:',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(width: 8),
                  _TypeChip(
                    label: 'All',
                    selected: typeFilter == null,
                    onTap: () => ref
                        .read(_adTypeFilterProvider.notifier)
                        .state = null,
                  ),
                  const SizedBox(width: 6),
                  _TypeChip(
                    label: 'Influencer',
                    color: Colors.deepPurple,
                    selected: typeFilter == AdRequestType.influencer,
                    onTap: () => ref
                        .read(_adTypeFilterProvider.notifier)
                        .state = AdRequestType.influencer,
                  ),
                  const SizedBox(width: 6),
                  _TypeChip(
                    label: 'Theater',
                    color: Colors.teal,
                    selected: typeFilter == AdRequestType.theater,
                    onTap: () => ref
                        .read(_adTypeFilterProvider.notifier)
                        .state = AdRequestType.theater,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // ── Requests list ─────────────────────────────────────────────
            Expanded(
              child: requestsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (requests) {
                  var filtered = requests
                      .where((r) => r.status == tabStatus)
                      .toList();
                  if (typeFilter != null) {
                    filtered = filtered
                        .where((r) => r.requestType == typeFilter)
                        .toList();
                  }
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                          'No ${tabStatus.label.toLowerCase()} ${typeFilter?.label.toLowerCase() ?? ''} requests'),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(_adRequestsProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) =>
                          _AdRequestCard(request: filtered[i]),
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
    required this.onTap,
    this.color = ShowSnapColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : ShowSnapColors.grey100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : ShowSnapColors.grey300),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? color : ShowSnapColors.grey600)),
      ),
    );
  }
}

class _AdRequestCard extends ConsumerWidget {
  final AdRequestModel request;
  const _AdRequestCard({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(request.brandName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                // ── Type badge ────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _typeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _typeColor),
                  ),
                  child: Text(request.requestType.label,
                      style: TextStyle(
                          color: _typeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
                // ── Status badge ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _statusColor),
                  ),
                  child: Text(request.status.label,
                      style: TextStyle(
                          color: _statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(request.campaignTitle,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('Budget: ${request.budgetRange}',
                style: const TextStyle(color: ShowSnapColors.grey600)),
            Text(
                'Dates: ${request.startDateTs.epochToDateLabel} — ${request.endDateTs.epochToDateLabel}',
                style: const TextStyle(color: ShowSnapColors.grey600)),
            if (request.creativeUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: request.creativeUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: request.creativeUrls[i],
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox(
                        width: 80,
                        height: 80,
                        child: Icon(Icons.image_outlined),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (request.status == AdRequestStatus.pending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close, color: ShowSnapColors.error),
                      label: const Text('Reject',
                          style: TextStyle(color: ShowSnapColors.error)),
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: ShowSnapColors.error)),
                      onPressed: () =>
                          _showRejectDialog(context, ref),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: ShowSnapColors.secondary),
                      onPressed: () =>
                          _approve(context, ref),
                    ),
                  ),
                ],
              ),
            ],
            if (request.adminNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ShowSnapColors.grey100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Note: ${request.adminNote}',
                    style: const TextStyle(
                        fontSize: 12, color: ShowSnapColors.grey600)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color get _typeColor => request.requestType == AdRequestType.theater
      ? Colors.teal
      : Colors.deepPurple;

  Color get _statusColor {
    switch (request.status) {
      case AdRequestStatus.approved:
        return ShowSnapColors.secondary;
      case AdRequestStatus.rejected:
        return ShowSnapColors.error;
      default:
        return ShowSnapColors.primary;
    }
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    await ref.read(databaseServiceProvider).updateAdRequest(
        request.requestId, {'status': AdRequestStatus.approved.name});
    ref.invalidate(_adRequestsProvider);
    if (context.mounted) context.showSnackbar('Request approved');
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Request'),
        content: TextField(
          controller: noteCtrl,
          decoration:
              const InputDecoration(labelText: 'Feedback (optional)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: ShowSnapColors.error),
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
                context.showSnackbar('Request rejected');
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}
