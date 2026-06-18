import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/models/ad_request_model.dart';
import '../../../core/models/offer_model.dart';
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
import '../../../core/widgets/main_app_bar.dart';
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
  final u = await ref.watch(authServiceProvider).getCurrentUserModel();
  return _DashData(user: u, bookings: bookings);
});

class _DashData {
  final UserModel? user;
  final List<BookingModel> bookings;
  const _DashData({this.user, required this.bookings});
  factory _DashData.empty() => const _DashData(bookings: []);
}

final _offersProvider = FutureProvider.autoDispose<List<OfferModel>>((ref) {
  return ref.watch(databaseServiceProvider).getAllOffers();
});

// ─── Main Screen ──────────────────────────────────────────────────────────────

class UserDashboardScreen extends ConsumerStatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  ConsumerState<UserDashboardScreen> createState() =>
      _UserDashboardScreenState();
}

class _UserDashboardScreenState extends ConsumerState<UserDashboardScreen> {
  late ConfettiController _confetti;
  final ScrollController _scrollController = ScrollController();

  // Anchors for jumping to sections
  final GlobalKey _purchasesKey = GlobalKey();
  final GlobalKey _wishlistKey = GlobalKey();
  final GlobalKey _rewardsKey = GlobalKey();
  final GlobalKey _influencerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confetti.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: ShowSnapDuration.normal,
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(_dashboardDataProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121314), // Sleek cinema black/greyish background
      body: Stack(
        children: [
          dataAsync.when(
            loading: () => _buildSkeleton(),
            error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
            data: (data) => _buildContent(data),
          ),
          // Confetti Canvas
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              colors: const [
                ShowSnapColors.primary,
                ShowSnapColors.primaryLight,
                Colors.white,
                Colors.amber,
              ],
              numberOfParticles: 40,
              gravity: 0.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return Container(
      color: const Color(0xFF121314),
      child: SingleChildScrollView(
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
      ),
    );
  }

  Widget _buildContent(_DashData data) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: _ProfileHeader(
            user: data.user,
            bookingCount: data.bookings.length,
            onRefresh: () => ref.refresh(_dashboardDataProvider),
            onVipCardTap: () {
              _confetti.play();
              HapticFeedback.heavyImpact();
              ShowSnapToast.show(context,
                  message: '🎉 You are a ShowSnap VIP! Tap coupons to copy codes.');
            },
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([



              
              // Rewards & Milestone Section
              Container(
                key: _rewardsKey,
                child: _RewardsSection(
                  user: data.user,
                  bookingCount: data.bookings.length,
                  onCouponClaimed: () {
                    _confetti.play();
                    HapticFeedback.mediumImpact();
                  },
                ),
              ),
              
              const SizedBox(height: 24),
              

              
              // Purchases Section
              Container(
                key: _purchasesKey,
                child: _RecentBookings(bookings: data.bookings),
              ),
              
              const SizedBox(height: 24),
              
              _SettingsSection(),
              const SizedBox(height: 98),
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
  final VoidCallback onVipCardTap;

  const _ProfileHeader({
    required this.user,
    required this.bookingCount,
    required this.onRefresh,
    required this.onVipCardTap,
  });

  @override
  ConsumerState<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends ConsumerState<_ProfileHeader> with SingleTickerProviderStateMixin {
  bool _uploading = false;
  late AnimationController _cardFlipController;

  @override
  void initState() {
    super.initState();
    _cardFlipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _cardFlipController.dispose();
    super.dispose();
  }

  String _levelLabel(int count) {
    if (count >= 30) return 'Platinum Member';
    if (count >= 15) return 'Gold Member';
    if (count >= 5) return 'Silver Member';
    return 'Bronze Member';
  }

  Color _levelColor(int count) {
    if (count >= 30) return const Color(0xFFE5E4E2); // Platinum
    if (count >= 15) return const Color(0xFFFFD700); // Gold
    if (count >= 5) return const Color(0xFFC0C0C0); // Silver
    return const Color(0xFFCD7F32); // Bronze
  }

  Future<void> _changeAvatar() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await img.readAsBytes();
      final url = await ref.read(cloudinaryServiceProvider).uploadImageBytes(
          bytes, img.name, AppConstants.cloudinaryAvatars);
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid != null) {
        await ref.read(databaseServiceProvider).updateUser(uid, {'avatarUrl': url});
        widget.onRefresh();
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _triggerCardAnimation() {
    widget.onVipCardTap();
    if (_cardFlipController.isCompleted) {
      _cardFlipController.reverse();
    } else {
      _cardFlipController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final lvlLabel = _levelLabel(widget.bookingCount);
    final lvlColor = _levelColor(widget.bookingCount);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2022), // Carbon dark container background
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(35),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Interactive Avatar
              TappableScale(
                onTap: _changeAvatar,
                child: Stack(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: ShowSnapColors.primary, width: 2.5),
                        color: const Color(0xFF2C2F33),
                      ),
                      child: ClipOval(
                        child: user?.avatarUrl.isNotEmpty == true
                            ? CachedNetworkImage(
                                imageUrl: user!.avatarUrl,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.person_outline, size: 36, color: Colors.white54),
                      ),
                    ).animate().scale(curve: Curves.elasticOut, duration: 600.ms),
                    if (_uploading)
                      const Positioned.fill(
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: ShowSnapColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, size: 12, color: Colors.black87),
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
                      user?.displayName.isNotEmpty == true ? user!.displayName : 'Guest User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: lvlColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: lvlColor.withOpacity(0.5), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.stars_rounded, color: lvlColor, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                lvlLabel,
                                style: TextStyle(
                                  color: lvlColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                style: IconButton.styleFrom(backgroundColor: const Color(0xFF2C2F33)),
                onPressed: () => _showEditProfile(context),
                icon: const Icon(Icons.tune, color: ShowSnapColors.primary, size: 20),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // ShowSnap VIP Digital Pass Card (Floating & Tap Interactive)
          AnimatedBuilder(
            animation: _cardFlipController,
            builder: (context, child) {
              final val = _cardFlipController.value;
              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(val * 3.14159),
                alignment: Alignment.center,
                child: val >= 0.5
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(3.14159),
                        child: _buildVipCardBack(),
                      )
                    : _buildVipCardFront(lvlLabel),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVipCardFront(String level) {
    return TappableScale(
      onTap: _triggerCardAnimation,
      child: Container(
        height: 180,
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF1E2125), Color(0xFF0F1012)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: ShowSnapColors.primary.withOpacity(0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: ShowSnapColors.primary.withOpacity(0.1),
              blurRadius: 25,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.circle_outlined, color: ShowSnapColors.primary, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'SHOWSNAP VIP',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: ShowSnapColors.primary.withOpacity(0.85),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ShowSnapColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ACTIVE PASS',
                    style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 9),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              widget.user?.displayName.toUpperCase() ?? 'GUEST USER',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'MEMBERSHIP LEVEL: ${level.toUpperCase()}',
              style: TextStyle(
                color: ShowSnapColors.primary.withOpacity(0.6),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'VALUED MEMBER SINCE 2026',
                  style: TextStyle(color: Colors.white30, fontSize: 8, fontWeight: FontWeight.bold),
                ),
                // Pseudo Card Chip / Tech element
                Container(
                  width: 32,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber.withOpacity(0.4)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVipCardBack() {
    return TappableScale(
      onTap: _triggerCardAnimation,
      child: Container(
        height: 180,
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF0F1012), Color(0xFF1E2125)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: ShowSnapColors.primary.withOpacity(0.35), width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              height: 36,
              width: double.infinity,
              color: Colors.black38,
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(40, (idx) {
                final height = (idx % 3 == 0) ? 28.0 : (idx % 2 == 0) ? 20.0 : 12.0;
                final width = (idx % 5 == 0) ? 3.0 : 1.5;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  height: height,
                  width: width,
                  color: ShowSnapColors.primary.withOpacity(0.7),
                );
              }),
            ),
            const SizedBox(height: 6),
            Text(
              'ETKT_${widget.user?.uid.substring(0, 8).toUpperCase() ?? 'GUEST'}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: ShowSnapColors.primary.withOpacity(0.5),
                letterSpacing: 2,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  void _showEditProfile(BuildContext context) {
    final user = widget.user;
    final nameCtrl = TextEditingController(text: user?.displayName ?? '');
    final cityCtrl = TextEditingController(text: user?.city ?? '');
    String completePhone = user?.phone ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2124),
      isScrollControlled: true,
      useRootNavigator: true,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ShowSnapRadius.lg)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Edit Profile Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Divider(color: Colors.white12, height: 24),
              TextFormField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: cityCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'City',
                  labelStyle: const TextStyle(color: Colors.white70),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.my_location, color: ShowSnapColors.primary),
                    onPressed: () async {
                      try {
                        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                        if (!serviceEnabled) {
                          if (sheetCtx.mounted) ShowSnapToast.error(sheetCtx, 'Location services disabled');
                          return;
                        }

                        LocationPermission permission = await Geolocator.checkPermission();
                        if (permission == LocationPermission.denied) {
                          permission = await Geolocator.requestPermission();
                          if (permission == LocationPermission.denied) return;
                        }
                        if (permission == LocationPermission.deniedForever) return;

                        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
                        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

                        if (placemarks.isNotEmpty) {
                          Placemark p = placemarks.first;
                          cityCtrl.text = p.locality ?? p.subAdministrativeArea ?? 'Unknown';
                        }
                      } catch (e) {
                        if (sheetCtx.mounted) {
                          ShowSnapToast.error(sheetCtx, 'Could not fetch location');
                        }
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              IntlPhoneField(
                initialValue: user?.phone,
                style: const TextStyle(color: Colors.white),
                dropdownTextStyle: const TextStyle(color: Colors.white),
                initialCountryCode: 'IN',
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                onChanged: (phone) {
                  completePhone = phone.completeNumber;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ShowSnapColors.primary,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () async {
                  final uid = ref.read(authStateProvider).valueOrNull?.uid;
                  if (uid == null) return;
                  await ref.read(databaseServiceProvider).updateUser(uid, {
                    'displayName': nameCtrl.text.trim(),
                    'city': cityCtrl.text.trim(),
                    'phone': completePhone,
                  });
                  widget.onRefresh();
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                },
                child: const Text('Save Profile'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

// ─── Quick Services Grid (BookMyShow Styling) ───────────────────────────────

class _QuickServicesGrid extends StatelessWidget {
  final VoidCallback onPurchasesTap;
  final VoidCallback onWishlistTap;
  final VoidCallback onRewardsTap;
  final VoidCallback onInfluencerTap;

  const _QuickServicesGrid({
    required this.onPurchasesTap,
    required this.onWishlistTap,
    required this.onRewardsTap,
    required this.onInfluencerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Shortcuts',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ServiceTile(
                icon: Icons.confirmation_number_outlined,
                label: 'Bookings',
                onTap: onPurchasesTap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ServiceTile(
                icon: Icons.favorite_border_rounded,
                label: 'Wishlist',
                onTap: onWishlistTap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ServiceTile(
                icon: Icons.emoji_events_outlined,
                label: 'Rewards',
                onTap: onRewardsTap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ServiceTile(
                icon: Icons.campaign_outlined,
                label: 'Campaigns',
                onTap: onInfluencerTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TappableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2022),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Icon(icon, color: ShowSnapColors.primary, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
      _StatInfo('Shows Booked', '${confirmed.length}', Icons.local_activity_outlined, const Color(0xFF8E24AA)),
      _StatInfo('Unique Titles', '$uniqueMovies', Icons.movie_outlined, const Color(0xFF00ACC1)),
      _StatInfo('Favorite City', 'Bangalore', Icons.location_on_outlined, const Color(0xFFFFB300)),
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
        color: const Color(0xFF1E2022),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: info.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(info.icon, color: info.color, size: 18),
          ),
          const Spacer(),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, val, child) {
              final raw = info.value.replaceAll(RegExp(r'[^\d]'), '');
              final isNumeric = raw.isNotEmpty;
              if (isNumeric) {
                final numVal = int.tryParse(raw) ?? 0;
                final animated = (numVal * val).toInt();
                final prefix = info.value.startsWith('₹') ? '₹' : '';
                return Text(
                  '$prefix$animated',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: info.color,
                  ),
                );
              }
              return Text(
                info.value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: info.color,
                ),
              );
            },
          ),
          const SizedBox(height: 2),
          Text(
            info.label,
            style: const TextStyle(fontSize: 10, color: Colors.white54),
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
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      return DateTime(now.year, now.month - (5 - i));
    });

    final counts = months.map((m) {
      return bookings.where((b) {
        final dt = DateTime.fromMillisecondsSinceEpoch(b.createdAt);
        return dt.year == m.year && dt.month == m.month;
      }).length.toDouble();
    }).toList();

    final bars = counts.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value,
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF8E9E20),
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
        color: const Color(0xFF1E2022),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Monthly Bookings',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
          const SizedBox(height: 2),
          const Text('Booking frequencies over the past 6 months',
              style: TextStyle(fontSize: 11, color: Colors.white54)),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (counts.reduce((a, b) => a > b ? a : b) + 1).clamp(4, double.infinity),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withOpacity(0.05),
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
                          DateFormat('MMM').format(months[v.toInt()]),
                          style: const TextStyle(fontSize: 9, color: Colors.white54),
                        ),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: const TextStyle(fontSize: 9, color: Colors.white54),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                barGroups: bars,
              ),
              swapAnimationDuration: const Duration(milliseconds: 600),
              swapAnimationCurve: Curves.easeOutBack,
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

    if (confirmed < 1) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2022),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.03)),
        ),
        child: Column(
          children: [
            const Icon(Icons.radar_outlined, size: 52, color: Colors.white30),
            const SizedBox(height: 12),
            const Text('Your Taste Analysis',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
            const SizedBox(height: 6),
            const Text(
              'Complete bookings to populate your cinematic taste profile graph!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ShowSnapColors.primary),
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Find Movies / Events', style: TextStyle(color: Colors.black87)),
            ),
          ],
        ),
      );
    }

    const genres = ['Action', 'Drama', 'Comedy', 'Thriller', 'Romance', 'Sci-Fi'];
    final values = [4.0, 3.2, 2.8, 4.5, 1.8, 3.5];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2022),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cinematic Taste Analysis',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: RadarChart(
              RadarChartData(
                radarShape: RadarShape.polygon,
                ticksTextStyle: const TextStyle(fontSize: 8, color: Colors.transparent),
                gridBorderData: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
                titlePositionPercentageOffset: 0.15,
                titleTextStyle: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600),
                getTitle: (i, _) => RadarChartTitle(text: genres[i % genres.length]),
                dataSets: [
                  RadarDataSet(
                    fillColor: ShowSnapColors.primary.withOpacity(0.18),
                    borderColor: ShowSnapColors.primary,
                    borderWidth: 2,
                    entryRadius: 3.5,
                    dataEntries: values.map((v) => RadarEntry(value: v)).toList(),
                  ),
                ],
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                tickCount: 4,
              ),
              swapAnimationDuration: const Duration(milliseconds: 750),
              swapAnimationCurve: Curves.easeOutBack,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Rewards Section ──────────────────────────────────────────────────────────

class _RewardsSection extends ConsumerWidget {
  final UserModel? user;
  final int bookingCount;
  final VoidCallback onCouponClaimed;

  const _RewardsSection({
    required this.user,
    required this.bookingCount,
    required this.onCouponClaimed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(_offersProvider);

    return offersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const SizedBox(),
      data: (offers) {
        final activeOffers = offers
            .where((o) => o.isActive && o.milestoneType == MilestoneType.totalBookings)
            .toList()
          ..sort((a, b) => a.threshold.compareTo(b.threshold));

        int nextMilestone = bookingCount + 5;
        int prevThreshold = (bookingCount ~/ 5) * 5;
        List<_Coupon> rewards = [];

        if (activeOffers.isNotEmpty) {
          OfferModel? nextOffer;
          OfferModel? prevOffer;
          for (final o in activeOffers) {
            if (o.threshold > bookingCount) {
              nextOffer = o;
              break;
            }
            prevOffer = o;
          }

          nextMilestone = nextOffer?.threshold ?? (prevOffer?.threshold ?? bookingCount);
          prevThreshold = prevOffer?.threshold ?? 0;

          rewards = activeOffers.map((o) {
            final isUnlocked = bookingCount >= o.threshold;
            final status = isUnlocked ? 'Unlocked' : 'Locked';
            String descr = '';
            if (o.rewardType == RewardType.percentDiscount) {
              descr = '${o.rewardValue.toInt()}% off next booking';
            } else if (o.rewardType == RewardType.flatDiscount) {
              descr = 'Flat ₹${o.rewardValue.toInt()} Off';
            } else {
              descr = 'Free Ticket';
            }
            return _Coupon(o.offerId.toUpperCase(), descr, status);
          }).toList();
        } else {
          // Fallback if no admin offers
          nextMilestone = prevThreshold + 5;
          rewards = [
            const _Coupon('BOOK50', '50% off next booking (up to ₹150)', 'Active'),
            const _Coupon('FREESHIP', 'Free popcorn combo on events', 'Unlocked'),
            const _Coupon('VIPSNAP', 'Flat ₹100 Off next Concert ticket', 'Active'),
          ];
        }

        final progress = nextMilestone == prevThreshold
            ? 1.0
            : ((bookingCount - prevThreshold) / (nextMilestone - prevThreshold)).clamp(0.0, 1.0);
        final needed = nextMilestone - bookingCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2022),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Unlocked Milestones & Rewards',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
          const SizedBox(height: 2),
          const Text('Tap coupon code to copy instantly!',
              style: TextStyle(fontSize: 11, color: Colors.white54)),
          const SizedBox(height: 16),
          
          // Progress bar
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined, color: ShowSnapColors.primary, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      needed > 0
                          ? 'Book $needed more shows for next milestone!'
                          : 'Milestone reached! Check your coupons.',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8E9E20), ShowSnapColors.primary],
                              ),
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$bookingCount/$nextMilestone bookings completed',
                      style: const TextStyle(fontSize: 10, color: Colors.white38),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          
          // Horizontal coupons grid/list
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: rewards.length,
              itemBuilder: (context, idx) {
                final r = rewards[idx];
                return GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: r.code));
                    onCouponClaimed();
                    if (context.mounted) {
                      ShowSnapToast.show(context,
                          message: '📋 Coupon code "${r.code}" copied to clipboard!');
                    }
                  },
                  child: Container(
                    width: 240,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ShowSnapColors.primary.withOpacity(0.12),
                          Colors.white.withOpacity(0.02)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ShowSnapColors.primary.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.confirmation_number_outlined, color: ShowSnapColors.primary, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                r.code,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                r.descr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
    },
    );
  }
}

class _Coupon {
  final String code;
  final String descr;
  final String status;
  const _Coupon(this.code, this.descr, this.status);
}

// ─── Recent Bookings / Purchases ─────────────────────────────────────────────

class _RecentBookings extends StatelessWidget {
  final List<BookingModel> bookings;
  const _RecentBookings({required this.bookings});

  @override
  Widget build(BuildContext context) {
    final confirmedList = bookings
        .where((b) =>
            b.status == BookingStatus.confirmed ||
            b.status == BookingStatus.redeemed ||
            b.status == BookingStatus.cancelled)
        .take(5)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Purchase History',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
            TextButton.icon(
              icon: const Icon(Icons.arrow_right_alt, size: 16),
              label: const Text('View All'),
              onPressed: () => context.go(AppRoutes.myBookings),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (confirmedList.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2022),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: Text('No tickets booked yet', style: TextStyle(color: Colors.white30)),
            ),
          )
        else
          AnimationLimiter(
            child: Column(
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 300),
                childAnimationBuilder: (widget) => SlideAnimation(
                  verticalOffset: 15,
                  child: FadeInAnimation(child: widget),
                ),
                children: confirmedList.map((b) => _BookingRow(booking: b)).toList(),
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
            ? Colors.white38
            : ShowSnapColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2022),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.02)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.local_activity_outlined, color: ShowSnapColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.movieTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${booking.theaterName} • ${booking.createdAt.epochToDateLabel}',
                  style: const TextStyle(fontSize: 10, color: Colors.white54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    booking.status.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8,
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isConfirmed)
            TappableScale(
              onTap: () => context.push('/ticket/${booking.bookingId}'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ShowSnapColors.primary,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'Ticket',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
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
      _SettRow(Icons.notifications_none_rounded, 'Notification Preferences',
          () => _NotifPrefsSheet.show(context)),
      _SettRow(Icons.place_outlined, 'City & Location settings', () {}),
      _SettRow(Icons.movie_filter_outlined, 'Genre Preferences',
          () => context.push(AppRoutes.profileSetup)),
      _SettRow(Icons.description_outlined, 'Terms of Service & Privacy policy', () {}),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2022),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Column(
        children: [
          ...rows.map((r) => _SettingsRow(row: r)),
          _SettingsRow(
            row: _SettRow(Icons.logout_rounded, 'Sign Out', () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dlgCtx) => AlertDialog(
                  backgroundColor: const Color(0xFF1F2124),
                  title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
                  content: const Text('Are you sure you want to sign out?', style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(dlgCtx).pop(false),
                        child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: ShowSnapColors.error),
                      onPressed: () => Navigator.of(dlgCtx).pop(true),
                      child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('My Wishlist',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Items'),
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
                  color: const Color(0xFF1E2022),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_border_rounded, color: Colors.white24),
                    SizedBox(width: 8),
                    Text('Nothing in your wishlist yet', style: TextStyle(color: Colors.white30)),
                  ],
                ),
              );
            }
            final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
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
                        borderRadius: BorderRadius.circular(16),
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
                        color: const Color(0xFF1E2022),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.02)),
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
                            child: Text(
                              entry.key,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          const Icon(Icons.favorite_rounded, color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right, color: Colors.white30),
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
        color: const Color(0xFF1E2022),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_outlined, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Influencer Ads Hub',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
              ),
              TextButton(
                onPressed: () => context.push('/influencer/ad-request'),
                child: const Text('New Ad Request', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text('Advertise your brand/walkthrough at ShowSnap screens',
              style: TextStyle(fontSize: 11, color: Colors.white54)),
          const SizedBox(height: 14),
          adRequestsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
            data: (requests) {
              if (requests.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add_circle_outline, color: Colors.white30, size: 18),
                      const SizedBox(width: 8),
                      Text('No campaign requests yet', style: TextStyle(color: Colors.white30, fontSize: 12)),
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
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                req.campaignTitle,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(req.brandName, style: const TextStyle(fontSize: 10, color: Colors.white54)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withOpacity(0.5)),
                          ),
                          child: Text(
                            req.status.name.toUpperCase(),
                            style: TextStyle(color: statusColor, fontSize: 8, fontWeight: FontWeight.bold),
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
      backgroundColor: const Color(0xFF1F2124),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(ShowSnapRadius.lg))),
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
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Notification Preferences',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Choose what you\'d like to be notified about',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 16),
          prefsAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
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
                      color: ShowSnapColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: ShowSnapColors.primary),
                  ),
                  title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                  value: enabled,
                  activeColor: ShowSnapColors.primary,
                  activeTrackColor: ShowSnapColors.primary.withOpacity(0.35),
                  inactiveTrackColor: Colors.black26,
                  onChanged: uid.isEmpty
                      ? null
                      : (v) => ref.read(databaseServiceProvider).updateNotifPref(uid, key, v),
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
    final color = isDestructive ? ShowSnapColors.error : Colors.white;
    return TappableScale(
      onTap: row.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDestructive
                    ? ShowSnapColors.error.withOpacity(0.12)
                    : ShowSnapColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                row.icon,
                size: 18,
                color: isDestructive ? ShowSnapColors.error : ShowSnapColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(row.label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 13)),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
