import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../core/config/theme.dart';
import '../../core/widgets/tappable_scale.dart';

class _OnboardPage {
  final String title;
  final String subtitle;
  final Color bgColor;
  final String imageUrl;

  const _OnboardPage({
    required this.title,
    required this.subtitle,
    required this.bgColor,
    required this.imageUrl,
  });
}

const _pages = [
  _OnboardPage(
    title: 'Explore Limitless Entertainment',
    subtitle:
        'Browse the latest blockbuster movies, exclusive events, and unforgettable concerts all in one place.',
    bgColor: Color(0xFFFFF8E1),
    imageUrl: 'https://i.ibb.co/gb1vvxCD/erasebg-transformed-6.jpg',
  ),
  _OnboardPage(
    title: 'Secure Your Best Spot',
    subtitle:
        'Choose your favorite seats instantly with our interactive and real-time theater maps.',
    bgColor: Color(0xFFE8F5E9),
    imageUrl: 'https://i.ibb.co/9mKK30wJ/erasebg-transformed-7.jpg',
  ),
  _OnboardPage(
    title: 'Unlock Exclusive Rewards',
    subtitle:
        'Earn points with every ticket you book and enjoy free movies, discounts, and VIP perks.',
    bgColor: Color(0xFFFCE4EC),
    imageUrl: 'https://i.ibb.co/whJZdng4/erasebg-transformed-8.jpg',
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
                child: TappableScale(
                  onTap: _finish,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: ShowSnapColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
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
                  TappableScale(
                    onTap: () {
                      if (_currentPage < _pages.length - 1) {
                        _pageController.nextPage(
                          duration: ShowSnapDuration.normal,
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _finish();
                      }
                    },
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: DecoratedBox(
                        decoration: ShowSnapTheme.primaryButtonDecoration,
                        child: Center(
                          child: Text(
                            _currentPage == _pages.length - 1
                                ? 'Get Started'
                                : 'Next',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 16, 
                              color: Colors.white,
                            ),
                          ),
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
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 300,
                maxHeight: 300,
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: page.bgColor,
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: TappableScale(
                    child: Image.network(
                      page.imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
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

          const SizedBox(height: 24),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black,
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
