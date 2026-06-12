import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/screen_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';

final _tmScreensProvider = FutureProvider<List<ScreenModel>>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return [];
  final theaters = await ref.watch(databaseServiceProvider).getAllTheaters();
  final theater =
      theaters.cast<dynamic>().firstWhere((t) => t.managerId == uid, orElse: () => null);
  if (theater == null) return [];
  return ref.watch(databaseServiceProvider).getScreensForTheater(theater.theaterId);
});

class ScreenManagerScreen extends ConsumerWidget {
  const ScreenManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screensAsync = ref.watch(_tmScreensProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Screens'),
        toolbarHeight: 70,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        flexibleSpace: Container(
          decoration:
              BoxDecoration(gradient: ShowSnapTheme.appBarGradient),
        ),
      ),
      body: screensAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (screens) => screens.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.theaters_outlined,
                        size: 80, color: ShowSnapColors.grey300),
                    const SizedBox(height: 16),
                    const Text('No screens yet'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          _showAddScreenDialog(context, ref),
                      child: const Text('Add Screen'),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms),
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(_tmScreensProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 16),
                  itemCount: screens.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _ScreenCard(screen: screens[i])
                        .animate()
                        .fadeIn(duration: 400.ms, delay: (i * 80).ms)
                        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddScreenDialog(context, ref),
        label: const Text('Add Screen'),
        icon: const Icon(Icons.add),
        backgroundColor: ShowSnapColors.primary,
      ).animate().scale(delay: 300.ms, duration: 400.ms, curve: Curves.elasticOut),
    );
  }

  void _showAddScreenDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final seatsCtrl = TextEditingController();
    String technology = '2D';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add Screen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration:
                    const InputDecoration(labelText: 'Screen Name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: technology,
                decoration:
                    const InputDecoration(labelText: 'Technology'),
                items: ['2D', '3D', 'IMAX', '4DX']
                    .map((t) =>
                        DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setS(() => technology = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: seatsCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Total Seats'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;
                final uid =
                    ref.read(authStateProvider).valueOrNull?.uid;
                if (uid == null) return;
                final db = ref.read(databaseServiceProvider);
                final theaters = await db.getAllTheaters();
                final theater = theaters.cast<dynamic>().firstWhere(
                    (t) => t.managerId == uid,
                    orElse: () => null);
                if (theater == null) return;

                await db.createScreen(ScreenModel(
                  screenId: '',
                  theaterId: theater.theaterId,
                  name: nameCtrl.text.trim(),
                  technology: technology,
                  totalSeats: int.tryParse(seatsCtrl.text) ?? 0,
                ));
                ref.invalidate(_tmScreensProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreenCard extends StatelessWidget {
  final ScreenModel screen;
  const _ScreenCard({required this.screen});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.theaters_outlined,
                    color: ShowSnapColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(screen.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                if (screen.isUnderMaintenance)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ShowSnapColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: ShowSnapColors.error),
                    ),
                    child: const Text('Maintenance',
                        style: TextStyle(
                            color: ShowSnapColors.error, fontSize: 11)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Chip(screen.technology),
                const SizedBox(width: 8),
                _Chip('${screen.totalSeats} seats'),
                const SizedBox(width: 8),
                _Chip('${screen.seatLayout.length} configured'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.grid_on_outlined, size: 16),
                    label: const Text('Edit Layout'),
                    onPressed: () => context
                        .push('/tm/seat-layout/${screen.screenId}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.schedule_outlined, size: 16),
                    label: const Text('Shows'),
                    onPressed: () =>
                        context.push('/tm/shows'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ShowSnapColors.grey100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ShowSnapColors.grey300),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}
