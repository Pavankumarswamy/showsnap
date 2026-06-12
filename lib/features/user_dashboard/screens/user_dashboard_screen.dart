import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/models/ad_request_model.dart';
import '../../../core/widgets/showsnap_toast.dart';
import '../../../core/config/router.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/database_service.dart';
import '../../../core/widgets/skeleton_widgets.dart';
import '../../../core/widgets/tappable_scale.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _wishlistProvider = StreamProvider.autoDispose<Map<String, String>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value({});
  return ref.watch(databaseServiceProvider).streamWishlist(uid);
});

final _notifPrefsProvider = StreamProvider.autoDispose<Map<String, bool>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value({});
  return ref.watch(databaseServiceProvider).streamNotifPrefs(uid);
});

final _userAdRequestsStreamProvider =
    StreamProvider.autoDispose<List<AdRequestModel>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(databaseServiceProvider).streamUserAdRequests(uid);
});

final _dashboardDataProvider = FutureProvider<_DashData>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return _DashData.empty();
  final db = ref.watch(databaseServiceProvider);
  final bookings = await db.getUserBookings(uid);
  final user = await db.getAllUsers();
  final u = user.cast<UserModel?>().firstWhere(
      (u) => u?.uid == uid, orElse: () => null);
  return _DashData(user: u, bookings: bookings);
});

class _DashData {
  final UserModel? user;
  final List<BookingModel> bookings;
  const _DashData({this.user, required this.bookings});
  factory _DashData.empty() => const _DashData(bookings: []);
}

// ─── Main Screen ──────────────────────────────────────────────────────────────

class UserDashboardScreen extends ConsumerStatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  ConsumerState<UserDashboardScreen> createState() =>
      _UserDashboardScreenState();
}

class _UserDashboardScreenState extends ConsumerState<UserDashboardScreen> {
  late ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(
        duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(_dashboardDataProvider);

    return Scaffold(
      body: Stack(
        children: [
          dataAsync.when(
            loading: () => _buildSkeleton(),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (data) => _buildContent(data),
          ),
          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              colors: const [
                ShowSnapColors.primary,
                ShowSnapColors.secondary,
                Colors.white,
              ],
              numberOfParticles: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: const [
          SizedBox(height: 200),
          SkeletonStatCard(),
          SizedBox(height: 12),
          SkeletonChartArea(),
          SizedBox(height: 12),
          SkeletonBookingItem(),
        ],
      ),
    );
  }

  Widget _buildContent(_DashData data) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
            child: _ProfileHeader(
          user: data.user,
          bookingCount: data.bookings.length,
          onRefresh: () => ref.refresh(_dashboardDataProvider),
        )),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _StatsGrid(bookings: data.bookings),
              const SizedBox(height: 20),
              _BookingChart(bookings: data.bookings),
              const SizedBox(height: 20),
              _GenreRadar(bookings: data.bookings),
              const SizedBox(height: 20),
              _RewardsSection(user: data.user),
              const SizedBox(height: 20),
              _WishlistSection(),
              const SizedBox(height: 20),
              _InfluencerHubSection(),
              const SizedBox(height: 20),
              _RecentBookings(bookings: data.bookings.take(5).toList()),
              const SizedBox(height: 20),
              _SettingsSection(),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ],
    );
  }
}

// ─── Profile Header ───────────────────────────────────────────────────────────

class _ProfileHeader extends ConsumerStatefulWidget {
  final UserModel? user;
  final int bookingCount;
  final VoidCallback onRefresh;

  const _ProfileHeader(
      {required this.user,
      required this.bookingCount,
      required this.onRefresh});

  @override
  ConsumerState<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends ConsumerState<_ProfileHeader> {
  bool _uploading = false;

  String _levelLabel(int count) {
    if (count >= 30) return '🎬 Platinum';
    if (count >= 16) return '🥇 Gold';
    if (count >= 5) return '🥈 Silver';
    return '🥉 Bronze';
  }

  Future<void> _changeAvatar() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (img == null) return;
    setState(() => _uploading = true);
    try {
      final url = await ref.read(cloudinaryServiceProvider).uploadImage(
          File(img.path), AppConstants.cloudinaryAvatars);
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid != null) {
        await ref.read(databaseServiceProvider).updateUser(uid, {'avatarUrl': url});
        widget.onRefresh();
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [ShowSnapColors.primary, ShowSnapColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(ShowSnapRadius.md),
          bottomRight: Radius.circular(ShowSnapRadius.md),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              TappableScale(
                onTap: _changeAvatar,
                child: Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white, width: 3),
                        color: ShowSnapColors.grey300,
                      ),
                      child: ClipOval(
                        child: user?.avatarUrl.isNotEmpty == true
                            ? CachedNetworkImage(
                                imageUrl: user!.avatarUrl,
                                fit: BoxFit.cover)
                            : const Icon(Icons.person,
                                size: 40, color: Colors.white),
                      ),
                    )
                        .animate()
                        .scale(
                          begin: const Offset(0, 0),
                          end: const Offset(1, 1),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.elasticOut,
                        ),
                    if (_uploading)
                      const Positioned.fill(
                        child: Center(
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 14, color: ShowSnapColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? 'User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius:
                            BorderRadius.circular(ShowSnapRadius.pill),
                      ),
                      child: Text(
                        _levelLabel(widget.bookingCount),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              // Edit button
              IconButton(
                onPressed: () => _showEditProfile(context),
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Stats strip
          Row(
            children: [
              _MiniStat('${widget.bookingCount}', 'Bookings'),
              _vertDivider(),
              _MiniStat(
                  '${user?.rewards.length ?? 0}', 'Rewards'),
              _vertDivider(),
              _MiniStat(
                '2',
                'Cities',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vertDivider() => Container(
        width: 1,
        height: 32,
        color: Colors.white38,
        margin: const EdgeInsets.symmetric(horizontal: 16),
      );

  void _showEditProfile(BuildContext context) {
    final user = widget.user;
    final nameCtrl =
        TextEditingController(text: user?.displayName ?? '');
    final cityCtrl = TextEditingController(text: user?.city ?? '');
    final phoneCtrl = TextEditingController(text: user?.phone ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(ShowSnapRadius.lg)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Edit Profile',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              TextFormField(
                  controller: cityCtrl,
                  decoration:
                      const InputDecoration(labelText: 'City')),
              const SizedBox(height: 12),
              TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final uid =
                      ref.read(authStateProvider).valueOrNull?.uid;
                  if (uid == null) return;
                  await ref.read(databaseServiceProvider).updateUser(uid, {
                    'displayName': nameCtrl.text.trim(),
                    'city': cityCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                  });
                  widget.onRefresh();
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                },
                child: const Text('Save Changes'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  const _MiniStat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20)),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─── Stats Grid ───────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final List<BookingModel> bookings;
  const _StatsGrid({required this.bookings});

  @override
  Widget build(BuildContext context) {
    final confirmed = bookings
        .where((b) =>
            b.status == BookingStatus.confirmed ||
            b.status == BookingStatus.redeemed)
        .toList();
    final totalSpent = confirmed.fold(0, (s, b) => s + b.totalAmount);
    final uniqueMovies = confirmed.map((b) => b.movieId).toSet().length;

    final stats = [
      _StatInfo('Total Spent', '₹$totalSpent', Icons.currency_rupee, ShowSnapColors.primary),
      _StatInfo('Movies', '$uniqueMovies', Icons.movie_outlined, ShowSnapColors.secondary),
      _StatInfo('Bookings', '${confirmed.length}', Icons.confirmation_number_outlined, Colors.purple),
      _StatInfo('Genres', '5', Icons.category_outlined, Colors.orange),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: stats.asMap().entries.map((e) {
        return _StatCard(info: e.value, index: e.key);
      }).toList(),
    );
  }
}

class _StatInfo {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatInfo(this.label, this.value, this.icon, this.color);
}

class _StatCard extends StatelessWidget {
  final _StatInfo info;
  final int index;
  const _StatCard({required this.info, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        boxShadow: ShowSnapShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: info.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(info.icon, color: info.color, size: 20),
          ),
          const Spacer(),
          Text(
            info.value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: info.color,
            ),
          )
              .animate()
              .custom(
                duration: const Duration(milliseconds: 1200),
                delay: Duration(milliseconds: index * 100),
                curve: Curves.easeOutExpo,
                builder: (_, v, child) {
                  // Extract numeric value and animate count-up
                  final raw = info.value.replaceAll(RegExp(r'[^\d]'), '');
                  final numVal = int.tryParse(raw) ?? 0;
                  final displayed = (numVal * v).toInt();
                  final prefix = info.value.startsWith('₹') ? '₹' : '';
                  return Text(
                    '$prefix$displayed',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: info.color,
                    ),
                  );
                },
              ),
          Text(
            info.label,
            style: const TextStyle(
                fontSize: 11, color: ShowSnapColors.grey600),
          ),
        ],
      ),
    );
  }
}

// ─── Booking Activity Chart ───────────────────────────────────────────────────

class _BookingChart extends StatelessWidget {
  final List<BookingModel> bookings;
  const _BookingChart({required this.bookings});

  @override
  Widget build(BuildContext context) {
    // Group bookings by month (last 6 months)
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final dt = DateTime(now.year, now.month - (5 - i));
      return dt;
    });

    final counts = months.map((m) {
      return bookings
          .where((b) {
            final dt = DateTime.fromMillisecondsSinceEpoch(b.createdAt);
            return dt.year == m.year && dt.month == m.month;
          })
          .length
          .toDouble();
    }).toList();

    final bars = counts.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value,
            width: 18,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(ShowSnapRadius.xs)),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFE65100),
                ShowSnapColors.primary,
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
        ],
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        boxShadow: ShowSnapShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Booking Activity',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Last 6 months',
              style: TextStyle(
                  fontSize: 12, color: ShowSnapColors.grey600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (counts.reduce((a, b) => a > b ? a : b) + 2)
                    .clamp(5, double.infinity),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: Color(0xFFF0F0F0),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat('MMM')
                              .format(months[v.toInt()]),
                          style: const TextStyle(
                              fontSize: 10,
                              color: ShowSnapColors.grey600),
                        ),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: const TextStyle(
                            fontSize: 10,
                            color: ShowSnapColors.grey600),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                barGroups: bars,
              ),
              swapAnimationDuration:
                  const Duration(milliseconds: 800),
              swapAnimationCurve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Genre Radar ──────────────────────────────────────────────────────────────

class _GenreRadar extends StatelessWidget {
  final List<BookingModel> bookings;
  const _GenreRadar({required this.bookings});

  @override
  Widget build(BuildContext context) {
    final confirmed = bookings
        .where((b) =>
            b.status == BookingStatus.confirmed ||
            b.status == BookingStatus.redeemed)
        .length;

    if (confirmed < 3) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          boxShadow: ShowSnapShadow.card,
        ),
        child: Column(
          children: [
            const Icon(Icons.radar_outlined,
                size: 60, color: ShowSnapColors.grey300),
            const SizedBox(height: 12),
            const Text('Your Taste Profile',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text(
              'Book more movies to unlock your taste profile!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: ShowSnapColors.grey600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Explore Movies'),
            ),
          ],
        ),
      );
    }

    // Build radar with hardcoded genre data (in a real app this comes from booking genre lookup)
    const genres = ['Action', 'Drama', 'Comedy', 'Thriller', 'Romance', 'Sci-Fi'];
    final values = [4.0, 3.0, 2.5, 3.5, 1.5, 2.0];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        boxShadow: ShowSnapShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Taste Profile',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: RadarChart(
              RadarChartData(
                radarShape: RadarShape.polygon,
                ticksTextStyle:
                    const TextStyle(fontSize: 8, color: Colors.transparent),
                gridBorderData: const BorderSide(
                    color: ShowSnapColors.grey300, width: 1),
                titlePositionPercentageOffset: 0.2,
                titleTextStyle: const TextStyle(
                    fontSize: 10, color: ShowSnapColors.grey600),
                getTitle: (i, _) =>
                    RadarChartTitle(text: genres[i % genres.length]),
                dataSets: [
                  RadarDataSet(
                    fillColor:
                        ShowSnapColors.primary.withOpacity(0.4),
                    borderColor: ShowSnapColors.primary,
                    borderWidth: 2,
                    entryRadius: 4,
                    dataEntries: values
                        .map((v) => RadarEntry(value: v))
                        .toList(),
                  ),
                ],
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                tickCount: 5,
              ),
              swapAnimationDuration:
                  const Duration(milliseconds: 1000),
              swapAnimationCurve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Rewards Section ──────────────────────────────────────────────────────────

class _RewardsSection extends StatelessWidget {
  final UserModel? user;
  const _RewardsSection({this.user});

  @override
  Widget build(BuildContext context) {
    final bookingCount = 0; // simplified
    final nextMilestone = 9;
    final progress = (bookingCount / nextMilestone).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        boxShadow: ShowSnapShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Rewards',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Tap a reward to apply at checkout',
              style: TextStyle(
                  fontSize: 12, color: ShowSnapColors.grey600)),
          const SizedBox(height: 16),
          // Milestone progress
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined,
                  color: ShowSnapColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Book ${nextMilestone - bookingCount} more for a free ticket!',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Stack(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: ShowSnapColors.grey300,
                              borderRadius: BorderRadius.circular(
                                  ShowSnapRadius.pill),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: v,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    ShowSnapColors.primary,
                                    ShowSnapColors.primaryLight,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                    ShowSnapRadius.pill),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$bookingCount/$nextMilestone movies',
                      style: const TextStyle(
                          fontSize: 11,
                          color: ShowSnapColors.grey600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Recent Bookings ──────────────────────────────────────────────────────────

class _RecentBookings extends StatelessWidget {
  final List<BookingModel> bookings;
  const _RecentBookings({required this.bookings});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Recent Bookings',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            TextButton(
              onPressed: () => context.push(AppRoutes.myBookings),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (bookings.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(ShowSnapRadius.md),
              boxShadow: ShowSnapShadow.card,
            ),
            child: const Center(
              child: Text('No bookings yet',
                  style: TextStyle(color: ShowSnapColors.grey600)),
            ),
          )
        else
          AnimationLimiter(
            child: Column(
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 375),
                childAnimationBuilder: (widget) => SlideAnimation(
                  verticalOffset: 20,
                  child: FadeInAnimation(child: widget),
                ),
                children: bookings.map((b) => _BookingRow(booking: b)).toList(),
              ),
            ),
          ),
      ],
    );
  }
}

class _BookingRow extends StatelessWidget {
  final BookingModel booking;
  const _BookingRow({required this.booking});

  @override
  Widget build(BuildContext context) {
    final isConfirmed = booking.status == BookingStatus.confirmed ||
        booking.status == BookingStatus.redeemed;
    final statusColor = booking.status == BookingStatus.cancelled
        ? ShowSnapColors.error
        : booking.status == BookingStatus.redeemed
            ? ShowSnapColors.grey600
            : ShowSnapColors.secondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        boxShadow: ShowSnapShadow.card,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 58,
            decoration: BoxDecoration(
              color: ShowSnapColors.grey100,
              borderRadius: BorderRadius.circular(ShowSnapRadius.xs),
            ),
            child: const Icon(Icons.movie_outlined,
                color: ShowSnapColors.grey600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.movieTitle,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  '${booking.theaterName} • ${booking.createdAt.epochToDateLabel}',
                  style: const TextStyle(
                      fontSize: 11, color: ShowSnapColors.grey600),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius:
                        BorderRadius.circular(ShowSnapRadius.pill),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    booking.status.label,
                    style: TextStyle(
                        fontSize: 10,
                        color: statusColor,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          if (isConfirmed)
            TappableScale(
              onTap: () => context
                  .push('/ticket/${booking.bookingId}'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ShowSnapColors.primaryLighter,
                  borderRadius:
                      BorderRadius.circular(ShowSnapRadius.pill),
                ),
                child: const Text('View',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Settings Section ─────────────────────────────────────────────────────────

class _SettingsSection extends ConsumerWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = [
      _SettRow(Icons.notifications_outlined, 'Notification Preferences',
          () => _NotifPrefsSheet.show(context)),
      _SettRow(Icons.location_on_outlined, 'City & Location', () {}),
      _SettRow(Icons.movie_filter_outlined, 'Genre Preferences',
          () => context.push(AppRoutes.profileSetup)),
      _SettRow(Icons.lock_outlined, 'Change Password', () {}),
      _SettRow(Icons.description_outlined, 'Terms & Privacy', () {}),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        boxShadow: ShowSnapShadow.card,
      ),
      child: Column(
        children: [
          ...rows.map((r) => _SettingsRow(row: r)),
          _SettingsRow(
            row: _SettRow(Icons.logout_rounded, 'Sign Out', () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dlgCtx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(dlgCtx).pop(false),
                        child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: ShowSnapColors.error),
                      onPressed: () => Navigator.of(dlgCtx).pop(true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) context.go(AppRoutes.login);
              }
            }),
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}

class _SettRow {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SettRow(this.icon, this.label, this.onTap);
}

// ─── Wishlist Section ─────────────────────────────────────────────────────────

class _WishlistSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistAsync = ref.watch(_wishlistProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('My Wishlist',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
              onPressed: () => context.go('/explore'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        wishlistAsync.when(
          loading: () => const Center(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator())),
          error: (e, _) =>
              Text('Error: $e', style: const TextStyle(color: Colors.red)),
          data: (wishlist) {
            if (wishlist.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                  boxShadow: ShowSnapShadow.card,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_border_rounded,
                        color: ShowSnapColors.grey300),
                    SizedBox(width: 8),
                    Text('Nothing in your wishlist yet',
                        style: TextStyle(color: ShowSnapColors.grey600)),
                  ],
                ),
              );
            }
            final uid =
                ref.read(authStateProvider).valueOrNull?.uid ?? '';
            return Column(
              children: wishlist.entries.map((entry) {
                return Slidable(
                  key: ValueKey(entry.key),
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (_) async {
                          await ref
                              .read(databaseServiceProvider)
                              .removeFromWishlist(uid, entry.key);
                          if (context.mounted) ShowSnapToast.show(context, message: 'Removed from wishlist');
                        },
                        backgroundColor: ShowSnapColors.error,
                        foregroundColor: Colors.white,
                        icon: Icons.delete_rounded,
                        label: 'Remove',
                        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                      ),
                    ],
                  ),
                  child: GestureDetector(
                    onTap: () {
                      if (entry.value == 'movie') {
                        context.push('/movie/${entry.key}');
                      } else if (entry.value == 'event') {
                        context.push('/event/${entry.key}');
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(ShowSnapRadius.md),
                        boxShadow: ShowSnapShadow.card,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            entry.value == 'movie'
                                ? Icons.movie_outlined
                                : Icons.event_outlined,
                            color: ShowSnapColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(entry.key,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                          const Icon(Icons.favorite_rounded,
                              color: Colors.red, size: 18),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right,
                              color: ShowSnapColors.grey600),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

// ─── Influencer Hub Section ───────────────────────────────────────────────────

class _InfluencerHubSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adRequestsAsync = ref.watch(_userAdRequestsStreamProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        boxShadow: ShowSnapShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_rounded, color: Colors.deepPurple),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Influencer Hub',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              TextButton(
                onPressed: () => context.push('/influencer/ad-request'),
                child: const Text('New Request',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Advertise your brand at ShowSnap theaters',
              style:
                  TextStyle(fontSize: 12, color: ShowSnapColors.grey600)),
          const SizedBox(height: 14),
          adRequestsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Text('Error: $e', style: const TextStyle(color: Colors.red)),
            data: (requests) {
              if (requests.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ShowSnapColors.grey100,
                    borderRadius: BorderRadius.circular(ShowSnapRadius.sm),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add_circle_outline,
                          color: ShowSnapColors.grey600),
                      SizedBox(width: 8),
                      Text('No ad requests yet',
                          style:
                              TextStyle(color: ShowSnapColors.grey600)),
                    ],
                  ),
                );
              }
              return Column(
                children: requests.take(3).map((req) {
                  final statusColor = req.status == AdRequestStatus.approved
                      ? ShowSnapColors.secondary
                      : req.status == AdRequestStatus.rejected
                          ? ShowSnapColors.error
                          : ShowSnapColors.primary;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ShowSnapColors.grey100,
                      borderRadius:
                          BorderRadius.circular(ShowSnapRadius.sm),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(req.campaignTitle,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(req.brandName,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: ShowSnapColors.grey600)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius:
                                BorderRadius.circular(ShowSnapRadius.pill),
                            border: Border.all(
                                color: statusColor.withOpacity(0.5)),
                          ),
                          child: Text(
                            req.status.name.toUpperCase(),
                            style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Notification Preferences Sheet ──────────────────────────────────────────

class _NotifPrefsSheet extends ConsumerWidget {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(ShowSnapRadius.lg))),
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: _NotifPrefsSheet(),
      ),
    );
  }

  static const _prefs = [
    ('bookingUpdates', 'Booking Updates', Icons.confirmation_number_rounded),
    ('newMovies', 'New Movies', Icons.movie_rounded),
    ('offers', 'Offers & Coupons', Icons.local_offer_rounded),
    ('eventReminders', 'Event Reminders', Icons.event_rounded),
    ('adRequests', 'Ad Request Updates', Icons.campaign_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(_notifPrefsProvider);
    final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: ShowSnapColors.grey300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Notification Preferences',
              style:
                  TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 4),
          const Text('Choose what you\'d like to be notified about',
              style: TextStyle(
                  color: ShowSnapColors.grey600, fontSize: 12)),
          const SizedBox(height: 16),
          prefsAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
            data: (prefs) => Column(
              children: _prefs.map((p) {
                final key = p.$1;
                final label = p.$2;
                final icon = p.$3;
                final enabled = prefs[key] ?? true;
                return SwitchListTile(
                  secondary: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: ShowSnapColors.primaryLighter,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        Icon(icon, size: 18, color: ShowSnapColors.primary),
                  ),
                  title: Text(label,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  value: enabled,
                  activeColor: ShowSnapColors.primary,
                  onChanged: uid.isEmpty
                      ? null
                      : (v) => ref
                          .read(databaseServiceProvider)
                          .updateNotifPref(uid, key, v),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final _SettRow row;
  final bool isDestructive;
  const _SettingsRow({required this.row, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? ShowSnapColors.error : ShowSnapColors.onSurface;
    return TappableScale(
      onTap: row.onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: ShowSnapColors.grey100)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDestructive
                    ? ShowSnapColors.error.withOpacity(0.1)
                    : ShowSnapColors.primaryLighter,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(row.icon,
                  size: 18,
                  color: isDestructive
                      ? ShowSnapColors.error
                      : ShowSnapColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(row.label,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.chevron_right, color: ShowSnapColors.grey600),
          ],
        ),
      ),
    );
  }
}
