// FILE: lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:convert';
import 'dart:math' as math;
import '../config/app_config.dart';
import '../cart/menu_page.dart';
import 'points_page.dart';

const List<String> _kPerkNames = [
  'Buy 1, Get 1 Free',
  '10% Off All Items',
];

// ── Category → MenuPage category name mapping ─────────────────────────────────
const Map<String, String> _kCategoryMap = {
  'Lucky Classic': 'Classic Milktea',
  'Frappes':       'Frappes',
  'Iced Coffees':  'Iced Coffee',
  'Fruit Juices':  'Fruit Soda Series',
};

// ── Store list (kept in sync with StoresPage) ─────────────────────────────────
final List<Map<String, dynamic>> _kStoreLocations = [
  {'name': 'East Fairview',             'branch_id': 6,  'address': 'Dunhill Corner Winston St. East Fairview Q.C',          'image': 'assets/images/eastfairview_branch.png', 'lat': 14.7032, 'lng': 121.0695},
  {'name': 'AUF Angeles',               'branch_id': 7,  'address': 'Stall #7 JCL foodcourt, 704 Fajardo st.',               'image': 'assets/images/auf_branch.jpg',           'lat': 15.1451, 'lng': 120.5941},
  {'name': 'Robinsons Galleria Cebu',   'branch_id': 8,  'address': '3rd Floor, Robinsons Galleria Cebu',                    'image': 'assets/images/galleriacebu_branch.jpg',  'lat': 10.3061, 'lng': 123.9059},
  {'name': 'Jenra Grand Mall',          'branch_id': 9,  'address': 'Upper Ground Floor (near Jollibee Entrance)',           'image': 'assets/images/jenra_branch.png',         'lat': 15.1336, 'lng': 120.5907},
  {'name': 'Pamana Medical Center',     'branch_id': 10, 'address': 'National Highway, Calamba, Laguna',                     'image': 'assets/images/pamana_branch.jpg',        'lat': 14.2017, 'lng': 121.1565},
  {'name': 'Dahlia',                    'branch_id': 11, 'address': '#10 Dahlia Avenue, Fairview, Quezon City',              'image': 'assets/images/dahlia_branch.png',        'lat': 14.7028, 'lng': 121.0664},
  {'name': 'Misamis St., Bago Bantay',  'branch_id': 12, 'address': '43 Misamis St. Sto. Cristo, Bago Bantay',              'image': 'assets/images/misamis_branch.png',       'lat': 14.6598, 'lng': 121.0263},
  {'name': 'Pontiac',                   'branch_id': 13, 'address': 'Pontiac st. cor. Datsun st. Fairview, Quezon City',     'image': 'assets/images/pontiac_branch.png',       'lat': 14.7065, 'lng': 121.0621},
  {'name': 'QCGH',                      'branch_id': 14, 'address': 'Stall # 5 Seminary Road Project 8, Quezon City',        'image': 'assets/images/qcgh_branch.png',          'lat': 14.6669, 'lng': 121.0221},
  {'name': 'Tondo, Manila',             'branch_id': 15, 'address': '539 Perla St., Tondo, Manila',                          'image': 'assets/images/tondo_branch.png',         'lat': 14.6138, 'lng': 120.9678},
  {'name': 'Lucky Boba - Main Branch',  'branch_id': 1,  'address': '356 Vipra St., Sangandaan, Quezon City',                'image': 'assets/images/vipra_branch.png',         'lat': 14.6811, 'lng': 121.0368},
  {'name': 'Starmall Shaw Blvd.',       'branch_id': 16, 'address': 'near Kalentong Jeepney Terminal',                       'image': 'assets/images/starmall_branch.png',      'lat': 14.5826, 'lng': 121.0535},
  {'name': 'Eton Centris',              'branch_id': 17, 'address': 'Second Floor, Eton Centris Station Mall',               'image': 'assets/images/etoncentris_branch.png',   'lat': 14.6444, 'lng': 121.0375},
  {'name': 'Isetann Cubao',             'branch_id': 18, 'address': 'Ground Floor, Isetann Department Store',                'image': 'assets/images/isetann_branch.jpg',       'lat': 14.6219, 'lng': 121.0515},
  {'name': 'Candelaria, Quezon',        'branch_id': 19, 'address': 'Maharlika Highway, Candelaria',                         'image': 'assets/images/candelaria_branch.png',    'lat': 13.9272, 'lng': 121.4233},
  {'name': 'Himlayan Rd., Pasong Tamo', 'branch_id': 20, 'address': '217 Himlayan Road cor. Tandang Sora Ave.',              'image': 'assets/images/himlayanrd_branch.png',    'lat': 14.6785, 'lng': 121.0505},
  {'name': 'Lucky Boba - Bagbag',       'branch_id': 5,  'address': '657, 1116 Quirino Hwy, Novaliches',                     'image': 'assets/images/bagbag_branch.png',        'lat': 14.7000, 'lng': 121.0333},
  {'name': 'Lucky Boba - Cloverleaf',   'branch_id': 21, 'address': 'Ayala Malls Cloverleaf, QC',                            'image': 'assets/images/cloverleaf_branch.jpg',    'lat': 14.6540, 'lng': 121.0020},
  {'name': 'Ayala Malls Fairview Terraces', 'branch_id': 22, 'address': 'Upper Ground Floor, Fairview, QC',                 'image': 'assets/images/ayalateracces_branch.jpg', 'lat': 14.7340, 'lng': 121.0578},
  {'name': 'Ayala Malls Feliz',         'branch_id': 2,  'address': 'Level 4, Food Choices, Pasig City',                     'image': 'assets/images/mallfeliz_branch.jpg',     'lat': 14.6186, 'lng': 121.0963},
  {'name': 'Landmark, Trinoma',         'branch_id': 23, 'address': 'Level 1 Food Center, Landmark Supermarket',             'image': 'assets/images/landmark_branch.jpg',      'lat': 14.6534, 'lng': 121.0336},
  {'name': 'SM North Edsa',             'branch_id': 24, 'address': 'The Block Entrance, SM North Edsa',                     'image': 'assets/images/smnorth_branch.jpg',       'lat': 14.6565, 'lng': 121.0305},
  {'name': 'SM Novaliches',             'branch_id': 3,  'address': 'Ground Floor, SM Novaliches, QC',                       'image': 'assets/images/smnova_branch.jpg',        'lat': 14.7047, 'lng': 121.0346},
  {'name': 'SM San Lazaro',             'branch_id': 25, 'address': 'Lower Ground Floor, SM San Lazaro, Manila',             'image': 'assets/images/sanlazaro_branch.jpg',     'lat': 14.6158, 'lng': 120.9830},
  {'name': 'Sta. Lucia Mall',           'branch_id': 26, 'address': 'Ground Floor, Sta. Lucia East Grand Mall',              'image': 'assets/images/stalucia_branch.jpg',      'lat': 14.6190, 'lng': 121.1000},
  {'name': 'Nova Plaza Mall',           'branch_id': 27, 'address': '3rd Floor, Novaliches, Quezon City',                    'image': 'assets/images/novaplaza_branch.jpg',     'lat': 14.7214, 'lng': 121.0421},
  {'name': 'Spark Place Cubao',         'branch_id': 28, 'address': '2nd Floor, Sparks Place, Cubao, QC',                    'image': 'assets/images/sparkplace_branch.jpg',    'lat': 14.6179, 'lng': 121.0553},
];

double _calcDistance(double lat1, double lon1, double lat2, double lon2) {
  var p = 0.017453292519943295;
  var c = math.cos;
  var a = 0.5 -
      c((lat2 - lat1) * p) / 2 +
      c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
  return 12742 * math.asin(math.sqrt(a));
}

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

  bool _loadingCard     = true;
  bool _hasActiveCard   = false;
  bool _loadingPoints   = true;
  int  _luckyPoints     = 0;

  // Nearby store state
  bool                  _loadingNearby  = true;
  Map<String, dynamic>? _nearestStore;
  double                _nearestDist    = 0;

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
    await Future.wait([
      _checkActiveCard(),
      _fetchLuckyPoints(),
      _loadNearestStore(),
    ]);
    await _loadPerkUsage();
    _checkInitialBranchSelection();
  }

  Future<void> _checkInitialBranchSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final int? selectedBranchId = prefs.getInt('selected_branch_id');

    if (selectedBranchId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showBranchPicker('Menu'); // Force picker on first load
      });
    }
  }

  // ── 1. Card status ────────────────────────────────────────────────────────
  Future<void> _checkActiveCard() async {
    final prefs       = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('user_id');

    final bool cached = prefs.getBool('has_active_card') ?? false;
    if (mounted) setState(() => _hasActiveCard = cached);

    if (userId == null) {
      if (mounted) setState(() => _loadingCard = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/check-card-status/$userId'),
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;

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
        if (mounted) setState(() => _hasActiveCard = hasCard);
      }
    } catch (e) {
      debugPrint('🔍 [HomePage] card API error: $e');
    } finally {
      if (mounted) setState(() => _loadingCard = false);
    }
  }

  // ── 2. Lucky Points ───────────────────────────────────────────────────────
  Future<void> _fetchLuckyPoints() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('session_token') ?? '';

    if (token.isEmpty) {
      if (mounted) setState(() => _loadingPoints = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/points'),  // ← no userId in URL
        headers: {
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',       // ← auth token instead
        },
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final dynamic raw = data['points'] ?? 0;
        final int pts = raw is int ? raw : int.tryParse(raw.toString()) ?? 0;
        if (mounted) setState(() => _luckyPoints = pts);
      }
    } catch (e) {
      debugPrint('🔍 [HomePage] points API error: $e');
    } finally {
      if (mounted) setState(() => _loadingPoints = false);
    }
  }

  // ── 3. Nearest store ──────────────────────────────────────────────────────
  Future<void> _loadNearestStore() async {
    double userLat = 14.7040;
    double userLng = 121.0340;

    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        ).timeout(const Duration(seconds: 5));
        userLat = pos.latitude;
        userLng = pos.longitude;
      }
    } catch (_) {}

    final sorted = List<Map<String, dynamic>>.from(_kStoreLocations);
    for (var s in sorted) {
      s['_dist'] = _calcDistance(userLat, userLng, s['lat'], s['lng']);
    }
    sorted.sort((a, b) => (a['_dist'] as double).compareTo(b['_dist'] as double));

    if (mounted) {
      setState(() {
        _nearestStore  = sorted.first;
        _nearestDist   = sorted.first['_dist'] as double;
        _loadingNearby = false;
      });
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
        _usedToday..clear()..addAll(used);
        _loadingCard = false;
      });
    }
  }

  int get _remainingPerks =>
      _kPerkNames.where((n) => !(_usedToday[n] ?? false)).length;

  // ── Branch picker ─────────────────────────────────────────────────────────
  Future<void> _showBranchPicker(String categoryLabel) async {
    final String? menuCategory = _kCategoryMap[categoryLabel];
    if (menuCategory == null) return;

    double userLat = 14.7040;
    double userLng = 121.0340;

    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        ).timeout(const Duration(seconds: 5));
        userLat = pos.latitude;
        userLng = pos.longitude;
      }
    } catch (_) {}

    final sorted = List<Map<String, dynamic>>.from(_kStoreLocations);
    for (var s in sorted) {
      s['_dist'] = _calcDistance(userLat, userLng, s['lat'], s['lng']);
    }
    sorted.sort((a, b) => a['_dist'].compareTo(b['_dist']));

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BranchPickerSheet(
        categoryLabel: categoryLabel,
        menuCategory:  menuCategory,
        stores:        sorted,
      ),
    );
  }

  // ── Safe card nav helper ──────────────────────────────────────────────────
  void _goToCards() {
    if (widget.onGoToCards != null) {
      widget.onGoToCards!();
    }
  }

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
                  // ── Lucky Points card ───────────────────────────────
                  Expanded(
                    child: _StatCard(
                      label:     'Lucky Points',
                      value:     _loadingPoints ? '...' : '$_luckyPoints pts',
                      icon:      Icons.star_rounded,
                      iconColor: _orange,
                      badge:     null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PointsPage(points: _luckyPoints),
                        ),
                      ).then((_) => _fetchLuckyPoints()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // ── Card Promos card ────────────────────────────────
                  Expanded(
                    child: _StatCard(
                      label:     'Card Promos',
                      value:     _hasActiveCard
                          ? '$_remainingPerks Remaining'
                          : 'No Card',
                      icon:      Icons.card_giftcard_rounded,
                      iconColor: _purple,
                      badge:     _hasActiveCard ? null : 'Get Now',
                      onTap:     _goToCards,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── CARD PROMOS SECTION ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Card Promos',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w700, color: _textDark)),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _goToCards,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Text(
                      _hasActiveCard ? 'View card' : 'Get a card',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w600, color: _purple),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_loadingCard)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                    color: const Color(0xFFEAEAF0),
                    borderRadius: BorderRadius.circular(15)),
              ),
            )
          else if (_hasActiveCard)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _goToCards,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2EEF8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _purple.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(color: _purple, shape: BoxShape.circle),
                          child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('You have an active card!',
                                  style: GoogleFonts.poppins(
                                      fontSize: 14, fontWeight: FontWeight.w700, color: _textDark)),
                              Text('Tap to view your perks',
                                  style: GoogleFonts.poppins(fontSize: 11, color: _textMid)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: _purple, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _goToCards,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8F0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _orange.withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle),
                          child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('No promos available',
                                  style: GoogleFonts.poppins(
                                      fontSize: 14, fontWeight: FontWeight.w700, color: _textDark)),
                              Text('Avail a Lucky Boba card to unlock perks',
                                  style: GoogleFonts.poppins(fontSize: 11, color: _textMid)),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, color: _orange, size: 14),
                      ],
                    ),
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
                    fontSize: 18, fontWeight: FontWeight.w700, color: _textDark)),
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
                    fontSize: 18, fontWeight: FontWeight.w700, color: _textDark)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics:         const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _CategoryCard(
                  label:     'Lucky Classic',
                  imagePath: 'assets/images/lucky_classic.png',
                  fallback:  _orange,
                  onTap:     () => _showBranchPicker('Lucky Classic'),
                ),
                const SizedBox(width: 12),
                _CategoryCard(
                  label:     'Frappes',
                  imagePath: 'assets/images/frappe.png',
                  fallback:  const Color(0xFFAB47BC),
                  onTap:     () => _showBranchPicker('Frappes'),
                ),
                const SizedBox(width: 12),
                _CategoryCard(
                  label:     'Iced Coffees',
                  imagePath: 'assets/images/iced_coffee.png',
                  fallback:  const Color(0xFF8D6E63),
                  onTap:     () => _showBranchPicker('Iced Coffees'),
                ),
                const SizedBox(width: 12),
                _CategoryCard(
                  label:     'Fruit Juices',
                  imagePath: 'assets/images/fruit_juices.png',
                  fallback:  const Color(0xFF66BB6A),
                  onTap:     () => _showBranchPicker('Fruit Juices'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── NEARBY STORES ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Nearby Stores',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700, color: _textDark)),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _loadingNearby
                ? Container(
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFFEAEAF0),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Center(child: CircularProgressIndicator()),
            )
                : _NearbyStoreBanner(
              store: _nearestStore!,
              dist:  _nearestDist,
            ),
          ),

          const SizedBox(height: 110),
        ],
      ),
    );
  }
}

// ── NEARBY STORE BANNER ───────────────────────────────────────────────────────
class _NearbyStoreBanner extends StatelessWidget {
  final Map<String, dynamic> store;
  final double               dist;

  const _NearbyStoreBanner({required this.store, required this.dist});

  static const Color _purple = Color(0xFF7C14D4);

  @override
  Widget build(BuildContext context) {
    return _TappableCard(
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: const Color(0xFF1A1A2E),
          boxShadow: [
            BoxShadow(
              color: _purple.withValues(alpha: 0.28),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // Branch image as background
              Positioned.fill(
                child: Image.asset(
                  store['image'] as String,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF7C14D4), Color(0xFF6A0EC0)],
                      ),
                    ),
                    child: const Center(
                      child: Icon(PhosphorIconsRegular.storefront,
                          color: Colors.white54, size: 48),
                    ),
                  ),
                ),
              ),
              // Dark overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.72),
                      ],
                      stops: const [0.25, 1.0],
                    ),
                  ),
                ),
              ),
              // "NEAREST" badge top-right
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _purple,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded,
                          color: Colors.white, size: 10),
                      const SizedBox(width: 4),
                      Text(
                        '${dist.toStringAsFixed(1)} km away',
                        style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              // Store name + address + CTA bottom
              Positioned(
                left: 20, right: 20, bottom: 18,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('NEAREST BRANCH',
                              style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2)),
                          const SizedBox(height: 4),
                          Text(store['name'] as String,
                              style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  height: 1.15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(store['address'] as String,
                              style: GoogleFonts.poppins(
                                  fontSize: 10, color: Colors.white60),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text('Directions',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _purple)),
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

// ── BRANCH PICKER BOTTOM SHEET ────────────────────────────────────────────────
class _BranchPickerSheet extends StatefulWidget {
  final String                     categoryLabel;
  final String                     menuCategory;
  final List<Map<String, dynamic>> stores;

  const _BranchPickerSheet({
    required this.categoryLabel,
    required this.menuCategory,
    required this.stores,
  });

  @override
  State<_BranchPickerSheet> createState() => _BranchPickerSheetState();
}

class _BranchPickerSheetState extends State<_BranchPickerSheet> {
  static const Color _purple   = Color(0xFF7C14D4);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMid  = Color(0xFF6B6B8A);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize:     0.4,
      maxChildSize:     0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _purple.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(PhosphorIconsRegular.storefront,
                        color: _purple, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pick a Branch',
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _textDark)),
                        Text('Browsing ${widget.categoryLabel} menu',
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: _textMid)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close_rounded,
                        color: Color(0xFFAAAAAA), size: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFEAEAF0)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                itemCount: widget.stores.length,
                itemBuilder: (_, i) {
                  final store = widget.stores[i];
                  final double dist = store['_dist'] ?? 0.0;
                  return _BranchTile(
                    store:     store,
                    dist:      dist,
                    isNearest: i == 0,
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      if (store['branch_id'] != null) {
                        await prefs.setInt('selected_branch_id', store['branch_id'] as int);
                        await prefs.setString('selected_branch_name', store['name'] as String);
                      }
                      
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MenuPage(
                            selectedStore:   store['name'],
                            initialCategory: widget.menuCategory,
                            branchId:        store['branch_id'] as int?,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── BRANCH TILE ───────────────────────────────────────────────────────────────
class _BranchTile extends StatelessWidget {
  final Map<String, dynamic> store;
  final double               dist;
  final bool                 isNearest;
  final VoidCallback         onTap;

  const _BranchTile({
    required this.store,
    required this.dist,
    required this.isNearest,
    required this.onTap,
  });

  static const Color _purple   = Color(0xFF7C14D4);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMid  = Color(0xFF6B6B8A);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isNearest
                ? _purple.withValues(alpha: 0.35)
                : const Color(0xFFEAEAF0),
            width: isNearest ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                store['image'],
                width: 52, height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 52, height: 52,
                  color: const Color(0xFFF2EEF8),
                  child: const Icon(PhosphorIconsRegular.storefront,
                      color: _purple, size: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(store['name'],
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _textDark),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (isNearest) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _purple.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('NEAREST',
                              style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: _purple,
                                  letterSpacing: 0.5)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(store['address'],
                      style: GoogleFonts.poppins(fontSize: 10, color: _textMid),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${dist.toStringAsFixed(1)} km',
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueAccent)),
                const SizedBox(height: 4),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 12, color: Color(0xFFAAAAAA)),
              ],
            ),
          ],
        ),
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
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 16, 10, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEAEAF0), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A2E))),
                const SizedBox(height: 2),
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: const Color(0xFF6B6B8A),
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              top: -9, right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C14D4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(badge!,
                    style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
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
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox()),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(subTitle.toUpperCase(),
                            style: GoogleFonts.poppins(
                                fontSize: 9,
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 4),
                        Text(title,
                            style: GoogleFonts.poppins(
                                fontSize: 22,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                height: 1.15)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(cta,
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF7C14D4))),
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
  final String       label;
  final String       imagePath;
  final Color        fallback;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.label,
    required this.imagePath,
    required this.fallback,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _TappableCard(
      onTap: onTap,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEAEAF0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              flex: 4,
              child: ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(18)),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, _, _) => Container(
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
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A2E))),
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
  final Widget        child;
  final VoidCallback? onTap;
  const _TappableCard({required this.child, this.onTap});

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
      onTap:       widget.onTap,
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) => _ctrl.reverse(),
      onTapCancel: ()  => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.scale(
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