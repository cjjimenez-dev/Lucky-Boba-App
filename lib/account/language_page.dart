// FILE: lib/pages/language_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  static const Color _purple   = Color(0xFF7C14D4);
  static const Color _bg       = Color(0xFFFAFAFA);
  static const Color _surface  = Color(0xFFF2EEF8);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMid  = Color(0xFF6B6B8A);

  String _selected = 'en';

  final _languages = [
    {'code': 'en', 'name': 'English',  'native': 'English',   'flag': '🇺🇸'},
    {'code': 'fil','name': 'Filipino', 'native': 'Filipino',  'flag': '🇵🇭'},
    {'code': 'ceb','name': 'Cebuano',  'native': 'Bisaya',    'flag': '🇵🇭'},
    {'code': 'ilo','name': 'Ilocano',  'native': 'Ilocano',   'flag': '🇵🇭'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _selected = prefs.getString('app_language') ?? 'en');
  }

  Future<void> _select(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', code);
    setState(() => _selected = code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Language updated!', style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: _purple, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: const BoxDecoration(color: _surface, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _purple),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Language',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: _textDark)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFEAEAF0)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      children: _languages.asMap().entries.map((e) {
                        final lang   = e.value;
                        final sel    = lang['code'] == _selected;
                        final isLast = e.key == _languages.length - 1;
                        return Column(
                          children: [
                            InkWell(
                              onTap: () => _select(lang['code']!),
                              borderRadius: BorderRadius.circular(18),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    Text(lang['flag']!, style: const TextStyle(fontSize: 28)),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(lang['name']!,
                                              style: GoogleFonts.poppins(
                                                  fontSize: 14, fontWeight: FontWeight.w600,
                                                  color: sel ? _purple : _textDark)),
                                          Text(lang['native']!,
                                              style: GoogleFonts.poppins(fontSize: 11, color: _textMid)),
                                        ],
                                      ),
                                    ),
                                    if (sel)
                                      Container(
                                        width: 24, height: 24,
                                        decoration: const BoxDecoration(color: _purple, shape: BoxShape.circle),
                                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                                      )
                                    else
                                      Container(
                                        width: 24, height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: const Color(0xFFDDD8F0), width: 1.5),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (!isLast)
                              Padding(
                                padding: const EdgeInsets.only(left: 58, right: 16),
                                child: Divider(height: 1, color: Colors.grey[100]),
                              ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _purple.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _purple.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: _purple, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Full translation support coming soon. Some screens may remain in English.',
                              style: GoogleFonts.poppins(fontSize: 12, color: _purple)),
                        ),
                      ],
                    ),
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