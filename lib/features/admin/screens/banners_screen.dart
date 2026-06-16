import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/config/router.dart';
import '../../../core/config/staff_theme.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/banner_model.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/widgets/showsnap_toast.dart';

final _allBannersProvider = FutureProvider<List<BannerModel>>(
    (ref) => ref.watch(databaseServiceProvider).getAllBanners());

class AdminBannersScreen extends ConsumerWidget {
  const AdminBannersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(_allBannersProvider);

    return PushDrawerLayout(
      backgroundColor: AdminColors.background,
      drawer: AdminDrawer(
        currentRoute: AppRoutes.adminBanners,
        onNavigateTo: (route) => context.push(route),
        onSignOut: () {},
      ),
      appBar: AppBar(
        backgroundColor: AdminColors.surface,
        foregroundColor: AdminColors.textPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AdminColors.border),
        ),
        title: const Text(
          'Manage Banners',
          style: TextStyle(
              color: AdminColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AdminColors.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label:
            const Text('Add Banner', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showBannerDialog(context, ref, null),
      ),
      body: bannersAsync.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: StaffShimmerCard(
              height: 80,
              baseColor: AdminColors.surface,
              highlightColor: AdminColors.surfaceElevated,
            ),
          ),
        ),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: AdminColors.error))),
        data: (banners) {
          if (banners.isEmpty) {
            return StaffEmptyState(
              icon: Icons.image_outlined,
              message: 'No banners yet.\nTap + to add one.',
            );
          }
          return RefreshIndicator(
            color: AdminColors.primary,
            backgroundColor: AdminColors.surface,
            onRefresh: () => ref.refresh(_allBannersProvider.future),
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: banners.length,
              proxyDecorator: (child, _, __) => Material(
                color: Colors.transparent,
                child: child,
              ),
              onReorder: (oldIndex, newIndex) async {
                if (newIndex > oldIndex) newIndex -= 1;
                final db = ref.read(databaseServiceProvider);
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
                    final ok = await StaffConfirmDialog.show(
                      context,
                      title: 'Delete Banner',
                      message: 'Remove "${banner.title}"? This cannot be undone.',
                      confirmLabel: 'Delete',
                      isDangerous: true,
                    );
                    if (ok == true) {
                      await ref
                          .read(databaseServiceProvider)
                          .deleteBanner(banner.bannerId);
                      ref.invalidate(_allBannersProvider);
                      if (context.mounted) {
                        ShowSnapToast.success(context, 'Banner deleted');
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
                ).animate().fadeIn(duration: 350.ms, delay: (i % 6 * 50).ms);
              },
            ),
          );
        },
      ),
    );
  }

  void _showBannerDialog(
      BuildContext context, WidgetRef ref, BannerModel? existing) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final subtitleCtrl = TextEditingController(text: existing?.subtitle ?? '');
    final imageCtrl = TextEditingController(text: existing?.imageUrl ?? '');
    final ctaTextCtrl = TextEditingController(text: existing?.ctaText ?? '');
    final ctaRouteCtrl = TextEditingController(text: existing?.ctaRoute ?? '');
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AdminColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ShowSnapRadius.md),
            side: const BorderSide(color: AdminColors.border),
          ),
          title: Text(
            existing == null ? 'New Banner' : 'Edit Banner',
            style: const TextStyle(
                color: AdminColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _darkField(titleCtrl, 'Title *'),
                const SizedBox(height: 12),
                _darkField(subtitleCtrl, 'Subtitle'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _darkField(imageCtrl, 'Image URL')),
                    const SizedBox(width: 8),
                    isUploading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AdminColors.primary)),
                          )
                        : IconButton(
                            icon: const Icon(Icons.upload_file,
                                color: AdminColors.primary),
                            tooltip: 'Upload Image',
                            onPressed: () async {
                              final picker = ImagePicker();
                              final file = await picker.pickImage(
                                  source: ImageSource.gallery);
                              if (file != null) {
                                setS(() => isUploading = true);
                                try {
                                  final cloudinary =
                                      ref.read(cloudinaryServiceProvider);
                                  final url = await cloudinary.uploadImage(
                                      File(file.path), 'banners');
                                  imageCtrl.text = url;
                                } catch (e) {
                                  if (ctx.mounted) {
                                    ShowSnapToast.error(
                                        ctx, 'Upload failed: $e');
                                  }
                                } finally {
                                  if (ctx.mounted) {
                                    setS(() => isUploading = false);
                                  }
                                }
                              }
                            },
                          ),
                  ],
                ),
                const SizedBox(height: 12),
                _darkField(ctaTextCtrl, 'Button Label (e.g. Book Now)'),
                const SizedBox(height: 12),
                _darkField(ctaRouteCtrl, 'Navigate To (e.g. /explore)'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: AdminColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ShowSnapRadius.md)),
              ),
              onPressed: isUploading
                  ? null
                  : () async {
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
                        ShowSnapToast.success(
                          context,
                          existing == null ? 'Banner added' : 'Banner updated',
                        );
                      }
                    },
              child: Text(
                existing == null ? 'Add' : 'Save',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _darkField(TextEditingController ctrl, String label) {
  return TextField(
    controller: ctrl,
    style: const TextStyle(color: AdminColors.textPrimary),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AdminColors.textSecondary),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        borderSide: const BorderSide(color: AdminColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        borderSide: const BorderSide(color: AdminColors.primary),
      ),
      filled: true,
      fillColor: AdminColors.surfaceElevated,
    ),
  );
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        children: [
          // Drag handle
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(Icons.drag_handle_rounded,
                color: AdminColors.textMuted, size: 20),
          ),
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(ShowSnapRadius.sm),
            child: banner.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: banner.imageUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _Thumb(),
                  )
                : _Thumb(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  banner.title,
                  style: const TextStyle(
                      color: AdminColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (banner.subtitle.isNotEmpty)
                  Text(
                    banner.subtitle,
                    style: const TextStyle(
                        color: AdminColors.textSecondary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (banner.ctaRoute.isNotEmpty)
                  Text(
                    banner.ctaRoute,
                    style: const TextStyle(
                        color: AdminColors.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ),
          Switch(
            value: banner.isActive,
            onChanged: onToggle,
            activeColor: AdminColors.success,
            inactiveTrackColor: AdminColors.border,
          ),
          PopupMenuButton<String>(
            color: AdminColors.surfaceElevated,
            icon: const Icon(Icons.more_vert_rounded,
                color: AdminColors.textSecondary, size: 20),
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Text('Edit',
                    style: TextStyle(color: AdminColors.textPrimary)),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete',
                    style: TextStyle(color: AdminColors.error)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 56,
        height: 56,
        color: AdminColors.surfaceElevated,
        child: const Icon(Icons.image_outlined,
            color: AdminColors.textMuted, size: 24),
      );
}
