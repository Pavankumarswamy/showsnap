import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/banner_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/widgets/showsnap_toast.dart';

final _allBannersProvider = FutureProvider<List<BannerModel>>((ref) =>
    ref.watch(databaseServiceProvider).getAllBanners());

class AdminBannersScreen extends ConsumerWidget {
  const AdminBannersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(_allBannersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Banners',
            style: TextStyle(fontWeight: FontWeight.w800)),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: ShowSnapTheme.appBarGradient),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ShowSnapColors.primary,
        icon: const Icon(Icons.add, color: Colors.black87),
        label: const Text('Add Banner',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: Colors.black87)),
        onPressed: () => _showBannerDialog(context, ref, null),
      ),
      body: bannersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (banners) {
          if (banners.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image_outlined,
                      size: 80, color: ShowSnapColors.grey300),
                  const SizedBox(height: 16),
                  const Text('No banners yet',
                      style: TextStyle(
                          color: ShowSnapColors.grey600, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap + to add a banner to the home screen.',
                    style: TextStyle(
                        color: ShowSnapColors.grey600, fontSize: 13),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(_allBannersProvider.future),
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: banners.length,
              onReorder: (oldIndex, newIndex) async {
                if (newIndex > oldIndex) newIndex -= 1;
                final db = ref.read(databaseServiceProvider);
                // Reorder by swapping the `order` values
                for (var i = 0; i < banners.length; i++) {
                  final b = banners[i];
                  await db.saveBanner(BannerModel(
                    bannerId: b.bannerId,
                    title: b.title,
                    subtitle: b.subtitle,
                    imageUrl: b.imageUrl,
                    ctaText: b.ctaText,
                    ctaRoute: b.ctaRoute,
                    order: i == oldIndex
                        ? newIndex
                        : i == newIndex
                            ? oldIndex
                            : i,
                    isActive: b.isActive,
                  ));
                }
                ref.invalidate(_allBannersProvider);
              },
              itemBuilder: (_, i) {
                final banner = banners[i];
                return _BannerTile(
                  key: ValueKey(banner.bannerId),
                  banner: banner,
                  onEdit: () => _showBannerDialog(context, ref, banner),
                  onDelete: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dlgCtx) => AlertDialog(
                        title: const Text('Delete Banner?'),
                        content: Text('Remove "${banner.title}"?'),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.of(dlgCtx).pop(false),
                              child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: ShowSnapColors.error),
                            onPressed: () =>
                                Navigator.of(dlgCtx).pop(true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ref
                          .read(databaseServiceProvider)
                          .deleteBanner(banner.bannerId);
                      ref.invalidate(_allBannersProvider);
                      if (context.mounted) {
                        ShowSnapToast.show(context,
                            message: 'Banner deleted');
                      }
                    }
                  },
                  onToggle: (val) async {
                    await ref.read(databaseServiceProvider).saveBanner(
                          BannerModel(
                            bannerId: banner.bannerId,
                            title: banner.title,
                            subtitle: banner.subtitle,
                            imageUrl: banner.imageUrl,
                            ctaText: banner.ctaText,
                            ctaRoute: banner.ctaRoute,
                            order: banner.order,
                            isActive: val,
                          ),
                        );
                    ref.invalidate(_allBannersProvider);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showBannerDialog(
      BuildContext context, WidgetRef ref, BannerModel? existing) {
    final titleCtrl =
        TextEditingController(text: existing?.title ?? '');
    final subtitleCtrl =
        TextEditingController(text: existing?.subtitle ?? '');
    final imageCtrl =
        TextEditingController(text: existing?.imageUrl ?? '');
    final ctaTextCtrl =
        TextEditingController(text: existing?.ctaText ?? '');
    final ctaRouteCtrl =
        TextEditingController(text: existing?.ctaRoute ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'New Banner' : 'Edit Banner'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Title *',
                    hintText: 'e.g. Weekend Special'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subtitleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Subtitle',
                    hintText: 'e.g. Family packages from ₹599'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: imageCtrl,
                decoration: const InputDecoration(
                    labelText: 'Image URL',
                    hintText: 'Cloudinary or any HTTPS URL'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctaTextCtrl,
                decoration: const InputDecoration(
                    labelText: 'Button Label',
                    hintText: 'e.g. Book Now, Explore'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctaRouteCtrl,
                decoration: const InputDecoration(
                    labelText: 'Navigate To (optional)',
                    hintText: 'e.g. /explore or /movie/abc123'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              final db = ref.read(databaseServiceProvider);
              final count = (await db.getAllBanners()).length;
              await db.saveBanner(BannerModel(
                bannerId: existing?.bannerId ?? '',
                title: titleCtrl.text.trim(),
                subtitle: subtitleCtrl.text.trim(),
                imageUrl: imageCtrl.text.trim(),
                ctaText: ctaTextCtrl.text.trim(),
                ctaRoute: ctaRouteCtrl.text.trim(),
                order: existing?.order ?? count,
                isActive: existing?.isActive ?? true,
              ));
              ref.invalidate(_allBannersProvider);
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) {
                ShowSnapToast.show(context,
                    message: existing == null
                        ? 'Banner added'
                        : 'Banner updated');
              }
            },
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }
}

class _BannerTile extends StatelessWidget {
  final BannerModel banner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(bool) onToggle;

  const _BannerTile({
    super.key,
    required this.banner,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: banner.imageUrl.isNotEmpty
              ? Image.network(
                  banner.imageUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _PlaceholderThumb(),
                )
              : _PlaceholderThumb(),
        ),
        title: Text(
          banner.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (banner.subtitle.isNotEmpty)
              Text(banner.subtitle,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12)),
            if (banner.ctaRoute.isNotEmpty)
              Text(banner.ctaRoute,
                  style: const TextStyle(
                      fontSize: 11, color: ShowSnapColors.grey600)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: banner.isActive,
              onChanged: onToggle,
              activeColor: ShowSnapColors.secondary,
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete',
                        style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderThumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 56,
        height: 56,
        color: ShowSnapColors.primaryLighter,
        child: const Icon(Icons.image_outlined,
            color: ShowSnapColors.primary, size: 24),
      );
}
