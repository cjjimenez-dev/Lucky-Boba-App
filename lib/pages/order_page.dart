import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../cart/delivery_page.dart';
import 'stores_page.dart';
import '../utils/app_theme.dart';

class OrderPage extends StatelessWidget {
  const OrderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent, // Background provided by Dashboard
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── LOGO HEADER ───────────────────────────────────────────
            Center(
              child: Hero(
                tag: 'logo',
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 60,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.local_cafe_rounded,
                      color: Colors.white70,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── PREMIUM QUESTION CARD ──────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: AppTheme.glassDecoration(
                borderRadius: 32,
                opacity: 0.12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'ORDER NOW',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.secondary,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'How would you like\nyour drinks today?',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // ── SECTION LABEL ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Choose your preference',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── ORDER OPTIONS ──────────────────────────────────────────
            _OrderCard(
              title: 'Delivery',
              subtitle: 'Order via GrabFood or foodpanda',
              icon: PhosphorIconsRegular.moped,
              accentColor: const Color(0xFF00C853),
              badge: 'FASTEST',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DeliveryPage()),
              ),
            ),

            const SizedBox(height: 16),

            _OrderCard(
              title: 'Store Pickup',
              subtitle: 'Skip the line and pick up nearby',
              icon: PhosphorIconsRegular.storefront,
              accentColor: AppTheme.secondary,
              badge: 'POPULAR',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StoresPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final String title, subtitle, badge;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _OrderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.badge,
    required this.onTap,
  });

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.98).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.glassDecoration(borderRadius: 24, opacity: 0.08),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(widget.icon, color: widget.accentColor, size: 30),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.badge,
                            style: GoogleFonts.outfit(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: widget.accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white54,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white24,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}