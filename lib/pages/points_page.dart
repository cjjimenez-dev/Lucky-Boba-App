import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../config/app_config.dart';

class PointsPage extends StatefulWidget {
  final int points;
  const PointsPage({super.key, required this.points});

  @override
  State<PointsPage> createState() => _PointsPageState();
}

class _PointsPageState extends State<PointsPage> {
  static const Color _purple   = Color(0xFF7C14D4);
  static const Color _orange   = Color(0xFFFF8C00);
  static const Color _bg       = Color(0xFFFAFAFA);
  static const Color _surface  = Color(0xFFF2EEF8);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMid  = Color(0xFF6B6B8A);
  static const Color _green    = Color(0xFF16A34A);

  bool    _loading = true;
  int     _points  = 0;
  List    _history = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _points = widget.points;
    _fetchPoints();
  }

  Future<void> _fetchPoints() async {
    setState(() { _loading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('session_token') ?? '';

      debugPrint('🔑 Token: $token');
      debugPrint('🌐 URL: ${AppConfig.apiUrl}/points');

      final res = await http.get(
        Uri.parse('${AppConfig.apiUrl}/points'),
        headers: {
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      debugPrint('📦 Status: ${res.statusCode}');
      debugPrint('📦 Body: ${res.body}');

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _points  = data['points'] ?? 0;
          _history = data['history'] ?? [];
        });
      } else {
        setState(() => _error = 'Failed to load points. (${res.statusCode})');
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      if (mounted) setState(() => _error = 'Network error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _pesoValue => (_points / 100) * 10;

  String _formatDate(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor:  Colors.white,
        elevation:        0,
        centerTitle:      true,
        surfaceTintColor: Colors.transparent,
        title: Text('Lucky Points',
            style: GoogleFonts.poppins(
                color: _textDark, fontWeight: FontWeight.w700, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1A1A2E), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEAEAF0)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : _error != null
          ? Center(
          child: Text(_error!,
              style: GoogleFonts.poppins(color: _textMid)))
          : RefreshIndicator(
        color:     _purple,
        onRefresh: _fetchPoints,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── POINTS BALANCE CARD ──────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C14D4), Color(0xFF9C3EE8)],
                    begin:  Alignment.topLeft,
                    end:    Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color:      _purple.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset:     const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text('LUCKY POINTS BALANCE',
                            style: GoogleFonts.poppins(
                                fontSize:      10,
                                color:         Colors.white70,
                                fontWeight:    FontWeight.w600,
                                letterSpacing: 1.2)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('$_points pts',
                        style: GoogleFonts.poppins(
                            fontSize:   42,
                            fontWeight: FontWeight.w800,
                            color:      Colors.white,
                            height:     1.0)),
                    const SizedBox(height: 6),
                    Text(
                      '≈ ₱${_pesoValue.toStringAsFixed(2)} redeemable value',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width:  double.infinity,
                      height: 6,
                      decoration: BoxDecoration(
                        color:        Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: FractionallySizedBox(
                        widthFactor: ((_points % 100) / 100)
                            .clamp(0.0, 1.0),
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            color:        Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _points >= 100
                          ? '${_points % 100} pts to next ₱10 reward'
                          : '${100 - _points} pts to your first ₱10 reward',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.white60),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── HOW IT WORKS ─────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:        _surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _purple.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How it works',
                        style: GoogleFonts.poppins(
                            fontSize:   13,
                            fontWeight: FontWeight.w700,
                            color:      _textDark)),
                    const SizedBox(height: 12),
                    _HowItWorksRow(
                      icon:  Icons.shopping_bag_rounded,
                      color: _orange,
                      text:  '₱1 spent = 1 Lucky Point',
                    ),
                    const SizedBox(height: 8),
                    _HowItWorksRow(
                      icon:  Icons.credit_card_rounded,
                      color: _purple,
                      text:  'Card holders earn 2× points per order',
                    ),
                    const SizedBox(height: 8),
                    _HowItWorksRow(
                      icon:  Icons.redeem_rounded,
                      color: _green,
                      text:  '100 points = ₱10 discount at checkout',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── HISTORY ──────────────────────────────────
              Text('Points History',
                  style: GoogleFonts.poppins(
                      fontSize:   16,
                      fontWeight: FontWeight.w700,
                      color:      _textDark)),
              const SizedBox(height: 12),

              if (_history.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Icon(PhosphorIconsRegular.star,
                            size:  48,
                            color: _textMid.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text('No points history yet',
                            style: GoogleFonts.poppins(
                                color:    _textMid,
                                fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Place an order to start earning!',
                            style: GoogleFonts.poppins(
                                color:    _textMid,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color:        Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFFEAEAF0)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics:    const NeverScrollableScrollPhysics(),
                    itemCount:  _history.length,
                    separatorBuilder: (_, _) => const Divider(
                        height: 1, color: Color(0xFFEAEAF0)),
                    itemBuilder: (_, i) {
                      final tx     = _history[i];
                      final isEarn = tx['type'] == 'earn';
                      final pts    = tx['points'] ?? 0;
                      final note   = tx['note'] ?? '';
                      final date   = _formatDate(
                          tx['created_at']?.toString());

                      return Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width:  38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isEarn
                                    ? _green.withValues(alpha: 0.10)
                                    : _orange.withValues(alpha: 0.10),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isEarn
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                                color: isEarn ? _green : _orange,
                                size:  18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(note,
                                      style: GoogleFonts.poppins(
                                          fontSize:   12,
                                          fontWeight: FontWeight.w600,
                                          color:      _textDark),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  Text(date,
                                      style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          color:    _textMid)),
                                ],
                              ),
                            ),
                            Text(
                              '${isEarn ? '+' : '-'}$pts pts',
                              style: GoogleFonts.poppins(
                                  fontSize:   14,
                                  fontWeight: FontWeight.w800,
                                  color: isEarn ? _green : _orange),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowItWorksRow extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   text;

  const _HowItWorksRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: const Color(0xFF1A1A2E))),
        ),
      ],
    );
  }
}