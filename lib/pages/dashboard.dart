// FILE: lib/dashboard.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../state/profile_notifier.dart';
import '../widgets/custom_navbar.dart';
import '../pages/home_page.dart';       // was ../menu/home_page.dart
import '../pages/order_page.dart';
import '../cards/cards_page.dart';
import '../pages/stores_page.dart';     // was ../menu/stores_page.dart (check your actual path)
import '../account/profile_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int    _selectedIndex = 0;
  String _userName      = '';

  // ── Cached pages — built once so state is preserved across tab switches ──
  late final List<Widget> _pages;

  static const Color _bg       = Color(0xFFFAFAFA);
  static const Color _purple   = Color(0xFF7C14D4);
  static const Color _surface  = Color(0xFFF2EEF8);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMid  = Color(0xFF6B6B8A);

  // Cards tab index — update if your tab order ever changes
  static const int _cardsTabIndex = 2;

  @override
  void initState() {
    super.initState();

    // Build pages once, wiring the callback so HomePage can switch to Cards
    _pages = [
      HomePage(onGoToCards: _goToCards),
      const OrderPage(),
      const CardsPage(),
      const StoresPage(),
    ];

    _loadUserData();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  /// Switches the bottom nav to the Cards tab.
  void _goToCards() {
    if (_selectedIndex != _cardsTabIndex) {
      setState(() => _selectedIndex = _cardsTabIndex);
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    final int?    userId    = prefs.getInt('user_id');
    final String? userIdStr = prefs.getString('user_id_str');
    final String  userKey   = userId?.toString() ?? userIdStr ?? '';
    final String  imageKey  = userKey.isNotEmpty
        ? 'profileImagePath_$userKey'
        : 'profileImagePath';

    setState(() {
      _userName = prefs.getString('userName') ?? 'Guest';
    });

    profileImageNotifier.value = prefs.getString(imageKey);
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  String _getTodayLabel() {
    const days = [
      'Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday',
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    final bool showHeader = _selectedIndex != 3;

    return Scaffold(
      extendBody:      true,
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [

            // ── HEADER ──────────────────────────────────────────────────
            if (showHeader)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Greeting
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getTodayLabel(),
                            style: GoogleFonts.poppins(
                              fontSize:   12,
                              color:      _textMid,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$_userName! 👋',
                            style: GoogleFonts.poppins(
                              fontSize:   22,
                              fontWeight: FontWeight.w700,
                              color:      _textDark,
                              height:     1.15,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),

                    // Avatar (reactive)
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProfilePage()),
                      ).then((_) => _loadUserData()),
                      child: ValueListenableBuilder<String?>(
                        valueListenable: profileImageNotifier,
                        builder: (context, imagePath, _) {
                          final hasImage = imagePath != null &&
                              File(imagePath).existsSync();
                          return Container(
                            height: 42,
                            width:  42,
                            decoration: BoxDecoration(
                              color:  _surface,
                              shape:  BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:      _purple.withValues(alpha: 0.10),
                                  blurRadius: 8,
                                  offset:     const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: hasImage
                                  ? Image.file(
                                File(imagePath),
                                fit:    BoxFit.cover,
                                width:  42,
                                height: 42,
                              )
                                  : const Icon(
                                PhosphorIconsRegular.user,
                                color: _purple,
                                size:  22,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

            // ── PAGE CONTENT ─────────────────────────────────────────────
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: _pages,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomNavBar(
        selectedIndex: _selectedIndex,
        onTabChange:   _onItemTapped,
      ),
    );
  }
}