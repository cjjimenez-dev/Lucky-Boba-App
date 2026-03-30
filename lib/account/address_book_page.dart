// FILE: lib/pages/address_book_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AddressBookPage extends StatefulWidget {
  const AddressBookPage({super.key});

  @override
  State<AddressBookPage> createState() => _AddressBookPageState();
}

class _AddressBookPageState extends State<AddressBookPage> {
  static const Color _purple   = Color(0xFF7C14D4);
  static const Color _bg       = Color(0xFFFAFAFA);
  static const Color _surface  = Color(0xFFF2EEF8);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMid  = Color(0xFF6B6B8A);

  List<Map<String, dynamic>> _addresses = [];

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString('saved_addresses');
    if (raw != null) {
      final decoded = json.decode(raw);
      setState(() => _addresses = List<Map<String, dynamic>>.from(decoded));
    }
  }

  Future<void> _saveAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_addresses', json.encode(_addresses));
  }

  void _showAddEditDialog({Map<String, dynamic>? existing, int? index}) {
    final labelCtrl   = TextEditingController(text: existing?['label']   ?? '');
    final addressCtrl = TextEditingController(text: existing?['address'] ?? '');
    final cityCtrl    = TextEditingController(text: existing?['city']    ?? '');
    final noteCtrl    = TextEditingController(text: existing?['note']    ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20, right: 20, top: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFEAEAF0), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(existing == null ? 'Add New Address' : 'Edit Address',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: _textDark)),
              const SizedBox(height: 16),
              _field(ctrl: labelCtrl,   hint: 'Label (e.g. Home, Work)',  icon: Icons.label_outline_rounded),
              const SizedBox(height: 10),
              _field(ctrl: addressCtrl, hint: 'Street address',           icon: Icons.home_outlined),
              const SizedBox(height: 10),
              _field(ctrl: cityCtrl,    hint: 'City / Municipality',      icon: Icons.location_city_outlined),
              const SizedBox(height: 10),
              _field(ctrl: noteCtrl,    hint: 'Delivery note (optional)', icon: Icons.notes_rounded),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    if (addressCtrl.text.trim().isEmpty) return;
                    final entry = {
                      'label':   labelCtrl.text.trim().isEmpty ? 'Address' : labelCtrl.text.trim(),
                      'address': addressCtrl.text.trim(),
                      'city':    cityCtrl.text.trim(),
                      'note':    noteCtrl.text.trim(),
                    };
                    labelCtrl.dispose(); addressCtrl.dispose();
                    cityCtrl.dispose();  noteCtrl.dispose();
                    Navigator.pop(ctx);
                    setState(() {
                      if (index != null) _addresses[index] = entry;
                      else _addresses.add(entry);
                    });
                    await _saveAddresses();
                  },
                  child: Text('Save Address',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({required TextEditingController ctrl, required String hint, required IconData icon}) {
    return TextField(
      controller: ctrl,
      style: GoogleFonts.poppins(fontSize: 13, color: _textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: _textMid, fontSize: 12),
        prefixIcon: Icon(icon, color: _purple, size: 20),
        filled: true, fillColor: _surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _purple, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                  Expanded(
                    child: Text('Address Book',
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: _textDark)),
                  ),
                  GestureDetector(
                    onTap: () => _showAddEditDialog(),
                    child: Container(
                      width: 40, height: 40,
                      decoration: const BoxDecoration(color: _surface, shape: BoxShape.circle),
                      child: const Icon(Icons.add_rounded, size: 22, color: _purple),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _addresses.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100, height: 100,
                      decoration: const BoxDecoration(color: _surface, shape: BoxShape.circle),
                      child: const Icon(Icons.map_outlined, size: 48, color: _purple),
                    ),
                    const SizedBox(height: 20),
                    Text('No saved addresses',
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: _textDark)),
                    const SizedBox(height: 8),
                    Text('Tap + to add a delivery address',
                        style: GoogleFonts.poppins(fontSize: 13, color: _textMid)),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                itemCount: _addresses.length,
                itemBuilder: (_, i) {
                  final a = _addresses[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEAEAF0)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.location_on_rounded, color: _purple, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a['label'] ?? 'Address',
                                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: _textDark)),
                              Text(a['address'] ?? '',
                                  style: GoogleFonts.poppins(fontSize: 12, color: _textMid), maxLines: 1, overflow: TextOverflow.ellipsis),
                              if ((a['city'] ?? '').isNotEmpty)
                                Text(a['city'],
                                    style: GoogleFonts.poppins(fontSize: 11, color: _textMid)),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (val) async {
                            if (val == 'edit') {
                              _showAddEditDialog(existing: a, index: i);
                            } else {
                              setState(() => _addresses.removeAt(i));
                              await _saveAddresses();
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'edit',
                                child: Text('Edit', style: GoogleFonts.poppins(fontSize: 13))),
                            PopupMenuItem(value: 'delete',
                                child: Text('Delete', style: GoogleFonts.poppins(fontSize: 13, color: Colors.red))),
                          ],
                          icon: const Icon(Icons.more_vert_rounded, color: Color(0xFFCCCCDD), size: 20),
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
    );
  }
}