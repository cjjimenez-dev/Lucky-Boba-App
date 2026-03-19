// FILE: lib/pages/card_purchase_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'qr_perk_page.dart';
import '../config/app_config.dart';

class CardPurchasePage extends StatefulWidget {
  final int    cardId;
  final String cardTitle;
  final String cardImagePath;
  final String cardPrice;
  final bool   isOwned;

  const CardPurchasePage({
    super.key,
    required this.cardId,
    required this.cardTitle,
    required this.cardImagePath,
    required this.cardPrice,
    this.isOwned = false,
  });

  @override
  State<CardPurchasePage> createState() => _CardPurchasePageState();
}

class _CardPurchasePageState extends State<CardPurchasePage>
    with SingleTickerProviderStateMixin {
  static const Color _purple    = Color(0xFF7C14D4);
  static const Color _bg        = Color(0xFFFAFAFA);
  static const Color _surface   = Color(0xFFF2EEF8);
  static const Color _textDark  = Color(0xFF1A1A2E);
  static const Color _textMid   = Color(0xFF6B6B8A);
  static const Color _yellow    = Color(0xFFFFD54F);
  static const Color _gcashBlue = Color(0xFF0070BA);
  static const Color _mayaGreen = Color(0xFF00B576);

  // ── ✅ UPDATE THESE WITH YOUR REAL NUMBERS ────────────────────────────────
  static const String _gcashNumber = '09XX XXX XXXX';
  static const String _mayaNumber  = '09XX XXX XXXX';
  static const String _accountName = 'Lucky Boba Store';

  late bool _isCurrentlyOwned;
  late AnimationController _flipController;
  late Animation<double>   _flipAnimation;
  bool _isFlipped     = false;
  bool _loadingExpiry = false;

  String? _expiresAtFormatted;
  int?    _daysRemaining;

  @override
  void initState() {
    super.initState();

    // ── ✅ Start with the passed-in value, then verify from SharedPreferences
    _isCurrentlyOwned = widget.isOwned;

    _flipController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    // ── ✅ Always re-check from SharedPreferences so it's never stale
    _syncOwnedStatusFromPrefs();
  }

  /// Re-reads has_active_card from SharedPreferences and updates UI.
  /// This ensures even if isOwned=false was passed, we still show
  /// the correct state if the user already owns a card.
  Future<void> _syncOwnedStatusFromPrefs() async {
    final prefs          = await SharedPreferences.getInstance();
    final bool fromPrefs = prefs.getBool('has_active_card') ?? false;

    if (fromPrefs && !_isCurrentlyOwned) {
      if (mounted) setState(() => _isCurrentlyOwned = true);
    }

    if (_isCurrentlyOwned) _loadExpiryInfo();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _loadExpiryInfo() async {
    setState(() => _loadingExpiry = true);
    try {
      final prefs       = await SharedPreferences.getInstance();
      final int? userId = prefs.getInt('user_id');
      if (userId == null) return;
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/check-card-status/$userId'),
      ).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['has_active_card'] == true) {
          setState(() {
            _expiresAtFormatted = data['expires_at_formatted'];
            _daysRemaining      = data['days_remaining'] is int
                ? data['days_remaining']
                : int.tryParse(data['days_remaining'].toString());
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingExpiry = false);
    }
  }

  void _toggleFlip() {
    if (!mounted) return;
    setState(() => _isFlipped = !_isFlipped);
    _isFlipped ? _flipController.forward() : _flipController.reverse();
  }

  // ── Open GCash app ────────────────────────────────────────────────────────
  Future<void> _openGCash() async {
    final Uri gcashDeepLink  = Uri.parse('gcash://');
    final Uri gcashPlayStore = Uri.parse(
        'https://play.google.com/store/apps/details?id=com.globe.gcash.android');

    if (await canLaunchUrl(gcashDeepLink)) {
      await launchUrl(gcashDeepLink, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(gcashPlayStore, mode: LaunchMode.externalApplication);
    }
  }

  // ── Open Maya app ─────────────────────────────────────────────────────────
  Future<void> _openMaya() async {
    final Uri mayaDeepLink  = Uri.parse('maya://');
    final Uri mayaPlayStore = Uri.parse(
        'https://play.google.com/store/apps/details?id=ph.maya.app');

    if (await canLaunchUrl(mayaDeepLink)) {
      await launchUrl(mayaDeepLink, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(mayaPlayStore, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _processPayment(String paymentMethod) async {
    Navigator.pop(context);
    final prefs       = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('user_id');
    if (userId == null) {
      if (!mounted) return;
      _showSnack('Session expired. Please log in again.', Colors.redAccent);
      return;
    }
    if (!mounted) return;
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF7C14D4))),
    );
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/purchase-card'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id':        userId,
          'card_id':        widget.cardId,
          'payment_method': paymentMethod,
        }),
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      Navigator.pop(context);
      if (response.statusCode == 200) {
        // ── ✅ Update SharedPreferences so other pages stay in sync ──────
        await prefs.setBool('has_active_card', true);
        await prefs.setInt('card_id', widget.cardId);

        setState(() => _isCurrentlyOwned = true);
        _showSnack('Card Activated! Enjoy your perks. 🎉', Colors.green);
        await _loadExpiryInfo();
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        throw Exception(data['message']);
      } else {
        throw Exception('Server error. Status: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnack('Error: $e', Colors.redAccent);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Payment method selector ───────────────────────────────────────────────
  void _showPaymentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Choose Payment Method',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w700, color: _textDark)),
              const SizedBox(height: 4),
              Text('Select how you want to pay for ${widget.cardTitle}',
                  style: GoogleFonts.poppins(fontSize: 12, color: _textMid)),
              const SizedBox(height: 20),

              // ── GCash ───────────────────────────────────────────────
              _PaymentOptionTile(
                label:    'GCash',
                subtitle: 'Pay via GCash e-wallet',
                color:    _gcashBlue,
                accentColor: const Color(0xFFE8F3FC),
                icon:     Icons.account_balance_wallet_rounded,
                logoPath: 'assets/images/gcash_logo.png',
                onTap: () {
                  Navigator.pop(context);
                  _showQrPaymentScreen(
                    method:        'gcash',
                    label:         'GCash',
                    color:         _gcashBlue,
                    accentColor:   const Color(0xFFE8F3FC),
                    qrAsset:       'assets/images/gcash_qr.png',
                    accountNumber: _gcashNumber,
                    onOpenApp:     _openGCash,
                  );
                },
              ),

              const SizedBox(height: 12),

              // ── Maya ────────────────────────────────────────────────
              _PaymentOptionTile(
                label:    'Maya',
                subtitle: 'Pay via Maya e-wallet',
                color:    _mayaGreen,
                accentColor: const Color(0xFFE6F7F1),
                icon:     Icons.payment_rounded,
                logoPath: 'assets/images/maya_logo.png',
                onTap: () {
                  Navigator.pop(context);
                  _showQrPaymentScreen(
                    method:        'maya',
                    label:         'Maya',
                    color:         _mayaGreen,
                    accentColor:   const Color(0xFFE6F7F1),
                    qrAsset:       'assets/images/maya_qr.png',
                    accountNumber: _mayaNumber,
                    onOpenApp:     _openMaya,
                  );
                },
              ),

              const SizedBox(height: 12),

              // ── Amount summary ──────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: _surface, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Amount to pay',
                        style: GoogleFonts.poppins(fontSize: 13, color: _textMid)),
                    Text(widget.cardPrice,
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w800, color: _purple)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── QR + Open App screen ──────────────────────────────────────────────────
  void _showQrPaymentScreen({
    required String        method,
    required String        label,
    required Color         color,
    required Color         accentColor,
    required String        qrAsset,
    required String        accountNumber,
    required Future<void> Function() onOpenApp,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),

                // Header
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                    child: Icon(Icons.qr_code_rounded, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Pay with $label',
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w700, color: _textDark)),
                    Text('Scan QR or open the $label app',
                        style: GoogleFonts.poppins(fontSize: 12, color: _textMid)),
                  ]),
                ]),

                const SizedBox(height: 20),

                // ── QR Box ────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Column(children: [
                    Container(
                      width: 200, height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(
                            color: color.withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 6))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(qrAsset, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.qr_code_2_rounded, color: color, size: 100),
                              const SizedBox(height: 8),
                              Text('QR Coming Soon',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(_accountName,
                        style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w700, color: _textDark)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: accountNumber));
                        _showSnack('Number copied!', Colors.green);
                      },
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(accountNumber,
                            style: GoogleFonts.poppins(
                                fontSize: 16, fontWeight: FontWeight.w700,
                                color: color, letterSpacing: 1.5)),
                        const SizedBox(width: 6),
                        Icon(Icons.copy_rounded, color: color, size: 16),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('Amount: ${widget.cardPrice}',
                          style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                    ),
                  ]),
                ),

                const SizedBox(height: 16),

                // ── Open App button ────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onOpenApp,
                    icon: Icon(Icons.open_in_new_rounded, color: color, size: 18),
                    label: Text('Open $label App',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700, fontSize: 14, color: color)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: color, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ── Info note ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8F0),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          'Send $_accountName the exact amount of ${widget.cardPrice}. After sending, tap "I\'ve Paid" below.',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.orange[800], height: 1.5)),
                    ),
                  ]),
                ),

                const SizedBox(height: 16),

                // ── I've Paid button ───────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _processPayment(method),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text("I've Paid — Activate My Card",
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showExpiryDialog() {
    final int days    = _daysRemaining ?? 0;
    final bool urgent = days <= 7;
    final Color color = urgent ? Colors.orange : Colors.green;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 72, height: 72,
                decoration: BoxDecoration(color: color.withOpacity(0.10), shape: BoxShape.circle),
                child: Icon(urgent ? Icons.warning_amber_rounded : Icons.calendar_month_rounded, color: color, size: 36)),
            const SizedBox(height: 16),
            Text('Card Expiry', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: _textDark)),
            const SizedBox(height: 20),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Expires on', style: GoogleFonts.poppins(fontSize: 13, color: _textMid)),
                  Text(_expiresAtFormatted ?? '—', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: _textDark)),
                ]),
                const SizedBox(height: 10),
                const Divider(color: Color(0xFFEAEAF0)),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Days remaining', style: GoogleFonts.poppins(fontSize: 13, color: _textMid)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text('$days day${days != 1 ? 's' : ''}',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                  ),
                ]),
              ]),
            ),
            if (urgent) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3))),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Your card expires soon! Visit any Lucky Boba store to renew.',
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.orange[800]))),
                ]),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0),
                child: Text('Got it', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showLockedMessage() =>
      _showSnack('Purchase this card to unlock the QR code!', Colors.redAccent);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        centerTitle: true, surfaceTintColor: Colors.transparent,
        title: Text(_isCurrentlyOwned ? 'My Card' : 'Purchase Card',
            style: GoogleFonts.poppins(color: _textDark, fontWeight: FontWeight.w700, fontSize: 16)),
        leading: _isCurrentlyOwned ? null : IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1A2E), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: const Color(0xFFEAEAF0))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Flippable card ──────────────────────────────────────────
          GestureDetector(
            onTap: _toggleFlip,
            child: Container(
              height: 210, width: double.infinity,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(color: _purple.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10))]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(children: [
                  Positioned.fill(child: AnimatedBuilder(
                    animation: _flipAnimation,
                    builder: (context, child) {
                      final angle  = _flipAnimation.value * math.pi;
                      final isBack = angle > math.pi / 2;
                      return Transform(
                        transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(angle),
                        alignment: Alignment.center,
                        child: isBack
                            ? Transform(alignment: Alignment.center, transform: Matrix4.rotationY(math.pi),
                            child: Image.asset('assets/images/back_card.png', fit: BoxFit.cover))
                            : Image.asset(widget.cardImagePath, fit: BoxFit.cover),
                      );
                    },
                  )),
                  Positioned(top: 12, right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.flip_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text('Tap to flip', style: GoogleFonts.poppins(fontSize: 10, color: Colors.white)),
                        ]),
                      )),
                ]),
              ),
            ),
          ),

          const SizedBox(height: 24),

          Row(children: [
            Expanded(child: Text(widget.cardTitle,
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: _textDark))),
            if (_isCurrentlyOwned) Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                const SizedBox(width: 4),
                Text('Active', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green)),
              ]),
            ),
          ]),
          const SizedBox(height: 6),
          Text('Your perks', style: GoogleFonts.poppins(fontSize: 13, color: _textMid)),

          // ── Expiry button ───────────────────────────────────────────
          if (_isCurrentlyOwned) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _loadingExpiry ? null : _showExpiryDialog,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _daysRemaining != null && _daysRemaining! <= 7 ? Colors.orange.withOpacity(0.08) : _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _daysRemaining != null && _daysRemaining! <= 7 ? Colors.orange.withOpacity(0.4) : _purple.withOpacity(0.2),
                    width: 1.2,
                  ),
                ),
                child: _loadingExpiry
                    ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C14D4))))
                    : Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _daysRemaining != null && _daysRemaining! <= 7 ? Colors.orange.withOpacity(0.15) : _purple.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _daysRemaining != null && _daysRemaining! <= 7 ? Icons.warning_amber_rounded : Icons.calendar_month_rounded,
                      color: _daysRemaining != null && _daysRemaining! <= 7 ? Colors.orange : _purple,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Card Validity', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: _textDark)),
                    Text(
                      _expiresAtFormatted != null ? 'Expires $_expiresAtFormatted' : 'Tap to check expiry',
                      style: GoogleFonts.poppins(fontSize: 11, color: _daysRemaining != null && _daysRemaining! <= 7 ? Colors.orange[700] : _textMid),
                    ),
                  ])),
                  if (_daysRemaining != null) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _daysRemaining! <= 7 ? Colors.orange.withOpacity(0.15) : Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${_daysRemaining}d left',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700,
                            color: _daysRemaining! <= 7 ? Colors.orange : Colors.green)),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_ios_rounded, color: _textMid, size: 13),
                ]),
              ),
            ),
          ],

          const SizedBox(height: 20),

          _PerkTile(
            label: 'Buy 1, Take 1',
            subtitle: _isCurrentlyOwned ? 'Tap to view daily QR code' : 'Locked — purchase to unlock',
            icon: PhosphorIconsRegular.coffee, isOwned: _isCurrentlyOwned,
            accentColor: _yellow, iconColor: _purple,
            onTap: _isCurrentlyOwned
                ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrPerkPage(perkName: 'Buy 1, Get 1 Free')))
                : _showLockedMessage,
          ),
          const SizedBox(height: 12),
          _PerkTile(
            label: '10% off on all items',
            subtitle: _isCurrentlyOwned ? 'Tap to view unlimited QR code' : 'Locked — purchase to unlock',
            icon: PhosphorIconsRegular.percent, isOwned: _isCurrentlyOwned,
            accentColor: const Color(0xFFF2EEF8), iconColor: _purple,
            onTap: _isCurrentlyOwned
                ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrPerkPage(perkName: '10% Off All Items')))
                : _showLockedMessage,
          ),
          const SizedBox(height: 32),
        ]),
      ),
      bottomNavigationBar: _isCurrentlyOwned ? const SizedBox.shrink() : Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFEAEAF0), width: 1))),
        child: ElevatedButton(
          onPressed: _showPaymentSheet,
          style: ElevatedButton.styleFrom(
              backgroundColor: _purple, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
          child: Text('Pay Now — ${widget.cardPrice}',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ),
    );
  }
}

// ── PAYMENT OPTION TILE ───────────────────────────────────────────────────────
class _PaymentOptionTile extends StatelessWidget {
  final String label, subtitle, logoPath;
  final Color color, accentColor;
  final IconData icon;
  final VoidCallback onTap;
  const _PaymentOptionTile({required this.label, required this.subtitle, required this.color, required this.accentColor, required this.icon, required this.logoPath, required this.onTap});
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMid  = Color(0xFF6B6B8A);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEAEAF0), width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(14)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Image.asset(logoPath, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(icon, color: color, size: 28)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark)),
            Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: _textMid)),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
        ]),
      ),
    );
  }
}

// ── PERK TILE ─────────────────────────────────────────────────────────────────
class _PerkTile extends StatelessWidget {
  final String label, subtitle;
  final IconData icon;
  final bool isOwned;
  final Color accentColor, iconColor;
  final VoidCallback onTap;
  const _PerkTile({required this.label, required this.subtitle, required this.icon, required this.isOwned, required this.accentColor, required this.iconColor, required this.onTap});
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMid  = Color(0xFF6B6B8A);
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isOwned ? accentColor.withValues(alpha: 0.15) : Colors.grey[100],
          border: Border.all(color: isOwned ? accentColor.withValues(alpha: 0.5) : Colors.grey[300]!, width: 1.5),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isOwned ? [BoxShadow(color: accentColor.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 3))] : [],
        ),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: isOwned ? accentColor : Colors.grey[300], shape: BoxShape.circle),
              child: Icon(isOwned ? icon : PhosphorIconsRegular.lock, color: isOwned ? iconColor : Colors.white, size: 18)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: isOwned ? _textDark : Colors.grey[500])),
            const SizedBox(height: 2),
            Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: isOwned ? _textMid : Colors.grey[400])),
          ])),
          Icon(isOwned ? Icons.arrow_forward_ios_rounded : Icons.lock_outline, color: isOwned ? _textMid : Colors.grey[400], size: 14),
        ]),
      ),
    );
  }
}