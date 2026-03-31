// FILE: lib/signup.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart'; // ✅ Firebase
import 'dart:convert';
import '../config/app_config.dart'; // ✅ No more hardcoded URLs

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage>
    with SingleTickerProviderStateMixin {

  // ── Brand tokens ─────────────────────────────────────────────────────────
  static const Color _purple      = Color(0xFF7C14D4);
  static const Color _purpleLight = Color(0xFF9B30FF);
  static const Color _orange      = Color(0xFFFF8C00);
  static const Color _bg          = Color(0xFFFAFAFA);
  static const Color _surface     = Color(0xFFF2EEF8);
  static const Color _border      = Color(0xFFEAEAF0);
  static const Color _textDark    = Color(0xFF1A1A2E);
  static const Color _textMid     = Color(0xFF6B6B8A);

  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool  _obscure      = true;
  bool  _obscureConf  = true;
  bool  _loading      = false;

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
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  // ── Validate email format ─────────────────────────────────────────────────
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\.\-]+@[\w\-]+\.\w{2,}$').hasMatch(email);
  }

  // ── Validate password strength ────────────────────────────────────────────
  bool _isStrongPassword(String password) {
    return password.length >= 8;
  }

  // ── Register via Firebase + Laravel ──────────────────────────────────────
  Future<void> _handleSignup() async {
    final name     = _nameCtrl.text.trim();
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final confirm  = _confirmCtrl.text.trim();

    // ── Validation ────────────────────────────────────────────────────────
    if (name.isEmpty || email.isEmpty ||
        password.isEmpty || confirm.isEmpty) {
      _snack('Please fill in all fields', Colors.orange);
      return;
    }

    if (!_isValidEmail(email)) {
      _snack('Please enter a valid email address', Colors.orange);
      return;
    }

    if (!_isStrongPassword(password)) {
      _snack('Password must be at least 8 characters', Colors.orange);
      return;
    }

    if (password != confirm) {
      _snack('Passwords do not match', Colors.redAccent);
      return;
    }

    setState(() => _loading = true);

    try {
      // ── Step 1: Create Firebase Auth user ────────────────────────────────
      final UserCredential userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email:    email,
        password: password,
      );

      // Update Firebase display name
      await userCredential.user?.updateDisplayName(name);

      // ── Step 2: Register in Laravel backend ──────────────────────────────
      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
        },
        body: jsonEncode({
          'name':     name,
          'email':    email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() => _loading = false);

      if (response.statusCode == 201 || response.statusCode == 200) {
        _snack('Account created successfully! 🎉', Colors.green);
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context);
      } else {
        // Laravel registration failed — delete the Firebase user to keep in sync
        await userCredential.user?.delete();
        final error = jsonDecode(response.body);
        _snack(
          error['message'] ?? 'Registration failed — please try again',
          Colors.redAccent,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _loading = false);
      // ── Friendly Firebase error messages ─────────────────────────────────
      switch (e.code) {
        case 'email-already-in-use':
          _snack('This email is already registered', Colors.redAccent);
          break;
        case 'weak-password':
          _snack('Password is too weak — use at least 8 characters',
              Colors.orange);
          break;
        case 'invalid-email':
          _snack('Invalid email address', Colors.orange);
          break;
        case 'network-request-failed':
          _snack('No internet connection', Colors.redAccent);
          break;
        default:
          _snack(e.message ?? 'Sign up failed', Colors.redAccent);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      debugPrint('Signup error: $e');
      _snack('Server error — check your connection', Colors.redAccent);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
      backgroundColor: color,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
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

                // ── PURPLE HERO SECTION ──────────────────────────────────
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
                          padding: const EdgeInsets.fromLTRB(
                              24, 36, 24, 52),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    width:  38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white
                                          .withValues(alpha: 0.15),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.30),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      color: Colors.white,
                                      size:  16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Center(
                                child: Container(
                                  width:        80,
                                  height:       80,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: 0.30),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.20),
                                        blurRadius: 24,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    'assets/images/maps_logo.png',
                                    fit:    BoxFit.cover,
                                    width:  80,
                                    height: 80,
                                    errorBuilder: (_, __, ___) =>
                                        Container(
                                          color: Colors.white
                                              .withValues(alpha: 0.15),
                                          child: const Icon(
                                            Icons.local_cafe_rounded,
                                            color: Colors.white,
                                            size:  34,
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
                                  fontSize:   24,
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
                                  'CREATE ACCOUNT',
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

                // ── FLOATING WHITE CARD ──────────────────────────────────
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
                            'Join Lucky Boba 🧋',
                            style: GoogleFonts.poppins(
                              fontSize:   20,
                              fontWeight: FontWeight.w700,
                              color:      _textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create your account to get started',
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: _textMid),
                          ),
                          const SizedBox(height: 24),

                          _fieldLabel('Full Name'),
                          const SizedBox(height: 7),
                          _inputField(
                            controller: _nameCtrl,
                            hint:       'Juan dela Cruz',
                            icon:       Icons.person_outline_rounded,
                            isPassword: false,
                            obscure:    false,
                          ),
                          const SizedBox(height: 16),

                          _fieldLabel('Email Address'),
                          const SizedBox(height: 7),
                          _inputField(
                            controller: _emailCtrl,
                            hint:       'name@example.com',
                            icon:       Icons.mail_outline_rounded,
                            isPassword: false,
                            obscure:    false,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),

                          _fieldLabel('Password'),
                          const SizedBox(height: 7),
                          _inputField(
                            controller: _passwordCtrl,
                            hint:       '••••••••  (min. 8 characters)',
                            icon:       Icons.lock_outline_rounded,
                            isPassword: true,
                            obscure:    _obscure,
                            onToggle: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                          const SizedBox(height: 16),

                          _fieldLabel('Confirm Password'),
                          const SizedBox(height: 7),
                          _inputField(
                            controller: _confirmCtrl,
                            hint:       '••••••••',
                            icon:       Icons.lock_outline_rounded,
                            isPassword: true,
                            obscure:    _obscureConf,
                            onToggle: () =>
                                setState(() => _obscureConf = !_obscureConf),
                          ),
                          const SizedBox(height: 28),

                          // ── Create Account button ─────────────────────
                          SizedBox(
                            width:  double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _handleSignup,
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
                                      color: _purple
                                          .withValues(alpha: 0.40),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
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
                                    'Create Account',
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

                // ── BELOW CARD — login link ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: _textMid),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          'Sign In',
                          style: GoogleFonts.poppins(
                            fontSize:        13,
                            fontWeight:      FontWeight.w700,
                            color:           _purple,
                            decoration:      TextDecoration.underline,
                            decorationColor: _purple,
                          ),
                        ),
                      ),
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
    required bool                  obscure,
    VoidCallback?                  onToggle,
    TextInputType?                 keyboardType,
  }) {
    return TextField(
      controller:   controller,
      obscureText:  isPassword && obscure,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 14, color: _textDark),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: GoogleFonts.poppins(color: _textMid, fontSize: 13),
        filled:    true,
        fillColor: _surface,
        prefixIcon: Icon(icon, color: _textMid, size: 20),
        suffixIcon: isPassword && onToggle != null
            ? GestureDetector(
          onTap: onToggle,
          child: Icon(
            obscure
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
}