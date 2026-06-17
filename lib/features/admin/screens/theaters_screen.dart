import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/router.dart';
import '../../../core/config/staff_theme.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/theater_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/widgets/showsnap_toast.dart';

final _theatersProvider = FutureProvider<List<TheaterModel>>((ref) {
  return ref.watch(databaseServiceProvider).getAllTheaters();
});

final _theaterSearchProvider = StateProvider<String>((ref) => '');

class TheatersScreen extends ConsumerWidget {
  const TheatersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theatersAsync = ref.watch(_theatersProvider);
    final search = ref.watch(_theaterSearchProvider);

    return PushDrawerLayout(
      backgroundColor: AdminColors.background,
      drawer: AdminDrawer(
        currentRoute: AppRoutes.adminTheaters,
        onNavigateTo: (route) => context.push(route),
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
          'Theaters',
          style: TextStyle(
              color: AdminColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business_rounded,
                color: AdminColors.primary),
            tooltip: 'Add Theater',
            onPressed: () async {
              final result = await context.push(AppRoutes.addTheater);
              if (result != null) {
                ref.invalidate(_theatersProvider);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: StaffSearchBar(
              hint: 'Search theaters by name or city',
              onChanged: (v) =>
                  ref.read(_theaterSearchProvider.notifier).state = v,
            ),
          ).animate().fadeIn(duration: 300.ms),
          Expanded(
            child: theatersAsync.when(
              loading: () => _buildSkeleton(),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: const TextStyle(color: AdminColors.error)),
              ),
              data: (theaters) {
                var filtered = theaters;
                if (search.isNotEmpty) {
                  final q = search.toLowerCase();
                  filtered = filtered
                      .where((t) =>
                          t.name.toLowerCase().contains(q) ||
                          t.city.toLowerCase().contains(q))
                      .toList();
                }

                if (filtered.isEmpty) {
                  return StaffEmptyState(
                    icon: Icons.theaters_outlined,
                    message: theaters.isEmpty
                        ? 'No theaters yet. Add your first theater.'
                        : 'No theaters match your search.',
                    ctaLabel: theaters.isEmpty ? 'Add Theater' : null,
                    onCta: theaters.isEmpty
                        ? () => context.push(AppRoutes.addTheater)
                        : null,
                  );
                }

                return RefreshIndicator(
                  color: AdminColors.primary,
                  backgroundColor: AdminColors.surface,
                  onRefresh: () => ref.refresh(_theatersProvider.future),
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 360,
                      mainAxisExtent: 260,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _TheaterCard(
                      theater: filtered[i],
                      onRefresh: () => ref.invalidate(_theatersProvider),
                    )
                        .animate()
                        .fadeIn(
                            duration: 350.ms, delay: (i % 6 * 60).ms)
                        .slideY(begin: 0.1, end: 0),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
        mainAxisExtent: 260,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const StaffShimmerCard(
        height: 260,
        baseColor: AdminColors.surface,
        highlightColor: AdminColors.surfaceElevated,
      ),
    );
  }
}

class _TheaterCard extends ConsumerWidget {
  final TheaterModel theater;
  final VoidCallback onRefresh;

  const _TheaterCard({required this.theater, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = theater.isActive;

    return Container(
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        border: Border.all(color: AdminColors.border),
        boxShadow: StaffShadow.subtle,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner image
          SizedBox(
            height: 110,
            width: double.infinity,
            child: theater.logoUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: theater.logoUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _placeholderBanner(),
                  )
                : _placeholderBanner(),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          theater.name,
                          style: const TextStyle(
                            color: AdminColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      StaffBadge(
                        label: isActive ? 'Active' : 'Inactive',
                        color: isActive
                            ? AdminColors.success
                            : AdminColors.textMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 12, color: AdminColors.textMuted),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          theater.city,
                          style: const TextStyle(
                              color: AdminColors.textSecondary,
                              fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionBtn(
                          label: 'Edit',
                          icon: Icons.edit_rounded,
                          color: AdminColors.info,
                          onTap: () {
                            context.push(AppRoutes.editTheater.replaceFirst(':id', theater.theaterId)).then((_) => onRefresh());
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      _IconMenuBtn(
                        theater: theater,
                        onRefresh: onRefresh,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderBanner() {
    return Container(
      color: AdminColors.surfaceElevated,
      child: const Center(
        child: Icon(Icons.theaters_rounded,
            size: 40, color: AdminColors.textMuted),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(ShowSnapRadius.sm),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _IconMenuBtn extends ConsumerWidget {
  final TheaterModel theater;
  final VoidCallback onRefresh;

  const _IconMenuBtn({required this.theater, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      color: AdminColors.surfaceElevated,
      icon: const Icon(Icons.more_vert_rounded,
          color: AdminColors.textSecondary, size: 18),
      onSelected: (action) => _handleAction(context, ref, action),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: theater.isActive ? 'deactivate' : 'activate',
          child: Text(
            theater.isActive ? 'Deactivate' : 'Activate',
            style: TextStyle(
              color: theater.isActive
                  ? AdminColors.error
                  : AdminColors.success,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleAction(
      BuildContext context, WidgetRef ref, String action) async {
    if (action == 'deactivate') {
      final ok = await StaffConfirmDialog.show(
        context,
        title: 'Deactivate Theater',
        message:
            'All shows for "${theater.name}" will be hidden from users. Existing bookings are unaffected.',
        confirmLabel: 'Deactivate',
        isDangerous: true,
      );
      if (ok != true) return;
    }

    try {
      await ref.read(databaseServiceProvider).updateTheater(
        theater.theaterId,
        {'isActive': action == 'activate'},
      );
      onRefresh();
      if (context.mounted) {
        ShowSnapToast.success(
          context,
          action == 'activate'
              ? '${theater.name} activated'
              : '${theater.name} deactivated',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ShowSnapToast.error(context, 'Failed: $e');
      }
    }
  }
}
