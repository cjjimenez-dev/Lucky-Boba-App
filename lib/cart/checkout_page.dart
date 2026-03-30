// FILE: lib/cart/checkout_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'cart_page.dart';
import '../config/app_config.dart';
import 'order_tracking_page.dart';

class CheckoutPage extends StatefulWidget {
  final String selectedStore;
  const CheckoutPage({super.key, required this.selectedStore});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  // ── Brand tokens ───────────────────────────────────────────────────────────
  static const Color _purple   = Color(0xFF7C14D4);
  static const Color _orange   = Color(0xFFFF8C00);
  static const Color _bg       = Color(0xFFFAFAFA);
  static const Color _surface  = Color(0xFFF2EEF8);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMid  = Color(0xFF6B6B8A);
  static const Color _green    = Color(0xFF16A34A);

  String _selectedPayment = 'GCash';
  String _orderType       = 'Take Out';
  bool   _isProcessing    = false;

  // ── Loyalty card state ─────────────────────────────────────────────────────
  Map<String, dynamic>? _activeCard;
  String?               _selectedPerk;
  bool                  _cardLoading = true;

  static const Map<String, String> _perkLabels = {
    'buy_1_take_1':   'Buy 1 Take 1 (cheapest free)',
    '10_percent_off': '10% Off total',
  };

  final List<Map<String, dynamic>> _paymentOptions = [
    {'label': 'GCash', 'icon': Icons.account_balance_wallet_rounded},
    {'label': 'Maya',  'icon': Icons.credit_card_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _fetchActiveCard();
  }

  // ── Fetch active loyalty card ──────────────────────────────────────────────
  Future<void> _fetchActiveCard() async {
    try {
      final prefs  = await SharedPreferences.getInstance();
      final token  = prefs.getString('session_token') ?? '';
      final userId = prefs.getInt('user_id') ?? 0;

      final res = await http.get(
        Uri.parse('${AppConfig.apiUrl}/check-card-status/$userId'),
        headers: {
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['has_active_card'] == true && data['card'] != null) {
          if (mounted) {
            setState(() {
              _activeCard  = Map<String, dynamic>.from(data['card']);
              _cardLoading = false;
            });
          }
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _cardLoading = false);
  }

  // ── Totals ─────────────────────────────────────────────────────────────────
  double get _rawTotal => myCart.fold(0.0, (sum, item) {
    final p = item['totalPrice'];
    if (p is double) return sum + p;
    if (p is int)    return sum + p.toDouble();
    return sum + (double.tryParse(p?.toString() ?? '0') ?? 0.0);
  });

  double get cartTotal {
    if (_selectedPerk == '10_percent_off') return _rawTotal * 0.90;
    if (_selectedPerk == 'buy_1_take_1') {
      if (myCart.isEmpty) return _rawTotal;
      double minPrice = double.maxFinite;
      for (final item in myCart) {
        final p = item['unitPrice'];
        final price = p is double
            ? p
            : p is int
            ? p.toDouble()
            : double.tryParse(p?.toString() ?? '0') ?? 0.0;
        if (price < minPrice) minPrice = price;
      }
      return (_rawTotal - minPrice).clamp(0, double.maxFinite);
    }
    return _rawTotal;
  }

  double get _discountAmount => _rawTotal - cartTotal;

  List<String> get _claimedPerks {
    if (_activeCard == null) return [];
    final raw = _activeCard!['claimed_promos'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return [];
  }

  // ── Checkout ───────────────────────────────────────────────────────────────
  Future<void> _handleCheckout() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final prefs        = await SharedPreferences.getInstance();
      final token        = prefs.getString('session_token') ?? '';
      final customerName = prefs.getString('user_name') ?? 'App Customer';
      final customerCode = prefs.getString('user_code') ?? '';
      final userId       = prefs.getInt('user_id') ?? 0;

      final siNumber  = 'APP-${DateTime.now().millisecondsSinceEpoch}';
      final qrPayload =
          'luckyboba|order|$siNumber|user_$userId|${DateTime.now().millisecondsSinceEpoch}';

      final body = jsonEncode({
        'si_number':      siNumber,
        'subtotal':       _rawTotal,
        'total':          cartTotal,
        'discount':       _discountAmount,
        'promo_applied':  _selectedPerk,
        'vatable_sales':  cartTotal / 1.12,
        'vat_amount':     cartTotal - (cartTotal / 1.12),
        'payment_method': _selectedPayment.toLowerCase(),
        'order_type':     _orderType.toLowerCase().replaceAll(' ', '_'),
        'branch_name':    widget.selectedStore,
        'cashier_name':   'Customer App',
        'pax_senior':     0,
        'pax_pwd':        0,
        'cash_tendered':  cartTotal,
        'customer_name':  customerName,
        'customer_code':  customerCode,
        'qr_code':        qrPayload,
        'card_id':        _activeCard?['card_id'],
        'items': myCart
            .map((item) => {
          'menu_item_id': item['id'],
          'name':         item['name'],
          'quantity':     item['quantity'],
          'unit_price':   item['unitPrice'],
          'total_price':  item['totalPrice'],
          if (item['cupSize']  != null) 'cup_size': item['cupSize'],
          if (item['add_ons'] != null) 'add_ons':  item['add_ons'],
        })
            .toList(),
      });

      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/online-orders'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      debugPrint('Checkout status: ${response.statusCode}');
      debugPrint('Checkout body:   ${response.body}');

      if (response.statusCode == 201) {
        final data        = json.decode(response.body);
        final confirmedSi = data['si_number'] ?? siNumber;

        final savedItems = myCart
            .map((item) => {
          'name':     item['name'],
          'quantity': item['quantity'],
          'price':    item['unitPrice'],
        })
            .toList();
        final savedTotal  = cartTotal;
        final savedMethod = _selectedPayment;

        myCart.clear();

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => OrderTrackingPage(
                siNumber:      confirmedSi,
                paymentMethod: savedMethod,
                amount:        savedTotal,
                items:         savedItems,
              ),
            ),
          );
        }
      } else {
        final data = json.decode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:         Text(data['message'] ?? 'Checkout failed.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Checkout error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Order items ───────────────────────────────────
                        _sectionLabel('Order Summary',
                            subtitle: '${myCart.length} items'),
                        const SizedBox(height: 10),
                        _buildOrderItemsList(),
                        const SizedBox(height: 24),

                        // ── Loyalty card perks ────────────────────────────
                        if (_cardLoading) ...[
                          _sectionLabel('Loyalty Card Perk'),
                          const SizedBox(height: 10),
                          _buildPerkLoadingShimmer(),
                          const SizedBox(height: 24),
                        ] else if (_activeCard != null) ...[
                          _sectionLabel(
                            'Loyalty Card Perk',
                            subtitle: _activeCard!['card_title']?.toString() ?? '',
                          ),
                          const SizedBox(height: 10),
                          _buildPerkSelector(),
                          const SizedBox(height: 24),
                        ],

                        // ── Order type ────────────────────────────────────
                        _sectionLabel('Order Type'),
                        const SizedBox(height: 10),
                        _buildOrderTypeToggle(),
                        const SizedBox(height: 24),

                        // ── Payment method ────────────────────────────────
                        _sectionLabel('Payment Method'),
                        const SizedBox(height: 10),
                        ..._paymentOptions
                            .map((opt) => _paymentCard(opt['label'], opt['icon'])),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                _buildBottomPlaceOrderBar(),
              ],
            ),

            if (_isProcessing)
              Container(
                color: Colors.black26,
                child: const Center(
                    child: CircularProgressIndicator(color: _purple)),
              ),
          ],
        ),
      ),
    );
  }

  // ── Loading shimmer for card perk ──────────────────────────────────────────
  Widget _buildPerkLoadingShimmer() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEAF0)),
      ),
      child: const Center(
        child: SizedBox(
          width:  22,
          height: 22,
          child:  CircularProgressIndicator(
              color: _purple, strokeWidth: 2),
        ),
      ),
    );
  }

  // ── Perk selector ──────────────────────────────────────────────────────────
  Widget _buildPerkSelector() {
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEAF0)),
      ),
      child: Column(
        children: [
          // No perk
          _perkTile(
            id:       null,
            label:    'No perk',
            sublabel: 'Pay full price',
            icon:     Icons.do_not_disturb_alt_rounded,
          ),
          const Divider(height: 1, color: Color(0xFFEAEAF0)),

          // Available perks
          ...['buy_1_take_1', '10_percent_off'].map((perkId) {
            final claimed = _claimedPerks.contains(perkId);
            return Column(
              children: [
                _perkTile(
                  id:       perkId,
                  label:    _perkLabels[perkId] ?? perkId,
                  sublabel: claimed ? 'Already used today' : 'Tap to apply',
                  icon:     perkId == 'buy_1_take_1'
                      ? Icons.coffee_rounded
                      : Icons.percent_rounded,
                  disabled: claimed,
                ),
                const Divider(height: 1, color: Color(0xFFEAEAF0)),
              ],
            );
          }),

          // Discount preview
          if (_selectedPerk != null)
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_offer_rounded,
                          size: 14, color: _green),
                      const SizedBox(width: 6),
                      Text('Discount applied',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _green)),
                    ],
                  ),
                  Text('-₱${_discountAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize:   14,
                        fontWeight: FontWeight.w700,
                        color:      _green,
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _perkTile({
    required String?  id,
    required String   label,
    required String   sublabel,
    required IconData icon,
    bool disabled = false,
  }) {
    final selected = _selectedPerk == id;
    return InkWell(
      onTap: disabled ? null : () => setState(() => _selectedPerk = id),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width:  38,
              height: 38,
              decoration: BoxDecoration(
                color: disabled
                    ? Colors.grey.shade100
                    : selected
                    ? _purple.withOpacity(0.10)
                    : _surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size:  18,
                  color: disabled
                      ? Colors.grey
                      : selected
                      ? _purple
                      : _textMid),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.poppins(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color:      disabled ? Colors.grey : _textDark,
                        decoration: disabled
                            ? TextDecoration.lineThrough
                            : null,
                      )),
                  Text(sublabel,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: disabled ? Colors.grey : _textMid)),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: disabled
                  ? Colors.grey
                  : selected
                  ? _purple
                  : _textMid,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────
  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
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
          Text('Review & Payment',
              style: GoogleFonts.poppins(
                  fontSize:   18,
                  fontWeight: FontWeight.w700,
                  color:      _textDark)),
        ],
      ),
    );
  }

  // ── Order items list ───────────────────────────────────────────────────────
  Widget _buildOrderItemsList() {
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAEAF0)),
      ),
      child: ListView.separated(
        shrinkWrap:       true,
        physics:          const NeverScrollableScrollPhysics(),
        itemCount:        myCart.length,
        separatorBuilder: (_, __) =>
        const Divider(height: 1, color: Color(0xFFEAEAF0)),
        itemBuilder: (_, index) => _itemTile(myCart[index]),
      ),
    );
  }

  Widget _itemTile(dynamic item) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${item['quantity']}× ${item['name']}',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            '₱${item['totalPrice']}',
            style: GoogleFonts.poppins(
                fontSize:   14,
                fontWeight: FontWeight.w700,
                color:      _orange),
          ),
        ],
      ),
    );
  }

  // ── Order type toggle ──────────────────────────────────────────────────────
  Widget _buildOrderTypeToggle() {
    return Row(
      children: [
        Expanded(
            child: _orderTypeCard('Dine In', Icons.storefront_rounded)),
        const SizedBox(width: 12),
        Expanded(
            child: _orderTypeCard('Take Out', Icons.shopping_bag_rounded)),
      ],
    );
  }

  Widget _orderTypeCard(String title, IconData icon) {
    final bool selected = _orderType == title;
    return GestureDetector(
      onTap: () => setState(() => _orderType = title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:  const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? _purple : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? _purple : const Color(0xFFEAEAF0)),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.white : _textMid),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                    color:      selected ? Colors.white : _textMid,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ── Payment card ───────────────────────────────────────────────────────────
  Widget _paymentCard(String label, IconData icon) {
    final bool selected = _selectedPayment == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedPayment = label),
      child: Container(
        margin:  const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? _purple.withOpacity(0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? _purple : const Color(0xFFEAEAF0)),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? _purple : _textMid),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal)),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected ? _purple : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom bar ─────────────────────────────────────────────────────────────
  Widget _buildBottomPlaceOrderBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.05),
              blurRadius: 10)
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Discount breakdown
          if (_selectedPerk != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Original',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: _textMid)),
                Text('₱${_rawTotal.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize:   12,
                      color:      _textMid,
                      decoration: TextDecoration.lineThrough,
                    )),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Card discount',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color:    const Color(0xFF16A34A))),
                Text('-₱${_discountAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                        fontSize:   12,
                        fontWeight: FontWeight.w700,
                        color:      const Color(0xFF16A34A))),
              ],
            ),
            const SizedBox(height: 6),
          ],

          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize:       MainAxisSize.min,
                children: [
                  const Text('Total',
                      style: TextStyle(fontSize: 12, color: _textMid)),
                  Text(
                    '₱${cartTotal.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                        fontSize:   22,
                        fontWeight: FontWeight.w800,
                        color:      _purple),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: (myCart.isEmpty || _isProcessing)
                      ? null
                      : _handleCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Place Order',
                      style: TextStyle(
                          color:      Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, {String? subtitle}) {
    return Row(
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize:   16,
                fontWeight: FontWeight.w700,
                color:      _textDark)),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(subtitle,
              style: GoogleFonts.poppins(fontSize: 12, color: _textMid)),
        ],
      ],
    );
  }
}