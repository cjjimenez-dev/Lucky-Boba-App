// FILE: lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../config/app_config.dart';

const List<String> _kPerkNames = [
  'Buy 1, Get 1 Free',
  '10% Off All Items',
];

class HomePage extends StatefulWidget {
  final VoidCallback? onGoToCards;

  const HomePage({super.key, this.onGoToCards});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const Color _purple   = Color(0xFF7C14D4);
  static const Color _orange   = Color(0xFFFF8C00);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMid  = Color(0xFF6B6B8A);

  bool _loadingCard   = true;
  bool _hasActiveCard = false;
  final Map<String, bool> _usedToday = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadingCard) _loadPerkUsage();
  }

  Future<void> _loadAll() async {
    await _checkActiveCard();
    await _loadPerkUsage();
  }

  Future<void> _checkActiveCard() async {
    final prefs       = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('user_id');

    // ── Step 1: Apply SharedPreferences instantly — no flicker ────────────
    final bool cached = prefs.getBool('has_active_card') ?? false;
    debugPrint('🔍 [HomePage] cached has_active_card = $cached');
    if (mounted) {
      setState(() => _hasActiveCard = cached);
    }

    if (userId == null) {
      debugPrint('🔍 [HomePage] user_id is null — skipping API call');
      if (mounted) setState(() => _loadingCard = false);
      return;
    }

    // ── Step 2: Verify with API in background ─────────────────────────────
    try {
      debugPrint('🔍 [HomePage] calling check-card-status/$userId');
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/check-card-status/$userId'),
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;
      debugPrint('🔍 [HomePage] API response: ${response.body}');

      if (response.statusCode == 200) {
        final data         = jsonDecode(response.body);
        final bool hasCard = data['has_active_card'] == true;

        await prefs.setBool('has_active_card', hasCard);
        if (hasCard) {
          final int? cardId = data['card_id'] is int
              ? data['card_id']
              : int.tryParse(data['card_id']?.toString() ?? '');
          if (cardId != null) await prefs.setInt('card_id', cardId);
        } else {
          await prefs.remove('card_id');
        }

        debugPrint('🔍 [HomePage] API has_active_card = $hasCard');
        if (mounted) setState(() => _hasActiveCard = hasCard);
      }
    } catch (e) {
      debugPrint('🔍 [HomePage] API error: $e');
    } finally {
      if (mounted) setState(() => _loadingCard = false);
    }
  }

  Future<void> _loadPerkUsage() async {
    final prefs        = await SharedPreferences.getInstance();
    final String today = DateTime.now().toIso8601String().substring(0, 10);
    final Map<String, bool> used = {};
    for (final name in _kPerkNames) {
      final String  key   = 'qr_date_$name';
      final String? saved = prefs.getString(key);
      used[name] = saved == today;
    }
    if (mounted) {
      setState(() {
        _usedToday
          ..clear()
          ..addAll(used);
        _loadingCard = false;
      });
    }
  }

  int get _remainingPerks =>
      _kPerkNames.where((n) => !(_usedToday[n] ?? false)).length;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── STAT CARDS ROW ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _StatCard(
                      label:     'Lucky Points',
                      value:     'Coming Soon',
                      icon:      Icons.star_rounded,
                      iconColor: _orange,
                      badge:     null,
                      onTap:     null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label:     'Card Promos',
                      value:     _hasActiveCard
                          ? '$_remainingPerks Remaining'
                          : 'No Card',
                      icon:      Icons.card_giftcard_rounded,
                      iconColor: _purple,
                      badge:     _hasActiveCard ? null : 'Get Now',
                      onTap:     widget.onGoToCards,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── CARD PROMOS ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Card Promos',
                  style: GoogleFonts.poppins(
                    fontSize:   18,
                    fontWeight: FontWeight.w700,
                    color:      _textDark,
                  ),
                ),
                GestureDetector(
                  onTap: widget.onGoToCards,
                  child: Text(
                    _hasActiveCard ? 'View card' : 'Get a card',
                    style: GoogleFonts.poppins(
                      fontSize:   12,
                      fontWeight: FontWeight.w600,
                      color:      _purple,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Loading skeleton
          if (_loadingCard)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  color:        const Color(0xFFEAEAF0),
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            )

          // ── HAS CARD ──────────────────────────────────────────────────
          else if (_hasActiveCard)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: widget.onGoToCards,
                child: Container(
                  width:   double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color:        const Color(0xFFF2EEF8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: _purple.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                            color: _purple, shape: BoxShape.circle),
                        child: const Icon(Icons.card_giftcard_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('You have an active card!',
                                style: GoogleFonts.poppins(
                                  fontSize:   14,
                                  fontWeight: FontWeight.w700,
                                  color:      _textDark,
                                )),
                            Text('Tap to view your perks',
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: _textMid)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: _purple, size: 14),
                    ],
                  ),
                ),
              ),
            )

          // ── NO CARD ───────────────────────────────────────────────────
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: widget.onGoToCards,
                child: Container(
                  width:   double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color:        const Color(0xFFFFF8F0),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: _orange.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                            color: _orange, shape: BoxShape.circle),
                        child: const Icon(Icons.card_giftcard_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('No promos available',
                                style: GoogleFonts.poppins(
                                  fontSize:   14,
                                  fontWeight: FontWeight.w700,
                                  color:      _textDark,
                                )),
                            Text('Avail a Lucky Boba card to unlock perks',
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: _textMid)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded,
                          color: _orange, size: 14),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 28),

          // ── NEW PRODUCT ALERT ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('New Product Alert!',
                style: GoogleFonts.poppins(
                  fontSize:   18,
                  fontWeight: FontWeight.w700,
                  color:      _textDark,
                )),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _TappableCard(
              child: _HeroBanner(
                imagePath:      'assets/images/promo1.png',
                gradientColors: const [Color(0xFFFF8C00), Color(0xFF7C14D4)],
                title:          'Holiday Overload',
                subTitle:       'Limited Time Offer',
                cta:            'Order Now',
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── EXPLORE CATEGORIES ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Explore Categories',
                style: GoogleFonts.poppins(
                  fontSize:   18,
                  fontWeight: FontWeight.w700,
                  color:      _textDark,
                )),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics:         const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _CategoryCard(label: 'Lucky Classic',
                    imagePath: 'assets/images/lucky_classic.png',
                    fallback:  _orange),
                const SizedBox(width: 12),
                _CategoryCard(label: 'Frappes',
                    imagePath: 'assets/images/frappe.png',
                    fallback:  const Color(0xFFAB47BC)),
                const SizedBox(width: 12),
                _CategoryCard(label: 'Iced Coffees',
                    imagePath: 'assets/images/iced_coffee.png',
                    fallback:  const Color(0xFF8D6E63)),
                const SizedBox(width: 12),
                _CategoryCard(label: 'Fruit Juices',
                    imagePath: 'assets/images/fruit_juices.png',
                    fallback:  const Color(0xFF66BB6A)),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── NEARBY STORES ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Nearby Stores',
                style: GoogleFonts.poppins(
                  fontSize:   18,
                  fontWeight: FontWeight.w700,
                  color:      _textDark,
                )),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _TappableCard(
              child: _HeroBanner(
                imagePath:      'assets/images/promo2.png',
                gradientColors: const [Color(0xFF7C14D4), Color(0xFF6A0EC0)],
                title:          'Grand Opening',
                subTitle:       'Pamana Medical Center Branch',
                cta:            'Directions',
              ),
            ),
          ),

          const SizedBox(height: 110),
        ],
      ),
    );
  }
}

// ── STAT CARD ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String        label;
  final String        value;
  final IconData      icon;
  final Color         iconColor;
  final String?       badge;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 16, 10, 14),
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEAEAF0), width: 1),
              boxShadow: [
                BoxShadow(
                  color:      Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset:     const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(height: 10),
                Text(value,
                    style: GoogleFonts.poppins(
                      fontSize:   16,
                      fontWeight: FontWeight.w700,
                      color:      const Color(0xFF1A1A2E),
                    )),
                const SizedBox(height: 2),
                Text(label,
                    style: GoogleFonts.poppins(
                      fontSize:   10,
                      color:      const Color(0xFF6B6B8A),
                      fontWeight: FontWeight.w500,
                    )),
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              top:   -9,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color:        const Color(0xFF7C14D4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(badge!,
                    style: GoogleFonts.poppins(
                      fontSize:   9,
                      color:      Colors.white,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ),
        ],
      ),
    );
  }
}

// ── HERO BANNER ───────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final String      imagePath;
  final List<Color> gradientColors;
  final String      title;
  final String      subTitle;
  final String      cta;

  const _HeroBanner({
    required this.imagePath,
    required this.gradientColors,
    required this.title,
    required this.subTitle,
    required this.cta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          colors: gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color:      gradientColors.first.withValues(alpha: 0.28),
            blurRadius: 20,
            offset:     const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                imagePath,
                fit:          BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                const SizedBox(),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin:  Alignment.topCenter,
                    end:    Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.60),
                    ],
                    stops: const [0.35, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20, right: 20, bottom: 18,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment:  MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize:       MainAxisSize.min,
                      children: [
                        Text(
                          subTitle.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize:      9,
                            color:         Colors.white70,
                            fontWeight:    FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize:   22,
                            color:      Colors.white,
                            fontWeight: FontWeight.w700,
                            height:     1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color:        Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(cta,
                        style: GoogleFonts.poppins(
                          fontSize:   11,
                          fontWeight: FontWeight.w700,
                          color:      const Color(0xFF7C14D4),
                        )),
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

// ── CATEGORY CARD ─────────────────────────────────────────────────────────────
class _CategoryCard extends StatelessWidget {
  final String label;
  final String imagePath;
  final Color  fallback;

  const _CategoryCard({
    required this.label,
    required this.imagePath,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return _TappableCard(
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEAEAF0), width: 1),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              flex: 4,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18)),
                child: Image.asset(
                  imagePath,
                  fit:   BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: fallback.withValues(alpha: 0.15),
                    child: Center(
                      child: Icon(Icons.local_drink_rounded,
                          color: fallback, size: 40),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize:   12,
                    fontWeight: FontWeight.w700,
                    color:      const Color(0xFF1A1A2E),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── TAPPABLE CARD ─────────────────────────────────────────────────────────────
class _TappableCard extends StatefulWidget {
  final Widget child;
  const _TappableCard({required this.child});

  @override
  State<_TappableCard> createState() => _TappableCardState();
}

class _TappableCardState extends State<_TappableCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;
  late final Animation<double>   _t;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:           this,
      duration:        const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 190),
    );
    _scale = Tween(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _t = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) => _ctrl.reverse(),
      onTapCancel: ()  => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder:   (_, child) => Transform.scale(
          scale: _scale.value,
          child: Stack(
            children: [
              if (_t.value > 0)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C14D4)
                              .withValues(alpha: 0.22 * _t.value),
                          blurRadius:   24 * _t.value,
                          spreadRadius: 2  * _t.value,
                          offset: Offset(0, 6 * _t.value),
                        ),
                      ],
                    ),
                  ),
                ),
              child!,
            ],
          ),
        ),
        child: widget.child,
      ),
    );
  }
}