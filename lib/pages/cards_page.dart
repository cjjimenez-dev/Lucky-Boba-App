// FILE: lib/pages/cards_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'card_purchase_page.dart';
import '../config/app_config.dart';

class CardsPage extends StatefulWidget {
  const CardsPage({super.key});

  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage> {
  static const Color _purple   = Color(0xFF7C14D4);
  static const Color _bg       = Color(0xFFFAFAFA);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMid  = Color(0xFF6B6B8A);

  bool _isLoading     = true;
  bool _hasActiveCard = false;
  Map<String, dynamic>? _activeCardData;

  final List<Map<String, dynamic>> cardList = const [
    {'id': 1, 'title': 'Daily Card',      'image': 'assets/images/normal_card.png',     'price': 'P300'},
    {'id': 2, 'title': 'Valentines Card', 'image': 'assets/images/valentines_card.png', 'price': 'P300'},
    {'id': 3, 'title': 'Students Card',   'image': 'assets/images/student_card.png',    'price': 'P300'},
    {'id': 4, 'title': 'Summer Card',     'image': 'assets/images/summer_card.png',     'price': 'P300'},
    {'id': 5, 'title': 'Birthday Card',   'image': 'assets/images/birthday_card.png',   'price': 'P300'},
  ];

  @override
  void initState() {
    super.initState();
    _checkSubscription();
  }

  Future<void> _checkSubscription() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final prefs       = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('user_id');

    // ── ✅ Step 1: Apply SharedPreferences immediately so UI never flashes wrong state
    final bool cachedHasCard = prefs.getBool('has_active_card') ?? false;
    final int? cachedCardId  = prefs.getInt('card_id');

    if (cachedHasCard && cachedCardId != null) {
      final Map<String, dynamic>? cachedCard = cardList.cast<Map<String, dynamic>?>().firstWhere(
            (c) => c?['id'] == cachedCardId,
        orElse: () => cardList[0],
      );
      if (mounted) {
        setState(() {
          _hasActiveCard  = true;
          _activeCardData = cachedCard;
          _isLoading      = false;
        });
      }
    }

    // ── ✅ Step 2: Still verify with API in background to stay in sync
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/check-card-status/$userId'),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data         = jsonDecode(response.body);
        final bool hasCard = data['has_active_card'] == true;

        Map<String, dynamic>? foundCard;
        if (hasCard) {
          final int? activeCardId = data['card_id'] is int
              ? data['card_id']
              : int.tryParse(data['card_id'].toString());

          foundCard = cardList.firstWhere(
                (c) => c['id'] == activeCardId,
            orElse: () => cardList[0],
          );

          // ── ✅ Keep SharedPreferences in sync with API response
          await prefs.setBool('has_active_card', true);
          if (activeCardId != null) await prefs.setInt('card_id', activeCardId);
        } else {
          // Card expired or revoked — clear cache
          await prefs.setBool('has_active_card', false);
          await prefs.remove('card_id');
        }

        if (mounted) {
          setState(() {
            _hasActiveCard  = hasCard;
            _activeCardData = foundCard;
            _isLoading      = false;
          });
        }
      } else {
        // API error — keep showing cached state, just stop loading
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Card status check failed: $e');
      // Network error — keep showing cached state, just stop loading
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showBirthdayDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:  _purple.withValues(alpha: 0.10),
                shape:  BoxShape.circle,
              ),
              child: Icon(PhosphorIconsRegular.cake,
                  color: _purple, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Birthday Card',
              style: GoogleFonts.poppins(
                color:      _textDark,
                fontWeight: FontWeight.w700,
                fontSize:   16,
              ),
            ),
          ],
        ),
        content: Text(
          'Please present a valid ID with your birth date to the cashier when claiming this card.',
          style: GoogleFonts.poppins(
              color: _textMid, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.poppins(
                    color: _textMid, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _goToPurchase(5, 'Birthday Card',
                  'assets/images/birthday_card.png', 'P300');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              elevation:       0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('I Understand',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _goToPurchase(
      int id, String title, String img, String price) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CardPurchasePage(
          cardId:        id,
          cardTitle:     title,
          cardImagePath: img,
          cardPrice:     price,
        ),
      ),
    ).then((_) => _checkSubscription());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: _bg,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF7C14D4)),
        ),
      );
    }

    if (_hasActiveCard && _activeCardData != null) {
      return CardPurchasePage(
        cardId:        _activeCardData!['id'],
        cardTitle:     _activeCardData!['title'],
        cardImagePath: _activeCardData!['image'],
        cardPrice:     _activeCardData!['price'],
        isOwned:       true,
      );
    }

    final int currentMonth = DateTime.now().month;

    return Container(
      color: _bg,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose Your Card',
                style: GoogleFonts.poppins(
                  fontSize:   22,
                  fontWeight: FontWeight.w700,
                  color:      _textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap a card to flip it and see the design',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: _textMid),
              ),
              const SizedBox(height: 24),

              ...cardList.map((card) {
                bool isAvailable = true;
                if (card['title'] == 'Valentines Card')
                  isAvailable = currentMonth == 2;
                if (card['title'] == 'Summer Card')
                  isAvailable =
                      currentMonth >= 3 && currentMonth <= 5;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: FlipCardItem(
                    title:       card['title'],
                    imagePath:   card['image'],
                    price:       card['price'],
                    isAvailable: isAvailable,
                    onBuyPressed: () {
                      if (card['title'] == 'Birthday Card') {
                        _showBirthdayDialog(context);
                      } else {
                        _goToPurchase(card['id'], card['title'],
                            card['image'], card['price']);
                      }
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ── FLIP CARD ITEM ────────────────────────────────────────────────────────────
class FlipCardItem extends StatefulWidget {
  final String        title;
  final String        imagePath;
  final String        price;
  final bool          isAvailable;
  final VoidCallback  onBuyPressed;

  const FlipCardItem({
    super.key,
    required this.title,
    required this.imagePath,
    required this.price,
    required this.isAvailable,
    required this.onBuyPressed,
  });

  @override
  State<FlipCardItem> createState() => _FlipCardItemState();
}

class _FlipCardItemState extends State<FlipCardItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double>   _animation;
  bool _isFlipped = false;

  static const Color _purple   = Color(0xFF7C14D4);
  static const Color _textDark = Color(0xFF1A1A2E);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _animation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (!mounted) return;
    setState(() => _isFlipped = !_isFlipped);
    _isFlipped ? _controller.forward() : _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Flippable card ──────────────────────────────────────────────
        GestureDetector(
          onTap: _toggleFlip,
          child: Container(
            height: 200,
            width:  double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color:      _purple.withValues(alpha: 0.15),
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
                    child: Opacity(
                      opacity: widget.isAvailable ? 1.0 : 0.45,
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          final angle  = _animation.value * math.pi;
                          final isBack = angle > math.pi / 2;
                          return Transform(
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(angle),
                            alignment: Alignment.center,
                            child: isBack
                                ? Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.rotationY(math.pi),
                              child: Image.asset(
                                  'assets/images/back_card.png',
                                  fit: BoxFit.cover),
                            )
                                : Image.asset(widget.imagePath,
                                fit: BoxFit.cover),
                          );
                        },
                      ),
                    ),
                  ),
                  if (!widget.isAvailable)
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color:        Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'COMING SOON',
                            style: GoogleFonts.poppins(
                              fontSize:      14,
                              fontWeight:    FontWeight.w700,
                              color:         Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top:   12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color:        Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flip_rounded,
                              color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text('Tap to flip',
                              style: GoogleFonts.poppins(
                                fontSize:   10,
                                color:      Colors.white,
                                fontWeight: FontWeight.w500,
                              )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ── Card info row ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEAEAF0), width: 1),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset:     const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: GoogleFonts.poppins(
                          fontSize:   15,
                          fontWeight: FontWeight.w700,
                          color:      _textDark,
                        )),
                    Text(widget.price,
                        style: GoogleFonts.poppins(
                          fontSize:   13,
                          color:      _purple,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
              GestureDetector(
                onTap: widget.isAvailable ? widget.onBuyPressed : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: widget.isAvailable
                        ? _purple
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Buy',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize:   13,
                      color: widget.isAvailable
                          ? Colors.white
                          : Colors.grey[500],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}