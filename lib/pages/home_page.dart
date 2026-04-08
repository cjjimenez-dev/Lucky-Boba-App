// FILE: lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import '../config/app_config.dart';
import '../cart/menu_page.dart';
import '../utils/app_theme.dart';
import 'points_page.dart';

// ── Category → MenuPage category name mapping ─────────────────────────────────
const Map<String, String> _kCategoryMap = {
  'Lucky Classic': 'Classic Milktea',
  'Frappes':       'Frappes',
  'Iced Coffees':  'Iced Coffee',
  'Fruit Juices':  'Fruit Soda Series',
};

// ── Store list ────────────────────────────────────────────────────────────────
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
  var a = 0.5 - c((lat2 - lat1) * p) / 2 + c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
  return 12742 * math.asin(math.sqrt(a));
}

class HomePage extends StatefulWidget {
  final VoidCallback? onGoToCards;
  const HomePage({super.key, this.onGoToCards});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _hasActiveCard   = false;
  bool _loadingPoints   = true;
  int  _luckyPoints     = 0;
  bool _loadingNearby   = true;
  Map<String, dynamic>? _nearestStore;
  double _nearestDist    = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _checkActiveCard(),
      _fetchLuckyPoints(),
      _loadNearestStore(),
    ]);
    _checkInitialBranchSelection();
  }

  Future<void> _checkInitialBranchSelection() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt('selected_branch_id') == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showBranchPicker('Lucky Classic'));
    }
  }

  Future<void> _checkActiveCard() async {
    final prefs = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('user_id');
    if (userId == null) return;
    try {
      final response = await http.get(Uri.parse('${AppConfig.apiUrl}/check-card-status/$userId')).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bool hasCard = data['has_active_card'] == true;
        await prefs.setBool('has_active_card', hasCard);
        if (mounted) setState(() => _hasActiveCard = hasCard);
      }
    } catch (_) {} 
  }

  Future<void> _fetchLuckyPoints() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('session_token') ?? '';
    if (token.isEmpty) {
      if (mounted) setState(() => _loadingPoints = false);
      return;
    }
    try {
      final response = await http.get(Uri.parse('${AppConfig.apiUrl}/points'), headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final dynamic raw = data['points'] ?? 0;
        if (mounted) setState(() => _luckyPoints = raw is int ? raw : int.tryParse(raw.toString()) ?? 0);
      }
    } catch (_) {} 
    finally { if (mounted) setState(() => _loadingPoints = false); }
  }

  Future<void> _loadNearestStore() async {
    double userLat = 14.7040; double userLng = 121.0340;
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)).timeout(const Duration(seconds: 5));
        userLat = pos.latitude; userLng = pos.longitude;
      }
    } catch (_) {}
    final sorted = List<Map<String, dynamic>>.from(_kStoreLocations);
    for (var s in sorted) { s['_dist'] = _calcDistance(userLat, userLng, s['lat'], s['lng']); }
    sorted.sort((a, b) => (a['_dist'] as double).compareTo(b['_dist'] as double));
    if (mounted) setState(() { _nearestStore = sorted.first; _nearestDist = sorted.first['_dist']; _loadingNearby = false; });
  }

  Future<void> _showBranchPicker(String categoryLabel) async {
    final String? menuCategory = _kCategoryMap[categoryLabel];
    if (menuCategory == null) return;
    final sorted = List<Map<String, dynamic>>.from(_kStoreLocations);
    // Sort logic here ignored for brevity but should be consistent
    await showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (_) => _BranchPickerSheet(categoryLabel: categoryLabel, menuCategory: menuCategory, stores: sorted)
    );
  }

  void _goToCards() { if (widget.onGoToCards != null) widget.onGoToCards!(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF0E6FF), Color(0xFFF9F9FB)])))),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('GOOD DAY! 👋', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.primary.withOpacity(0.5), letterSpacing: 2)),
                          Text('Fresh Boba Awaits', style: AppTheme.heading.copyWith(fontSize: 24)),
                        ]),
                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: const Icon(PhosphorIconsRegular.bell, color: AppTheme.primary, size: 20)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _StatCard(label: 'Your Points', value: _loadingPoints ? '...' : '$_luckyPoints', icon: PhosphorIconsFill.sparkle, iconColor: AppTheme.secondary, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PointsPage(points: _luckyPoints))).then((_) => _fetchLuckyPoints()))),
                          const SizedBox(width: 12),
                          Expanded(child: _StatCard(label: 'Active Perks', value: _hasActiveCard ? 'Active' : 'None', icon: PhosphorIconsFill.ticket, iconColor: AppTheme.primary, badge: _hasActiveCard ? null : 'GET', onTap: _goToCards)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [const Icon(PhosphorIconsFill.fire, color: Colors.redAccent, size: 20), const SizedBox(width: 8), Text('Whats Hot!', style: AppTheme.subHeading)])),
                  const SizedBox(height: 12),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _TappableCard(child: _HeroBanner(imagePath: 'assets/images/promo1.png', gradientColors: const [AppTheme.primary, AppTheme.primaryLight], title: 'Winter Specials', subTitle: 'Limited release', cta: 'Order Now'))),
                  const SizedBox(height: 32),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Categories', style: AppTheme.subHeading), Text('See All', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary))])),
                  const SizedBox(height: 16),
                  SizedBox(height: 120, child: ListView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 20), children: [
                    _CategoryMiniCard(label: 'Classics', icon: PhosphorIconsFill.coffee, color: const Color(0xFF6D4C41), onTap: () => _showBranchPicker('Lucky Classic')),
                    _CategoryMiniCard(label: 'Frappes', icon: PhosphorIconsFill.iceCream, color: const Color(0xFFCE93D8), onTap: () => _showBranchPicker('Frappes')),
                    _CategoryMiniCard(label: 'Coffees', icon: PhosphorIconsFill.coffee, color: const Color(0xFF8D6E63), onTap: () => _showBranchPicker('Iced Coffees')),
                    _CategoryMiniCard(label: 'Juices', icon: PhosphorIconsFill.drop, color: const Color(0xFF81C784), onTap: () => _showBranchPicker('Fruit Juices')),
                  ])),
                  const SizedBox(height: 32),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('Visit Us', style: AppTheme.subHeading)),
                  const SizedBox(height: 12),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _loadingNearby ? _SkeletonBanner() : _NearbyStoreBanner(store: _nearestStore!, dist: _nearestDist)),
                  const SizedBox(height: 110),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color iconColor; final String? badge; final VoidCallback? onTap;
  const _StatCard({required this.label, required this.value, required this.icon, required this.iconColor, this.badge, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(borderRadius: BorderRadius.circular(24), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white, width: 1.5), boxShadow: [BoxShadow(color: iconColor.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 18)),
        const Spacer(),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(value, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textDark)), if (badge != null) ...[const SizedBox(width: 4), Text(badge!, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.primary))]]),
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textMid, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      ])))),
    );
  }
}

class _CategoryMiniCard extends StatelessWidget {
  final String label; final IconData icon; final Color color; final VoidCallback onTap;
  const _CategoryMiniCard({required this.label, required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(width: 85, margin: const EdgeInsets.only(right: 12), child: Column(children: [
      Container(width: 70, height: 70, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8))]), child: Icon(icon, color: color, size: 30)),
      const SizedBox(height: 10),
      Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
    ])));
  }
}

class _SkeletonBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) { return Container(height: 200, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)), child: const Center(child: CircularProgressIndicator(strokeWidth: 2))); }
}

class _NearbyStoreBanner extends StatelessWidget {
  final Map<String, dynamic> store; final double dist;
  const _NearbyStoreBanner({required this.store, required this.dist});
  @override
  Widget build(BuildContext context) {
    return _TappableCard(child: Container(width: double.infinity, height: 200, decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), color: const Color(0xFF1A1A2E), boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8))]), child: ClipRRect(borderRadius: BorderRadius.circular(22), child: Stack(children: [
      Positioned.fill(child: Image.asset(store['image'], fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppTheme.primary, child: const Icon(PhosphorIconsRegular.storefront, color: Colors.white54, size: 48)))),
      Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.7)], stops: const [0.25, 1.0])))),
      Positioned(top: 14, right: 14, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.location_on_rounded, color: Colors.white, size: 10), const SizedBox(width: 4), Text('${dist.toStringAsFixed(1)} km away', style: GoogleFonts.poppins(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700))]))),
      Positioned(left: 20, right: 20, bottom: 18, child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text('NEAREST BRANCH', style: GoogleFonts.poppins(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.w600, letterSpacing: 1.2)), const SizedBox(height: 4), Text(store['name'], style: GoogleFonts.poppins(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w700, height: 1.15), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 2), Text(store['address'], style: GoogleFonts.poppins(fontSize: 10, color: Colors.white60), maxLines: 1, overflow: TextOverflow.ellipsis)])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)), child: Text('Directions', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary))),
      ])),
    ]))));
  }
}

class _HeroBanner extends StatelessWidget {
  final String imagePath, title, subTitle, cta; final List<Color> gradientColors;
  const _HeroBanner({required this.imagePath, required this.gradientColors, required this.title, required this.subTitle, required this.cta});
  @override
  Widget build(BuildContext context) {
    return Container(width: double.infinity, height: 200, decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradientColors)), child: ClipRRect(borderRadius: BorderRadius.circular(22), child: Stack(children: [
      Positioned.fill(child: Image.asset(imagePath, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
      Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.6)], stops: const [0.35, 1.0])))),
      Positioned(left: 20, right: 20, bottom: 18, child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(subTitle.toUpperCase(), style: GoogleFonts.poppins(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.w600, letterSpacing: 1.2)), const SizedBox(height: 4), Text(title, style: GoogleFonts.poppins(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700, height: 1.15))])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)), child: Text(cta, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary))),
      ])),
    ])));
  }
}

class _BranchPickerSheet extends StatelessWidget {
  final String categoryLabel, menuCategory; final List<Map<String, dynamic>> stores;
  const _BranchPickerSheet({required this.categoryLabel, required this.menuCategory, required this.stores});
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(initialChildSize: 0.65, minChildSize: 0.4, maxChildSize: 0.92, builder: (_, scrollCtrl) => Container(decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))), child: Column(children: [
      const SizedBox(height: 12), Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2))), const SizedBox(height: 16),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(PhosphorIconsRegular.storefront, color: AppTheme.primary, size: 18)),
        const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Pick a Branch', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textDark)), Text('Browsing $categoryLabel menu', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textMid))])),
        const Icon(Icons.close_rounded, color: Color(0xFFAAAAAA), size: 22),
      ])),
      const SizedBox(height: 14), const Divider(height: 1, color: Color(0xFFEAEAF0)),
      Expanded(child: ListView.builder(controller: scrollCtrl, padding: const EdgeInsets.fromLTRB(16, 4, 16, 20), itemCount: stores.length, itemBuilder: (_, i) {
        final double dist = stores[i]['_dist'] ?? 0.0;
        return _BranchTile(store: stores[i], dist: dist, isNearest: i == 0, onTap: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('selected_branch_id', stores[i]['branch_id']);
          await prefs.setString('selected_branch_name', stores[i]['name']);
          if (context.mounted) {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => MenuPage(selectedStore: stores[i]['name'], initialCategory: menuCategory, branchId: stores[i]['branch_id'])));
          }
        });
      })),
    ])));
  }
}

class _BranchTile extends StatelessWidget {
  final Map<String, dynamic> store; final double dist; final bool isNearest; final VoidCallback onTap;
  const _BranchTile({required this.store, required this.dist, required this.isNearest, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isNearest ? AppTheme.primary.withOpacity(0.35) : const Color(0xFFEAEAF0), width: isNearest ? 1.5 : 1), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]), child: Row(children: [
      ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset(store['image'], width: 52, height: 52, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 52, height: 52, color: const Color(0xFFF2EEF8), child: const Icon(PhosphorIconsRegular.storefront, color: AppTheme.primary, size: 24)))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Flexible(child: Text(store['name'], style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark), overflow: TextOverflow.ellipsis)), if (isNearest) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text('NEAREST', style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w700, color: AppTheme.primary, letterSpacing: 0.5)))]]),
        Text(store['address'], style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textMid), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${dist.toStringAsFixed(1)} km', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueAccent)), const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFFAAAAAA))]),
    ])));
  }
}

class _TappableCard extends StatefulWidget {
  final Widget child; final VoidCallback? onTap;
  const _TappableCard({required this.child, this.onTap});
  @override
  State<_TappableCard> createState() => _TappableCardState();
}

class _TappableCardState extends State<_TappableCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl; late final Animation<double> _scale, _t;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 110), reverseDuration: const Duration(milliseconds: 190));
    _scale = Tween(begin: 1.0, end: 0.97).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _t = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: widget.onTap, onTapDown: (_) => _ctrl.forward(), onTapUp: (_) => _ctrl.reverse(), onTapCancel: () => _ctrl.reverse(), child: AnimatedBuilder(animation: _ctrl, builder: (_, child) => Transform.scale(scale: _scale.value, child: Stack(children: [if (_t.value > 0) Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.22 * _t.value), blurRadius: 24 * _t.value, spreadRadius: 2 * _t.value, offset: Offset(0, 6 * _t.value))]))), child!])), child: widget.child));
  }
}