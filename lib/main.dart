import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'signup.dart';
import 'terms_conditions.dart';
import 'pages/landing_promo_page.dart';
import 'onboarding/onboarding_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Initialize Firebase ───────────────────────────────────────────────────
  await Firebase.initializeApp();

  final prefs = await SharedPreferences.getInstance();
  final bool onboardingDone = prefs.getBool('onboarding_done') ?? false;

  runApp(LuckyBobaApp(showOnboarding: !onboardingDone));
}

class LuckyBobaApp extends StatelessWidget {
  final bool showOnboarding;
  const LuckyBobaApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lucky Boba App',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7C14D4)),
      ),
      home: showOnboarding ? const OnboardingPage() : const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {

  static const Color _purple      = Color(0xFF7C14D4);
  static const Color _purpleLight = Color(0xFF9B30FF);
  static const Color _orange      = Color(0xFFFF8C00);
  static const Color _bg          = Color(0xFFFAFAFA);
  static const Color _surface     = Color(0xFFF2EEF8);
  static const Color _border      = Color(0xFFEAEAF0);
  static const Color _textDark    = Color(0xFF1A1A2E);
  static const Color _textMid     = Color(0xFF6B6B8A);

  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool  _obscure         = true;
  bool  _loading         = false;
  bool  _googleLoading   = false;
  bool  _facebookLoading = false;

  // ── Google Sign-In instance ───────────────────────────────────────────────
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  late final AnimationController _entryCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _entryCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(
        parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
        parent: _entryCtrl, curve: Curves.easeOut));
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  // ── Normal email/password login ───────────────────────────────────────────
  Future<void> _handleLogin() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _snack('Please fill in all fields', Colors.orange);
      return;
    }

    setState(() => _loading = true);

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/api/login'),
        headers: {'Content-Type': 'application/json'},
        body:    jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() => _loading = false);

      if (response.statusCode == 200) {
        await _saveUserAndNavigate(jsonDecode(response.body), email);
      } else {
        _snack('Invalid email or password', Colors.redAccent);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      _snack('Cannot reach server — check your Wi-Fi', Colors.redAccent);
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────
  Future<void> _handleGoogleSignIn() async {
    setState(() => _googleLoading = true);

    try {
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _googleLoading = false);
        return;
      }

      final String name  = googleUser.displayName ?? 'Guest';
      final String email = googleUser.email;

      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/api/google-login'),
        headers: {'Content-Type': 'application/json'},
        body:    jsonEncode({'name': name, 'email': email}),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() => _googleLoading = false);

      if (response.statusCode == 200) {
        await _saveUserAndNavigate(jsonDecode(response.body), email);
      } else {
        _snack('Google Sign-In failed — please try again', Colors.redAccent);
      }
    } catch (e) {
      if (mounted) setState(() => _googleLoading = false);
      debugPrint('Google Sign-In error: $e');
      _snack('Google Sign-In failed — check your connection', Colors.redAccent);
    }
  }

  // ── Facebook Sign-In ──────────────────────────────────────────────────────
  Future<void> _handleFacebookSignIn() async {
    setState(() => _facebookLoading = true);

    try {
      await FacebookAuth.instance.logOut();

      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status != LoginStatus.success) {
        setState(() => _facebookLoading = false);
        return;
      }

      final OAuthCredential credential =
      FacebookAuthProvider.credential(
        result.accessToken!.tokenString,
      );

      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        setState(() => _facebookLoading = false);
        _snack('Facebook Sign-In failed', Colors.redAccent);
        return;
      }

      if (!mounted) return;
      setState(() => _facebookLoading = false);

      // Facebook login doesn't go through Laravel so no card data
      await _saveUserAndNavigate(
        {
          'user': {
            'id':              firebaseUser.uid,
            'name':            firebaseUser.displayName ?? 'Guest',
            'email':           firebaseUser.email ?? '',
            'role':            'customer',
            'has_active_card': false,
            'card_id':         null,
            'card_expires_at': null,
          }
        },
        firebaseUser.email ?? '',
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _facebookLoading = false);
      debugPrint('FirebaseAuthException: ${e.code} — ${e.message}');
      _snack('Sign-In failed: ${e.message}', Colors.redAccent);
    } catch (e) {
      if (mounted) setState(() => _facebookLoading = false);
      debugPrint('Facebook Sign-In error: $e');
      _snack('Facebook Sign-In failed — check your connection', Colors.redAccent);
    }
  }

  // ── Save user data and navigate ───────────────────────────────────────────
  // ✅ Supports both int (Laravel) and String (Firebase) user IDs
  Future<void> _saveUserAndNavigate(
      Map<String, dynamic> data, String fallbackEmail) async {
    final userObj = data['user'] ?? data;

    // Support both int (Laravel) and String (Firebase UID)
    final dynamic rawId  = userObj['id'];
    final String userKey = rawId?.toString() ?? fallbackEmail;

    final String userName  = userObj['name']  ?? 'Guest';
    final String userRole  = userObj['role']  ?? 'customer';
    final String userEmail = userObj['email'] ?? fallbackEmail;

    // ── ✅ Read card data from login response ─────────────────────────────
    final bool hasActiveCard = userObj['has_active_card'] == true;
    final int? cardId        = userObj['card_id'] is int
        ? userObj['card_id']
        : int.tryParse(userObj['card_id']?.toString() ?? '');
    final String? cardExpiresAt = userObj['card_expires_at']?.toString();
    // ──────────────────────────────────────────────────────────────────────

    final prefs = await SharedPreferences.getInstance();

    // Save as int if Laravel, as string if Firebase
    if (rawId is int) {
      await prefs.setInt('user_id', rawId);
    } else {
      await prefs.setString('user_id_str', userKey);
    }

    await prefs.setString('userName',  userName);
    await prefs.setString('userRole',  userRole);
    await prefs.setString('userEmail', userEmail);

    // ── ✅ Save card status to SharedPreferences ───────────────────────────
    await prefs.setBool('has_active_card', hasActiveCard);
    if (cardId != null) {
      await prefs.setInt('card_id', cardId);
    } else {
      await prefs.remove('card_id');
    }
    if (cardExpiresAt != null) {
      await prefs.setString('card_expires_at', cardExpiresAt);
    } else {
      await prefs.remove('card_expires_at');
    }
    // ──────────────────────────────────────────────────────────────────────

    debugPrint('✅ Login → user_id=$userKey name=$userName role=$userRole '
        'has_active_card=$hasActiveCard card_id=$cardId');

    // ✅ Use string key — works for both Laravel int IDs and Firebase string UIDs
    final bool hasAccepted =
        prefs.getBool('has_accepted_terms_$userKey') ?? false;

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => hasAccepted
              ? const LandingPromoPage()
              : const TermsPage(),
        ),
      );
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
      backgroundColor: color,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [

                // ── PURPLE HERO SECTION ──────────────────────────────
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin:  Alignment.topLeft,
                      end:    Alignment.bottomRight,
                      colors: [_purple, Color(0xFF5A0EA0)],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top:   -30,
                        right: -30,
                        child: Container(
                          width:  130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        left:   -20,
                        child: Container(
                          width:  90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 40, 24, 56),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Center(
                                child: Container(
                                  width:        90,
                                  height:       90,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.30),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:      Colors.black.withValues(alpha: 0.20),
                                        blurRadius: 24,
                                        offset:     const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    'assets/images/maps_logo.png',
                                    fit:    BoxFit.cover,
                                    width:  90,
                                    height: 90,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      child: const Icon(
                                        Icons.local_cafe_rounded,
                                        color: Colors.white,
                                        size:  36,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Lucky Boba',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize:   26,
                                  fontWeight: FontWeight.w800,
                                  color:      Colors.white,
                                  height:     1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _orange.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _orange.withValues(alpha: 0.55),
                                    width: 1.2,
                                  ),
                                ),
                                child: Text(
                                  'CUSTOMER APP',
                                  style: GoogleFonts.poppins(
                                    fontSize:      10,
                                    fontWeight:    FontWeight.w700,
                                    color:         const Color(0xFFFFD580),
                                    letterSpacing: 1.8,
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

                // ── FLOATING WHITE CARD ──────────────────────────────
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      width:   double.infinity,
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        color:        Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color:      Colors.black.withValues(alpha: 0.10),
                            blurRadius: 32,
                            offset:     const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome 👋',
                            style: GoogleFonts.poppins(
                              fontSize:   20,
                              fontWeight: FontWeight.w700,
                              color:      _textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sign in to continue to Lucky Boba',
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: _textMid),
                          ),
                          const SizedBox(height: 24),

                          _fieldLabel('Email Address'),
                          const SizedBox(height: 7),
                          _inputField(
                            controller: _emailCtrl,
                            hint:       'name@luckyboba.com',
                            icon:       Icons.mail_outline_rounded,
                            isPassword: false,
                          ),
                          const SizedBox(height: 16),

                          _fieldLabel('Password'),
                          const SizedBox(height: 7),
                          _inputField(
                            controller: _passwordCtrl,
                            hint:       '••••••••',
                            icon:       Icons.lock_outline_rounded,
                            isPassword: true,
                          ),
                          const SizedBox(height: 28),

                          // Sign in button
                          SizedBox(
                            width:  double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:         Colors.transparent,
                                shadowColor:             Colors.transparent,
                                disabledBackgroundColor: Colors.transparent,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: _loading
                                      ? null
                                      : const LinearGradient(
                                    colors: [_purple, _purpleLight],
                                  ),
                                  color: _loading
                                      ? _purple.withValues(alpha: 0.5)
                                      : null,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: _loading
                                      ? []
                                      : [
                                    BoxShadow(
                                      color:      _purple.withValues(alpha: 0.40),
                                      blurRadius: 16,
                                      offset:     const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  alignment: Alignment.center,
                                  child: _loading
                                      ? const SizedBox(
                                    width:  20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color:       Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                      : Text(
                                    'Sign In',
                                    style: GoogleFonts.poppins(
                                      fontSize:   15,
                                      fontWeight: FontWeight.w700,
                                      color:      Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── BELOW CARD ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Column(
                    children: [

                      // OR divider
                      Row(
                        children: [
                          Expanded(
                              child: Divider(color: _border, thickness: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'OR',
                              style: GoogleFonts.poppins(
                                fontSize:   11,
                                fontWeight: FontWeight.w700,
                                color:      _textMid,
                              ),
                            ),
                          ),
                          Expanded(
                              child: Divider(color: _border, thickness: 1)),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── GOOGLE BUTTON ────────────────────────────
                      GestureDetector(
                        onTap: _googleLoading ? null : _handleGoogleSignIn,
                        child: Container(
                          width:   double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color:        Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _border, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color:      Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset:     const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: _googleLoading
                              ? const Center(
                            child: SizedBox(
                              width:  20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFFEA4335),
                              ),
                            ),
                          )
                              : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FaIcon(
                                FontAwesomeIcons.google,
                                color: const Color(0xFFEA4335),
                                size:  16,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Continue with Google',
                                style: GoogleFonts.poppins(
                                  fontSize:   13,
                                  fontWeight: FontWeight.w600,
                                  color:      _textDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── FACEBOOK BUTTON ──────────────────────────
                      _socialBtn(
                        icon:      FontAwesomeIcons.facebookF,
                        label:     'Continue with Facebook',
                        color:     const Color(0xFF1877F2),
                        onTap:     _facebookLoading ? () {} : _handleFacebookSignIn,
                        isLoading: _facebookLoading,
                      ),

                      const SizedBox(height: 24),

                      // Sign up link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: _textMid),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SignupPage()),
                            ),
                            child: Text(
                              'Sign Up',
                              style: GoogleFonts.poppins(
                                fontSize:        13,
                                fontWeight:      FontWeight.w700,
                                color:           _orange,
                                decoration:      TextDecoration.underline,
                                decorationColor: _orange,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize:   12,
        fontWeight: FontWeight.w600,
        color:      _textDark,
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String                hint,
    required IconData              icon,
    required bool                  isPassword,
  }) {
    return TextField(
      controller:  controller,
      obscureText: isPassword && _obscure,
      style: GoogleFonts.poppins(fontSize: 14, color: _textDark),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: GoogleFonts.poppins(color: _textMid, fontSize: 14),
        filled:    true,
        fillColor: _surface,
        prefixIcon: Icon(icon, color: _textMid, size: 20),
        suffixIcon: isPassword
            ? GestureDetector(
          onTap: () => setState(() => _obscure = !_obscure),
          child: Icon(
            _obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: _textMid,
            size:  20,
          ),
        )
            : null,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: _border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: _purple, width: 1.5),
        ),
      ),
    );
  }

  Widget _socialBtn({
    required IconData     icon,
    required String       label,
    required Color        color,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border, width: 1),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset:     const Offset(0, 3),
            ),
          ],
        ),
        child: isLoading
            ? Center(
          child: SizedBox(
            width:  20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color:       color,
            ),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icon, color: color, size: 16),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize:   13,
                fontWeight: FontWeight.w600,
                color:      _textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}