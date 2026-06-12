import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../core/config/theme.dart';

class _OnboardPage {
  final String title;
  final String subtitle;
  final Color bgColor;
  final IconData icon;
  final Color iconColor;

  const _OnboardPage({
    required this.title,
    required this.subtitle,
    required this.bgColor,
    required this.icon,
    required this.iconColor,
  });
}

const _pages = [
  _OnboardPage(
    title: 'Discover What\'s Playing',
    subtitle:
        'Movies, events, concerts — all in one place, personalised just for you.',
    bgColor: Color(0xFFFFF8E1),
    icon: Icons.movie_filter_rounded,
    iconColor: ShowSnapColors.primary,
  ),
  _OnboardPage(
    title: 'Pick Your Perfect Seat',
    subtitle:
        'Interactive seat maps with real-time availability. Your seat, your choice.',
    bgColor: Color(0xFFE8F5E9),
    icon: Icons.event_seat_rounded,
    iconColor: ShowSnapColors.secondary,
  ),
  _OnboardPage(
    title: 'Earn While You Watch',
    subtitle:
        'Book 9 movies, get the 10th free. Unlock rewards with every booking.',
    bgColor: Color(0xFFFCE4EC),
    icon: Icons.emoji_events_rounded,
    iconColor: Color(0xFFE91E63),
  ),
];

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenWelcome', true);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip'),
                ),
              ),
            ),

            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) =>
                    _PageContent(page: _pages[i], isActive: i == _currentPage),
              ),
            ),

            // Dots + button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _pages.length,
                    effect: const WormEffect(
                      activeDotColor: ShowSnapColors.primary,
                      dotColor: ShowSnapColors.grey300,
                      dotHeight: 10,
                      dotWidth: 10,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: DecoratedBox(
                      decoration: ShowSnapTheme.primaryButtonDecoration,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(ShowSnapRadius.md),
                          ),
                        ),
                        onPressed: () {
                          if (_currentPage < _pages.length - 1) {
                            _pageController.nextPage(
                              duration: ShowSnapDuration.normal,
                              curve: Curves.easeInOut,
                            );
                          } else {
                            _finish();
                          }
                        },
                        child: Text(
                          _currentPage == _pages.length - 1
                              ? 'Get Started'
                              : 'Next',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  final _OnboardPage page;
  final bool isActive;

  const _PageContent({required this.page, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration area
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: page.bgColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(page.icon, size: 100, color: page.iconColor),
            ),
          )
              .animate(target: isActive ? 1 : 0)
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1, 1),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
              )
              .fadeIn(duration: const Duration(milliseconds: 400)),

          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: ShowSnapColors.onBackground,
              height: 1.2,
            ),
          )
              .animate(target: isActive ? 1 : 0)
              .slideY(
                begin: 0.3,
                end: 0,
                duration: const Duration(milliseconds: 400),
                delay: const Duration(milliseconds: 100),
                curve: Curves.easeOutCubic,
              )
              .fadeIn(
                duration: const Duration(milliseconds: 400),
                delay: const Duration(milliseconds: 100),
              ),

          const SizedBox(height: 16),

          // Subtitle
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: ShowSnapColors.grey600,
              height: 1.6,
            ),
          )
              .animate(target: isActive ? 1 : 0)
              .slideY(
                begin: 0.3,
                end: 0,
                duration: const Duration(milliseconds: 400),
                delay: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
              )
              .fadeIn(
                duration: const Duration(milliseconds: 400),
                delay: const Duration(milliseconds: 200),
              ),
        ],
      ),
    );
  }
}
