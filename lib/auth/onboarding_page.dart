// FILE: lib/onboarding/onboarding_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // ── Brand tokens (identical to LoginPage + Dashboard) ───────────────────
  static const Color _purple      = Color(0xFF7C14D4);
  static const Color _purpleDeep  = Color(0xFF5A0EA0);
  static const Color _orange      = Color(0xFFFF8C00);
  static const Color _orangeLight = Color(0xFFFFB347);
  static const Color _dark        = Color(0xFF1A1A2E);
  static const Color _darkMid     = Color(0xFF3D2066);

  static const List<_OnboardSlide> _slides = [
    _OnboardSlide(
      gradientStart:  _purple,
      gradientEnd:    _purpleDeep,
      accentColor:    _orange,
      icon:           Icons.local_cafe_rounded,
      useLogoInstead: true,
      badgeIcon:      Icons.waving_hand_rounded,
      badge:          'Welcome',
      title:          'Welcome to\nLucky Boba!',
      subtitle:
      'Your favourite boba shop is now in your pocket. Order, earn, and enjoy exclusive perks — all in one place.',
    ),
    _OnboardSlide(
      gradientStart:  _orange,
      gradientEnd:    _orangeLight,
      accentColor:    _purple,
      icon:           Icons.card_giftcard_rounded,
      useLogoInstead: false,
      badgeIcon:      Icons.local_offer_rounded,
      badge:          'Sweet Deals',
      title:          'Unlock Card\nPerks',
      subtitle:
      'Avail a Lucky Boba card and get exclusive deals like Buy 1 Get 1 Free and 10% Off — redeemable via QR.',
    ),
    _OnboardSlide(
      gradientStart:  _dark,
      gradientEnd:    _darkMid,
      accentColor:    _orange,
      icon:           Icons.star_rounded,
      useLogoInstead: false,
      badgeIcon:      Icons.emoji_events_rounded,
      badge:          'Start Earning',
      title:          'Earn Lucky\nPoints',
      subtitle:
      'Every purchase earns you Lucky Points. Collect and redeem for free drinks, upgrades, and special rewards.',
    ),
  ];

  // ── Animation controllers ────────────────────────────────────────────────
  late final List<AnimationController> _fadeCtrl;
  late final List<Animation<double>>   _fadeAnim;
  late final List<AnimationController> _riseCtrl;
  late final List<Animation<Offset>>   _riseAnim;
  late final AnimationController       _pulseCtrl;
  late final Animation<double>         _pulseAnim;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Per-slide fade
    _fadeCtrl = List.generate(
      _slides.length,
          (_) => AnimationController(
          vsync: this, duration: const Duration(milliseconds: 550)),
    );
    _fadeAnim = _fadeCtrl
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut))
        .toList();

    // Per-slide rise
    _riseCtrl = List.generate(
      _slides.length,
          (_) => AnimationController(
          vsync: this, duration: const Duration(milliseconds: 600)),
    );
    _riseAnim = _riseCtrl
        .map((c) => Tween<Offset>(
      begin: const Offset(0, 0.10),
      end:   Offset.zero,
    ).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOut)))
        .toList();

    // Continuous icon pulse
    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.07).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Kick off first slide
    _fadeCtrl[0].forward();
    _riseCtrl[0].forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _fadeCtrl) { c.dispose(); }
    for (final c in _riseCtrl) { c.dispose(); }
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _fadeCtrl[index].forward(from: 0);
    _riseCtrl[index].forward(from: 0);
  }

  // ── Finish: mark done (never shows again) → go to LoginPage ─────────────
  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder:        (_, _, _) => const LoginPage(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 450),
      ),
    );
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve:    Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide  = _slides[_currentPage];
    final isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 480),
        curve:    Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
            colors: [slide.gradientStart, slide.gradientEnd],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [

              // ── Top row: step counter + skip ──────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Step pill  e.g. "1 / 3"
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color:        Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        '${_currentPage + 1} / ${_slides.length}',
                        style: GoogleFonts.poppins(
                          fontSize:   12,
                          fontWeight: FontWeight.w700,
                          color:      Colors.white,
                        ),
                      ),
                    ),

                    // Skip — hidden on last slide
                    AnimatedOpacity(
                      opacity:  isLast ? 0 : 1,
                      duration: const Duration(milliseconds: 300),
                      child: GestureDetector(
                        onTap: isLast ? null : _finish,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color:        Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'Skip',
                            style: GoogleFonts.poppins(
                              fontSize:   13,
                              fontWeight: FontWeight.w600,
                              color:      Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Page view ─────────────────────────────────────────────
              Expanded(
                child: PageView.builder(
                  controller:    _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount:     _slides.length,
                  itemBuilder:   (_, index) {
                    final s = _slides[index];
                    return FadeTransition(
                      opacity: _fadeAnim[index],
                      child: SlideTransition(
                        position: _riseAnim[index],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32),
                          child: Column(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [

                              // ── Icon / Logo bubble ───────────────
                              ScaleTransition(
                                scale: _pulseAnim,
                                child: Container(
                                  width:  160,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white
                                        .withValues(alpha: 0.13),
                                    border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: 0.28),
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.20),
                                        blurRadius: 50,
                                        offset:
                                        const Offset(0, 18),
                                      ),
                                    ],
                                  ),
                                  child: s.useLogoInstead
                                      ? Padding(
                                    padding:
                                    const EdgeInsets.all(
                                        28),
                                    child: Image.asset(
                                      'assets/images/logo.png',
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (_, _, _) =>
                                      const Icon(
                                        Icons
                                            .local_cafe_rounded,
                                        color: Colors.white,
                                        size:  64,
                                      ),
                                    ),
                                  )
                                      : Icon(
                                    s.icon,
                                    color: Colors.white,
                                    size:  72,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 44),

                              // ── Badge pill ───────────────────────
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 7),
                                decoration: BoxDecoration(
                                  color: s.accentColor
                                      .withValues(alpha: 0.22),
                                  borderRadius:
                                  BorderRadius.circular(20),
                                  border: Border.all(
                                    color: s.accentColor
                                        .withValues(alpha: 0.55),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(s.badgeIcon,
                                        color: Colors.white,
                                        size:  13),
                                    const SizedBox(width: 6),
                                    Text(
                                      s.badge,
                                      style: GoogleFonts.poppins(
                                        fontSize:      11,
                                        fontWeight:    FontWeight.w700,
                                        color:         Colors.white,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 18),

                              // ── Title ────────────────────────────
                              Text(
                                s.title,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize:   34,
                                  fontWeight: FontWeight.w800,
                                  color:      Colors.white,
                                  height:     1.15,
                                ),
                              ),

                              const SizedBox(height: 16),

                              // ── Subtitle ─────────────────────────
                              Text(
                                s.subtitle,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color:    Colors.white
                                      .withValues(alpha: 0.82),
                                  height:   1.65,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Dots + CTA ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 44),
                child: Column(
                  children: [
                    // Animated pill dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (i) {
                        final active = i == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 320),
                          curve:    Curves.easeInOut,
                          margin: const EdgeInsets.symmetric(
                              horizontal: 4),
                          width:  active ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 28),

                    // CTA button — white card, gradient text color
                    GestureDetector(
                      onTap: _next,
                      child: Container(
                        width:   double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 17),
                        decoration: BoxDecoration(
                          color:        Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 24,
                              offset:     const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: [
                            Text(
                              isLast ? 'Get Started' : 'Next',
                              style: GoogleFonts.poppins(
                                fontSize:   15,
                                fontWeight: FontWeight.w700,
                                color:      slide.gradientStart,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isLast
                                  ? Icons.local_cafe_rounded
                                  : Icons.arrow_forward_rounded,
                              color: slide.gradientStart,
                              size:  18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────
class _OnboardSlide {
  final Color    gradientStart;
  final Color    gradientEnd;
  final Color    accentColor;
  final IconData icon;
  final bool     useLogoInstead;
  final IconData badgeIcon;
  final String   badge;
  final String   title;
  final String   subtitle;

  const _OnboardSlide({
    required this.gradientStart,
    required this.gradientEnd,
    required this.accentColor,
    required this.icon,
    required this.useLogoInstead,
    required this.badgeIcon,
    required this.badge,
    required this.title,
    required this.subtitle,
  });
}