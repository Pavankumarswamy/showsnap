import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/router.dart';
import '../../../core/config/staff_theme.dart';
import '../../../core/config/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/showsnap_toast.dart';

final _allUsersProvider = FutureProvider<List<UserModel>>((ref) {
  return ref.watch(databaseServiceProvider).getAllUsers();
});

final _userRoleFilterProvider = StateProvider<String?>((ref) => null);
final _userSearchProvider = StateProvider<String>((ref) => '');

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(_allUsersProvider);
    final roleFilter = ref.watch(_userRoleFilterProvider);
    final search = ref.watch(_userSearchProvider);

    return Scaffold(
      backgroundColor: AdminColors.background,
      drawer: AdminDrawer(
        currentRoute: AppRoutes.userManagement,
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
          'User Management',
          style: TextStyle(
              color: AdminColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Search + filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                StaffSearchBar(
                  hint: 'Search by name or email',
                  onChanged: (v) =>
                      ref.read(_userSearchProvider.notifier).state = v,
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _RoleChip(
                        label: 'All',
                        value: null,
                        selected: roleFilter,
                        ref: ref,
                      ),
                      const SizedBox(width: 8),
                      _RoleChip(
                        label: 'Users',
                        value: AppConstants.roleUser,
                        selected: roleFilter,
                        ref: ref,
                      ),
                      const SizedBox(width: 8),
                      _RoleChip(
                        label: 'Theater Managers',
                        value: AppConstants.roleTheaterManager,
                        selected: roleFilter,
                        ref: ref,
                        color: AdminColors.warning,
                      ),
                      const SizedBox(width: 8),
                      _RoleChip(
                        label: 'Event Managers',
                        value: AppConstants.roleEventManager,
                        selected: roleFilter,
                        ref: ref,
                        color: AdminColors.success,
                      ),
                      const SizedBox(width: 8),
                      _RoleChip(
                        label: 'Admins',
                        value: AppConstants.roleAdmin,
                        selected: roleFilter,
                        ref: ref,
                        color: AdminColors.error,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),
          // List
          Expanded(
            child: usersAsync.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 6,
                itemBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: StaffShimmerCard(
                    height: 72,
                    baseColor: AdminColors.surface,
                    highlightColor: AdminColors.surfaceElevated,
                  ),
                ),
              ),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: const TextStyle(color: AdminColors.error)),
              ),
              data: (users) {
                var filtered = users;
                if (roleFilter != null) {
                  filtered =
                      filtered.where((u) => u.role == roleFilter).toList();
                }
                if (search.isNotEmpty) {
                  final q = search.toLowerCase();
                  filtered = filtered
                      .where((u) =>
                          u.displayName.toLowerCase().contains(q) ||
                          u.email.toLowerCase().contains(q))
                      .toList();
                }

                if (filtered.isEmpty) {
                  return StaffEmptyState(
                    icon: Icons.people_outline,
                    message: users.isEmpty
                        ? 'No users registered yet'
                        : 'No users match your search',
                  );
                }

                return RefreshIndicator(
                  color: AdminColors.primary,
                  backgroundColor: AdminColors.surface,
                  onRefresh: () => ref.refresh(_allUsersProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _UserTile(user: filtered[i])
                        .animate()
                        .fadeIn(
                            duration: 350.ms, delay: (i % 8 * 40).ms)
                        .slideY(begin: 0.08, end: 0),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final String? value;
  final String? selected;
  final WidgetRef ref;
  final Color color;

  const _RoleChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.ref,
    this.color = AdminColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () =>
          ref.read(_userRoleFilterProvider.notifier).state = value,
      child: AnimatedContainer(
        duration: 150.ms,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : AdminColors.surface,
          borderRadius: BorderRadius.circular(ShowSnapRadius.pill),
          border: Border.all(
            color: isSelected ? color : AdminColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                isSelected ? Colors.black : AdminColors.textSecondary,
            fontWeight:
                isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _UserTile extends ConsumerWidget {
  final UserModel user;
  const _UserTile({required this.user});

  Color _roleColor() {
    switch (user.role) {
      case AppConstants.roleAdmin:
        return AdminColors.error;
      case AppConstants.roleTheaterManager:
        return AdminColors.warning;
      case AppConstants.roleEventManager:
        return AdminColors.success;
      default:
        return AdminColors.info;
    }
  }

  String _roleLabel() {
    switch (user.role) {
      case AppConstants.roleAdmin:
        return 'Admin';
      case AppConstants.roleTheaterManager:
        return 'TM';
      case AppConstants.roleEventManager:
        return 'EM';
      default:
        return 'User';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleColor = _roleColor();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: roleColor.withOpacity(0.15),
            backgroundImage: user.avatarUrl.isNotEmpty
                ? NetworkImage(user.avatarUrl)
                : null,
            child: user.avatarUrl.isEmpty
                ? Text(
                    user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: roleColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName.isNotEmpty
                      ? user.displayName
                      : 'Unknown',
                  style: const TextStyle(
                      color: AdminColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  user.email,
                  style: const TextStyle(
                      color: AdminColors.textSecondary, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StaffBadge(label: _roleLabel(), color: roleColor),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            color: AdminColors.surfaceElevated,
            icon: const Icon(Icons.more_vert_rounded,
                color: AdminColors.textSecondary, size: 20),
            onSelected: (action) =>
                _handleAction(context, ref, action),
            itemBuilder: (_) => [
              if (user.role != AppConstants.roleAdmin)
                const PopupMenuItem(
                  value: 'makeAdmin',
                  child: Text('Make Admin',
                      style: TextStyle(color: AdminColors.textPrimary)),
                ),
              if (user.role != AppConstants.roleTheaterManager)
                const PopupMenuItem(
                  value: 'makeTM',
                  child: Text('Make Theater Manager',
                      style: TextStyle(color: AdminColors.textPrimary)),
                ),
              if (user.role != AppConstants.roleEventManager)
                const PopupMenuItem(
                  value: 'makeEM',
                  child: Text('Make Event Manager',
                      style: TextStyle(color: AdminColors.textPrimary)),
                ),
              if (user.role != AppConstants.roleUser)
                const PopupMenuItem(
                  value: 'makeUser',
                  child: Text('Make User',
                      style: TextStyle(color: AdminColors.textPrimary)),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: user.isActive ? 'deactivate' : 'activate',
                child: Text(
                  user.isActive ? 'Deactivate' : 'Activate',
                  style: TextStyle(
                    color: user.isActive
                        ? AdminColors.error
                        : AdminColors.success,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(
      BuildContext context, WidgetRef ref, String action) async {
    if (action == 'deactivate') {
      final ok = await StaffConfirmDialog.show(
        context,
        title: 'Deactivate User',
        message:
            'This will prevent ${user.displayName} from logging in. Proceed?',
        confirmLabel: 'Deactivate',
        isDangerous: true,
      );
      if (ok != true) return;
    }

    final db = ref.read(databaseServiceProvider);
    try {
      switch (action) {
        case 'makeAdmin':
          await db.updateUser(user.uid, {'role': AppConstants.roleAdmin});
          break;
        case 'makeTM':
          await db.updateUser(
              user.uid, {'role': AppConstants.roleTheaterManager});
          break;
        case 'makeEM':
          await db.updateUser(
              user.uid, {'role': AppConstants.roleEventManager});
          break;
        case 'makeUser':
          await db.updateUser(user.uid, {'role': AppConstants.roleUser});
          break;
        case 'deactivate':
          await db.updateUser(user.uid, {'isActive': false});
          break;
        case 'activate':
          await db.updateUser(user.uid, {'isActive': true});
          break;
      }
      ref.invalidate(_allUsersProvider);
      if (context.mounted) {
        ShowSnapToast.success(context, 'Updated successfully');
      }
    } catch (e) {
      if (context.mounted) {
        ShowSnapToast.error(context, 'Failed: $e');
      }
    }
  }
}
