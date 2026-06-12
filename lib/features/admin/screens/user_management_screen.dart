import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/extensions.dart';

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
      appBar: AppBar(
        title: const Text('User Management'),
        flexibleSpace: Container(
          decoration:
              BoxDecoration(gradient: ShowSnapTheme.appBarGradient),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by name or email',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) =>
                      ref.read(_userSearchProvider.notifier).state = v,
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip('All', null, roleFilter, ref),
                      const SizedBox(width: 8),
                      _FilterChip('Users', AppConstants.roleUser,
                          roleFilter, ref),
                      const SizedBox(width: 8),
                      _FilterChip('Managers',
                          AppConstants.roleTheaterManager, roleFilter, ref),
                      const SizedBox(width: 8),
                      _FilterChip('Admins', AppConstants.roleAdmin,
                          roleFilter, ref),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: usersAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
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
                  return const Center(child: Text('No users found'));
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(_allUsersProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 4),
                    itemBuilder: (_, i) =>
                        _UserTile(user: filtered[i]),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final String? value;
  final String? selected;
  final WidgetRef ref;

  const _FilterChip(this.label, this.value, this.selected, this.ref);

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () =>
          ref.read(_userRoleFilterProvider.notifier).state = value,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? ShowSnapColors.primary : ShowSnapColors.grey100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? ShowSnapColors.primary : ShowSnapColors.grey300,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              color: isSelected ? Colors.black : ShowSnapColors.grey600,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            )),
      ),
    );
  }
}

class _UserTile extends ConsumerWidget {
  final UserModel user;
  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color roleColor;
    switch (user.role) {
      case AppConstants.roleAdmin:
        roleColor = ShowSnapColors.error;
        break;
      case AppConstants.roleTheaterManager:
        roleColor = ShowSnapColors.secondary;
        break;
      default:
        roleColor = ShowSnapColors.primary;
    }

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: roleColor.withOpacity(0.1),
          backgroundImage: user.avatarUrl.isNotEmpty
              ? NetworkImage(user.avatarUrl)
              : null,
          child: user.avatarUrl.isEmpty
              ? Text(
                  user.displayName.isNotEmpty
                      ? user.displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      color: roleColor, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        title: Text(user.displayName.isNotEmpty ? user.displayName : 'Unknown'),
        subtitle: Text(user.email,
            style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: roleColor),
              ),
              child: Text(
                user.role.capitalize,
                style: TextStyle(
                    color: roleColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (action) =>
                  _handleAction(context, ref, action),
              itemBuilder: (_) => [
                if (user.role != AppConstants.roleAdmin)
                  const PopupMenuItem(
                      value: 'makeAdmin', child: Text('Make Admin')),
                if (user.role != AppConstants.roleTheaterManager)
                  const PopupMenuItem(
                      value: 'makeTM', child: Text('Make Theater Manager')),
                if (user.role != AppConstants.roleUser)
                  const PopupMenuItem(
                      value: 'makeUser', child: Text('Make User')),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: user.isActive ? 'deactivate' : 'activate',
                  child: Text(user.isActive ? 'Deactivate' : 'Activate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(
      BuildContext context, WidgetRef ref, String action) async {
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
        context.showSnackbar('Updated successfully');
      }
    } catch (e) {
      if (context.mounted) {
        context.showErrorSnackbar('Failed: $e');
      }
    }
  }
}
