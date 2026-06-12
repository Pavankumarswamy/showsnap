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

class AdRequestsScreen extends ConsumerWidget {
  const AdRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(_adRequestsProvider);
    final tabStatus = ref.watch(_adStatusTabProvider);

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
        body: requestsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (requests) {
            final filtered = requests
                .where((r) => r.status == tabStatus)
                .toList();
            if (filtered.isEmpty) {
              return Center(
                child: Text('No ${tabStatus.label.toLowerCase()} requests'),
              );
            }
            return RefreshIndicator(
              onRefresh: () => ref.refresh(_adRequestsProvider.future),
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) =>
                    _AdRequestCard(request: filtered[i]),
              ),
            );
          },
        ),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(request.brandName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
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
