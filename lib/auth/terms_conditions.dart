import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'landing_promo_page.dart';
import '../main.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  final Color creamVioletBg = const Color(0xFFE8DEF8);
  final Color darkVioletNav = const Color(0xFF3B2063);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: creamVioletBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8,
              color: Colors.white,
              shadowColor: darkVioletNav.withValues(alpha: 0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 60,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.gavel_rounded,
                          size: 50,
                          color: darkVioletNav),
                    ),
                    const SizedBox(height: 15),

                    Text(
                      'TERMS OF USE',
                      style: GoogleFonts.fredoka(
                        color:         darkVioletNav,
                        fontSize:      20,
                        fontWeight:    FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color:        Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                _mockTermsData,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  height:   1.6,
                                  color:    Colors.black87,
                                ),
                                textAlign: TextAlign.justify,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                    const LoginPage()),
                              );
                            },
                            child: Text(
                              "DECLINE",
                              style: GoogleFonts.poppins(
                                color:      Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final prefs =
                              await SharedPreferences.getInstance();

                              // ✅ Support both int (Laravel) and
                              //    String (Firebase) user IDs
                              final int?    userId    = prefs.getInt('user_id');
                              final String? userIdStr = prefs.getString('user_id_str');

                              // Use whichever is available
                              final String userKey =
                                  userId?.toString() ?? userIdStr ?? '';

                              if (userKey.isNotEmpty) {
                                await prefs.setBool(
                                    'has_accepted_terms_$userKey', true);
                              }

                              if (!context.mounted) return;
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                    const LandingPromoPage()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: darkVioletNav,
                              foregroundColor: Colors.white,
                              padding:         const EdgeInsets.symmetric(
                                  vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              "I ACCEPT",
                              style: GoogleFonts.poppins(
                                  fontWeight:    FontWeight.bold,
                                  letterSpacing: 1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const String _mockTermsData = """
1. INTRODUCTION
Welcome to Lucky Boba POS. By accessing or using our mobile application, you agree to be bound by these Terms and Conditions.

2. USE OF SERVICE
You agree to use this application only for lawful purposes and in accordance with the company's operational guidelines. Unauthorized access to the backend system is strictly prohibited.

3. PRIVACY POLICY
We value your privacy. Your login credentials and sales data are stored securely. We do not share your personal information with third parties without consent.

4. USER RESPONSIBILITIES
- You are responsible for maintaining the confidentiality of your account password.
- You must report any unauthorized use of your account immediately.
- The POS system is for authorized staff only.

5. INTELLECTUAL PROPERTY
All content, logos, and graphics within this app are the property of Lucky Boba and are protected by copyright laws.

6. TERMINATION
We reserve the right to terminate or suspend access to our service immediately, without prior notice, for any breach of these Terms.

7. CHANGES TO TERMS
We may update our Terms and Conditions from time to time. You are advised to review this page periodically for any changes.

Last Updated: February 2026
""";