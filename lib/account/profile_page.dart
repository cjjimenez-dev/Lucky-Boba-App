// FILE: lib/account/profile_page.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../state/profile_notifier.dart';
import '../auth/login.dart';
import 'order_history_page.dart';
import 'address_book_page.dart';
import 'notifications_page.dart';
import 'contact_us_page.dart';
import 'legal_page.dart';
import 'language_page.dart';
import 'account_settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color _purple   = Color(0xFF7C14D4);
  static const Color _orange   = Color(0xFFFF8C00);
  static const Color _bg       = Color(0xFFFAFAFA);
  static const Color _surface  = Color(0xFFF2EEF8);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMid  = Color(0xFF6B6B8A);

  static const Set<String> _adminRoles = {
    'superadmin',
    'branch_manager',
    'cashier',
  };

  String  _userName         = 'Loading...';
  String  _userRole         = 'customer';
  String  _userEmail        = '';
  String? _profileImagePath;
  bool    _isUploading      = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();

    final int?    userId    = prefs.getInt('user_id');
    final String? userIdStr = prefs.getString('user_id_str');
    final String  userKey   = userId?.toString() ?? userIdStr ?? '';
    final String  imageKey  =
    userKey.isNotEmpty ? 'profileImagePath_$userKey' : 'profileImagePath';

    setState(() {
      _userName         = prefs.getString('userName') ?? 'Guest User';
      _userRole         = prefs.getString('userRole') ?? 'customer';
      _userEmail        = prefs.getString('userEmail') ?? '';
      _profileImagePath = prefs.getString(imageKey);
    });

    profileImageNotifier.value = _profileImagePath;
  }

  // ── Update display name — saves to DB then updates local prefs ────────────
  Future<void> _showEditUsernameDialog() async {
    await showDialog(
      context: context,
      builder: (_) => _EditNameDialog(
        initialName: _userName,
        onSave:      _updateDisplayName,
      ),
    );
  }

  /// Calls PUT /api/user/name, then updates SharedPreferences on success.
  Future<void> _updateDisplayName(String newName) async {
    final prefs = await SharedPreferences.getInstance();

    // Check both common token keys just to be safe
    final String? token = prefs.getString('token') ?? prefs.getString('session_token');
    debugPrint('🔑 Token being sent: $token');

    // ── Optimistic update — show change immediately ───────────────────
    if (mounted) setState(() => _userName = newName);

    try {
      final response = await http.put(
        Uri.parse('${AppConfig.apiUrl}/user/name'),
        headers: <String, String>{ // <-- Fixed map typing here
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'name': newName}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // ── Persist locally only after DB confirms success ────────────
        await prefs.setString('userName', newName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Display name updated!',
                  style: GoogleFonts.poppins(fontSize: 13)),
              backgroundColor: _purple,
              behavior:        SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else {
        // ── Roll back the optimistic update on failure ────────────────
        final oldName = prefs.getString('userName') ?? _userName;
        if (mounted) setState(() => _userName = oldName);

        final body    = jsonDecode(response.body);
        final message = body['message'] ?? 'Failed to update name';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message,
                  style: GoogleFonts.poppins(fontSize: 13)),
              backgroundColor: Colors.redAccent,
              behavior:        SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (_) {
      // ── Roll back on network error ────────────────────────────────
      final oldName = prefs.getString('userName') ?? _userName;
      if (mounted) setState(() => _userName = oldName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot reach server — check your Wi-Fi',
                style: GoogleFonts.poppins(fontSize: 13)),
            backgroundColor: Colors.redAccent,
            behavior:        SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // ── Open Admin Panel in browser ───────────────────────────────────────────
  Future<void> _openAdminPanel() async {
    final Uri url = Uri.parse('https://luckybobastores.com');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open Admin Panel',
                style: GoogleFonts.poppins(fontSize: 13)),
            backgroundColor: Colors.red,
            behavior:        SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source:       source,
        maxWidth:     512,
        maxHeight:    512,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isUploading = true);

      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token') ?? prefs.getString('session_token');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.apiUrl}/user/avatar'),
      );

      request.headers.addAll({
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });

      request.files.add(await http.MultipartFile.fromPath('image', picked.path));

      debugPrint('🚀 Sending image to server...');
      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      // 🚨 ADDED: Print the exact response from Laravel
      debugPrint('👀 UPLOAD STATUS CODE: ${response.statusCode}');
      debugPrint('👀 UPLOAD RESPONSE BODY: ${response.body}');

      if (response.statusCode == 200) {
        final int?    userId    = prefs.getInt('user_id');
        final String? userIdStr = prefs.getString('user_id_str');
        final String  userKey   = userId?.toString() ?? userIdStr ?? '';
        final String  imageKey  = userKey.isNotEmpty ? 'profileImagePath_$userKey' : 'profileImagePath';

        await prefs.setString(imageKey, picked.path);
        profileImageNotifier.value = picked.path;

        if (mounted) {
          setState(() {
            _profileImagePath = picked.path;
            _isUploading      = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Profile picture updated!', style: GoogleFonts.poppins(fontSize: 13)),
              backgroundColor: _purple,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else {
        if (mounted) setState(() => _isUploading = false);

        // 🚨 ADDED: Safely handle the error message even if Laravel sends HTML
        String errorMessage = 'Failed to upload image (Code: ${response.statusCode})';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded['message'] != null) errorMessage = decoded['message'];
        } catch (e) {
          debugPrint('⚠️ Could not decode JSON. Server likely threw a 500 error.');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot reach server. Check your connection.'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
        );
      }
      debugPrint('❌ Image upload error: $e');
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();

    final bool onboardingDone = prefs.getBool('onboarding_done') ?? true;

    final Map<String, String> savedImages = {};
    final Set<String> allKeys = prefs.getKeys();
    for (final key in allKeys) {
      if (key.startsWith('profileImagePath_')) {
        final val = prefs.getString(key);
        if (val != null) savedImages[key] = val;
      }
    }

    final Map<String, bool> savedTerms = {};
    for (final key in allKeys) {
      if (key.startsWith('has_accepted_terms_')) {
        final val = prefs.getBool(key);
        if (val != null) savedTerms[key] = val;
      }
    }

    await prefs.clear();

    await prefs.setBool('onboarding_done', onboardingDone);
    for (final entry in savedImages.entries) {
      await prefs.setString(entry.key, entry.value);
    }
    for (final entry in savedTerms.entries) {
      await prefs.setBool(entry.key, entry.value);
    }

    profileImageNotifier.value = null;

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder:        (_, __, ___) => const LoginPage(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
          (route) => false,
    );
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width:  40,
                  height: 4,
                  decoration: BoxDecoration(
                    color:        const Color(0xFFEAEAF0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Update Profile Photo',
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _textDark)),
              const SizedBox(height: 16),
              _sourceOption(
                icon:  Icons.camera_alt_rounded,
                label: 'Take a Photo',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 10),
              _sourceOption(
                icon:  Icons.photo_library_rounded,
                label: 'Choose from Gallery',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_profileImagePath != null) ...[
                const SizedBox(height: 10),
                _sourceOption(
                  icon:  Icons.delete_outline_rounded,
                  label: 'Remove Photo',
                  color: Colors.red,
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    final int?    userId    = prefs.getInt('user_id');
                    final String? userIdStr = prefs.getString('user_id_str');
                    final String  userKey   =
                        userId?.toString() ?? userIdStr ?? '';
                    final String  imageKey  = userKey.isNotEmpty
                        ? 'profileImagePath_$userKey'
                        : 'profileImagePath';

                    await prefs.remove(imageKey);
                    profileImageNotifier.value = null;
                    setState(() => _profileImagePath = null);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceOption({
    required IconData     icon,
    required String       label,
    required VoidCallback onTap,
    Color?                color,
  }) {
    final c = color ?? _textDark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color != null
              ? Colors.red.withValues(alpha: 0.06)
              : _surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(width: 14),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String displayEmail = _userEmail.isNotEmpty
        ? _userEmail
        : '${_userName.toLowerCase().replaceAll(' ', '')}@luckyboba.com';

    final bool isAdmin = _adminRoles.contains(_userRole);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── App Bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width:  40,
                      height: 40,
                      decoration: const BoxDecoration(
                          color: _surface, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: _purple),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('My Profile',
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _textDark)),
                  ),
                ],
              ),
            ),

            // ── Scrollable body ───────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                child: Column(
                  children: [

                    // ── Profile hero card ─────────────────────────────
                    Container(
                      width:   double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_purple, _purple.withValues(alpha: 0.80)],
                          begin:  Alignment.topLeft,
                          end:    Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          // ── Avatar ────────────────────────────────
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width:  96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    width: 2.5,
                                  ),
                                ),
                                child: ClipOval(
                                  child: _isUploading
                                      ? const Center(
                                      child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2))
                                      : _profileImagePath != null &&
                                      File(_profileImagePath!)
                                          .existsSync()
                                      ? Image.file(
                                    File(_profileImagePath!),
                                    fit:    BoxFit.cover,
                                    width:  96,
                                    height: 96,
                                  )
                                      : Icon(PhosphorIconsRegular.user,
                                      color: Colors.white, size: 44),
                                ),
                              ),
                              GestureDetector(
                                onTap: _showImageSourceSheet,
                                child: Container(
                                  width:  30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: _orange,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 14),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // ── Tappable name with edit icon ──────────
                          GestureDetector(
                            onTap: _showEditUsernameDialog,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    _userName,
                                    style: GoogleFonts.poppins(
                                      fontSize:   20,
                                      fontWeight: FontWeight.w800,
                                      color:      Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                    overflow:  TextOverflow.ellipsis,
                                    maxLines:  2,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.20),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    color: Colors.white,
                                    size:  12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 2),
                          Text(
                            displayEmail,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color:    Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ── Role badge ────────────────────────────
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              _userRole[0].toUpperCase() +
                                  _userRole.substring(1),
                              style: GoogleFonts.poppins(
                                fontSize:   12,
                                fontWeight: FontWeight.w600,
                                color:      Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── ADMIN PANEL BUTTON (staff only) ───────────────
                    if (isAdmin) ...[
                      GestureDetector(
                        onTap: _openAdminPanel,
                        child: Container(
                          width:   double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF4A0A8A),
                                Color(0xFF7C14D4),
                              ],
                              begin: Alignment.topLeft,
                              end:   Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color:      const Color(0xFF7C14D4)
                                    .withValues(alpha: 0.30),
                                blurRadius: 16,
                                offset:     const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.admin_panel_settings_rounded,
                                  color: Colors.white,
                                  size:  22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Admin Panel',
                                      style: GoogleFonts.poppins(
                                        fontSize:   14,
                                        fontWeight: FontWeight.w700,
                                        color:      Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'Open POS management dashboard',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.white
                                            .withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.open_in_new_rounded,
                                color: Colors.white,
                                size:  18,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Account section ───────────────────────────────
                    _sectionLabel('Account'),
                    const SizedBox(height: 10),
                    _menuCard([
                      _MenuTileData(
                        icon:     PhosphorIconsRegular.pencilSimple,
                        title:    'Edit Display Name',
                        subtitle: _userName,
                        onTap:    _showEditUsernameDialog,
                      ),
                      _MenuTileData(
                        icon:     PhosphorIconsRegular.gear,
                        title:    'Account Settings',
                        subtitle: 'Email, password, phone & more',
                        onTap:    () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const AccountSettingsPage())),
                      ),
                      _MenuTileData(
                        icon:     PhosphorIconsRegular.mapPin,
                        title:    'Address Book',
                        subtitle: 'Manage your saved addresses',
                        onTap:    () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const AddressBookPage())),
                      ),
                      _MenuTileData(
                        icon:     PhosphorIconsRegular.receipt,
                        title:    'Order History',
                        subtitle: 'View your past orders',
                        onTap:    () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const OrderHistoryPage())),
                      ),
                      _MenuTileData(
                        icon:     PhosphorIconsRegular.bell,
                        title:    'Notifications',
                        subtitle: 'Manage alerts & updates',
                        onTap:    () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const NotificationsPage())),
                      ),
                      _MenuTileData(
                        icon:     PhosphorIconsRegular.translate,
                        title:    'Language',
                        subtitle: 'English',
                        onTap:    () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const LanguagePage())),
                      ),
                    ]),

                    const SizedBox(height: 16),

                    // ── Support section ───────────────────────────────
                    _sectionLabel('Support'),
                    const SizedBox(height: 10),
                    _menuCard([
                      _MenuTileData(
                        icon:  PhosphorIconsRegular.phoneCall,
                        title: 'Contact Us',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const ContactUsPage())),
                      ),
                      _MenuTileData(
                        icon:  PhosphorIconsRegular.shieldCheck,
                        title: 'Privacy Policy',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const LegalPage(type: LegalType.privacy))),
                      ),
                      _MenuTileData(
                        icon:  PhosphorIconsRegular.fileText,
                        title: 'Terms & Conditions',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const LegalPage(type: LegalType.terms))),
                      ),
                    ]),

                    const SizedBox(height: 16),

                    // ── Logout button ─────────────────────────────────
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18)),
                            title: Text('Log Out',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    color: _textDark)),
                            content: Text(
                              'Are you sure you want to log out?',
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: _textMid),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Cancel',
                                    style: GoogleFonts.poppins(
                                        color: _textMid,
                                        fontWeight: FontWeight.w600)),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _logout();
                                },
                                child: Text('Log Out',
                                    style: GoogleFonts.poppins(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        width:   double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.red.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.logout_rounded,
                                color: Colors.red, size: 20),
                            const SizedBox(width: 10),
                            Text('Log Out',
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.red)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize:      13,
              fontWeight:    FontWeight.w700,
              color:         _textMid,
              letterSpacing: 0.5)),
    );
  }

  Widget _menuCard(List<_MenuTileData> tiles) {
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAEAF0), width: 1),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: tiles.asMap().entries.map((entry) {
          final i      = entry.key;
          final tile   = entry.value;
          final isLast = i == tiles.length - 1;
          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 4),
                leading: Container(
                  width:  38,
                  height: 38,
                  decoration: BoxDecoration(
                    color:        _surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(tile.icon, color: _purple, size: 20),
                ),
                title: Text(tile.title,
                    style: GoogleFonts.poppins(
                        fontSize:   14,
                        fontWeight: FontWeight.w600,
                        color:      _textDark)),
                subtitle: tile.subtitle != null
                    ? Text(tile.subtitle!,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: _textMid))
                    : null,
                trailing: const Icon(Icons.arrow_forward_ios_rounded,
                    color: Color(0xFFCCCCDD), size: 14),
                onTap: tile.onTap ?? () {},
              ),
              if (!isLast)
                Padding(
                  padding:
                  const EdgeInsets.only(left: 72, right: 18),
                  child: Divider(height: 1, color: Colors.grey[100]),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MenuTileData {
  final IconData      icon;
  final String        title;
  final String?       subtitle;
  final VoidCallback? onTap;

  const _MenuTileData({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });
}

// ── Separate StatefulWidget for the edit-name dialog ─────────────────────────
// Owning the TextEditingController here means Flutter disposes it automatically
// when the dialog is popped — no manual dispose() needed, no crash.
class _EditNameDialog extends StatefulWidget {
  final String                    initialName;
  final Future<void> Function(String) onSave;

  const _EditNameDialog({
    required this.initialName,
    required this.onSave,
  });

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  static const Color _purple   = Color(0xFF7C14D4);
  static const Color _surface  = Color(0xFFF2EEF8);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMid  = Color(0xFF6B6B8A);

  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _ctrl.dispose(); // safe here — called after widget leaves the tree
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Edit Display Name',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, color: _textDark)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose a name others will see on your profile.',
            style: GoogleFonts.poppins(fontSize: 12, color: _textMid),
          ),
          const SizedBox(height: 14),
          TextField(
            controller:  _ctrl,
            autofocus:   false ,
            maxLength:   30,
            style: GoogleFonts.poppins(fontSize: 14, color: _textDark),
            decoration: InputDecoration(
              hintText:  'Enter display name',
              hintStyle: GoogleFonts.poppins(color: _textMid, fontSize: 13),
              filled:       true,
              fillColor:    _surface,
              counterStyle: GoogleFonts.poppins(fontSize: 10, color: _textMid),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:   BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _purple, width: 1.5),
              ),
              prefixIcon: const Icon(Icons.person_outline_rounded,
                  color: _purple, size: 20),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: GoogleFonts.poppins(
                  color: _textMid, fontWeight: FontWeight.w600)),
        ),
        TextButton(
          onPressed: () async {
            final newName = _ctrl.text.trim();
            if (newName.isEmpty) return;
            Navigator.pop(context);        // close dialog first
            await widget.onSave(newName);  // then call API
          },
          child: Text('Save',
              style: GoogleFonts.poppins(
                  color: _purple, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}