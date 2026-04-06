  // FILE: lib/pages/menu_page.dart
  import 'package:flutter/material.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:phosphor_flutter/phosphor_flutter.dart';
  import 'package:http/http.dart' as http;
  import 'dart:convert';
  import 'item_customization_page.dart';
  import 'cart_page.dart';
  import '../config/app_config.dart';
  
  class MenuPage extends StatefulWidget {
    final String? selectedStore;
    final String? initialCategory;
    final int?    branchId; // ✅ branch_id from branches table (null = no filter)
  
    const MenuPage({
      super.key,
      this.selectedStore,
      this.initialCategory,
      this.branchId,
    });
  
    @override
    State<MenuPage> createState() => _MenuPageState();
  }
  
  class _MenuPageState extends State<MenuPage> {
    static const Set<String> _hiddenCategories = {
      'PROMOS',
      'GRAND OPENING PROMO',
      'FREEBIES',
    };
  
    static const Color _purple   = Color(0xFF7C14D4);
    static const Color _orange   = Color(0xFFFF8C00);
    static const Color _bg       = Color(0xFFFAFAFA);
    static const Color _surface  = Color(0xFFF2EEF8);
    static const Color _textDark = Color(0xFF1A1A2E);
    static const Color _textMid  = Color(0xFF6B6B8A);
  
    int           _selectedCategoryIndex = 0;
    List<dynamic> _allMenuItems          = [];
    List<String>  _categories            = [];
    bool          _isLoading             = true;
  
    final ScrollController _chipScrollCtrl = ScrollController();
  
    @override
    void initState() {
      super.initState();
      _fetchMenu();
    }
  
    @override
    void dispose() {
      _chipScrollCtrl.dispose();
      super.dispose();
    }
  
    Future<void> _fetchMenu() async {
      try {
        // ✅ Append branch_id query param if available so the backend
        //    filters by per-branch availability overrides.
        String url = '${AppConfig.apiUrl}/public-menu';
        if (widget.branchId != null) {
          url += '?branch_id=${widget.branchId}';
        }
  
        debugPrint('📡 [MenuPage] Fetching: $url');
  
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 15));
  
        debugPrint('📡 [MenuPage] Status: ${response.statusCode}');
  
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
  
          if (data.isNotEmpty) {
            debugPrint('🔍 [MenuPage] FIRST RAW ITEM: ${data.first}');
            debugPrint('🔍 [MenuPage] image field = ${data.first['image']}');
            debugPrint('🔍 [MenuPage] AppConfig.storageUrl = ${AppConfig.storageUrl}');
          } else {
            debugPrint('⚠️ [MenuPage] API returned empty list');
          }
  
          final Set<String>   cats           = {};
          final List<dynamic> sanitizedItems = [];
  
          for (var item in data) {
            String cat = item['category']?.toString().trim() ?? '';
            if (cat.isEmpty || cat == 'null') cat = 'General';
            if (_hiddenCategories.contains(cat.toUpperCase())) continue;
            item['category'] = cat;
            cats.add(cat);
            sanitizedItems.add(item);
          }
  
          final sortedCats = cats.toList()..sort();
  
          // Jump to initialCategory if provided
          int startIndex = 0;
          if (widget.initialCategory != null) {
            final idx = sortedCats.indexWhere(
                  (c) =>
              c.toLowerCase().contains(
                widget.initialCategory!.toLowerCase(),
              ) ||
                  widget.initialCategory!.toLowerCase().contains(
                    c.toLowerCase(),
                  ),
            );
            if (idx != -1) startIndex = idx;
          }
  
          setState(() {
            _allMenuItems          = sanitizedItems;
            _categories            = sortedCats.isEmpty ? ['General'] : sortedCats;
            _selectedCategoryIndex = startIndex;
            _isLoading             = false;
          });
  
          if (startIndex > 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _chipScrollCtrl.animateTo(
                startIndex * 110.0,
                duration: const Duration(milliseconds: 400),
                curve:    Curves.easeOut,
              );
            });
          }
        } else {
          debugPrint('❌ [MenuPage] Bad status: ${response.statusCode}');
          debugPrint('❌ [MenuPage] Body: ${response.body}');
          setState(() => _isLoading = false);
        }
      } catch (e) {
        debugPrint('❌ [MenuPage] Fetch error: $e');
        setState(() => _isLoading = false);
      }
    }
  
    String? _buildImageUrl(dynamic rawImage) {
      String? imageUrl = rawImage?.toString().trim();
  
      if (imageUrl == null || imageUrl.isEmpty || imageUrl == 'null') {
        return null;
      }
  
      if (imageUrl.startsWith('http')) {
        imageUrl = imageUrl.replaceAll('http://localhost:', 'http://10.0.2.2:');
        return imageUrl;
      }
  
      if (imageUrl.startsWith('/')) imageUrl = imageUrl.substring(1);
      return Uri.encodeFull('${AppConfig.storageUrl}/$imageUrl');
    }
  
    List<Map<String, dynamic>> get _groupedCurrentItems {
      if (_categories.isEmpty) return [];
      final categoryItems = _allMenuItems
          .where((i) => i['category'] == _categories[_selectedCategoryIndex])
          .toList();
      final Map<String, List<dynamic>> grouped = {};
      for (final item in categoryItems) {
        final name = (item['name'] ?? '').toString().trim();
        grouped.putIfAbsent(name, () => []).add(item);
      }
      return grouped.entries.map((entry) {
        final variants = entry.value;
        variants.sort((a, b) {
          final priceA = double.tryParse(
              a['sellingPrice']?.toString() ??
                  a['price']?.toString() ??
                  '0') ??
              0;
          final priceB = double.tryParse(
              b['sellingPrice']?.toString() ??
                  b['price']?.toString() ??
                  '0') ??
              0;
          return priceA.compareTo(priceB);
        });
        final representative = Map<String, dynamic>.from(variants.first as Map);
        representative['variants'] = variants;
        return representative;
      }).toList();
    }
  
    @override
    Widget build(BuildContext context) {
      final groupedItems = _groupedCurrentItems;
  
      return Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── APP BAR ────────────────────────────────────────────────────
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lucky Menu',
                            style: GoogleFonts.poppins(
                              fontSize:   18,
                              fontWeight: FontWeight.w700,
                              color:      _textDark,
                            ),
                          ),
                          Text(
                            widget.selectedStore ?? 'Select a Branch',
                            style: GoogleFonts.poppins(
                              fontSize:   12,
                              color:      _textMid,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CartPage(
                            selectedStore: widget.selectedStore ?? '',
                          ),
                        ),
                      ),
                      child: Container(
                        width:  40,
                        height: 40,
                        decoration: const BoxDecoration(
                            color: _surface, shape: BoxShape.circle),
                        child: const Icon(PhosphorIconsRegular.shoppingCart,
                            size: 20, color: _purple),
                      ),
                    ),
                  ],
                ),
              ),
  
              // ── CATEGORY CHIPS ─────────────────────────────────────────────
              SizedBox(
                height: 40,
                child: ListView.builder(
                  controller:      _chipScrollCtrl,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount:       _categories.length,
                  itemBuilder: (context, index) {
                    final bool selected = index == _selectedCategoryIndex;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedCategoryIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin:   const EdgeInsets.only(right: 10),
                        padding:  const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? _purple : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? _purple : const Color(0xFFEAEAF0),
                            width: 1,
                          ),
                          boxShadow: selected
                              ? [
                            BoxShadow(
                              color:      _purple.withValues(alpha: 0.20),
                              blurRadius: 8,
                              offset:     const Offset(0, 3),
                            )
                          ]
                              : [],
                        ),
                        child: Text(
                          _categories[index],
                          style: GoogleFonts.poppins(
                            fontSize:   12,
                            fontWeight: FontWeight.w600,
                            color:      selected ? Colors.white : _textMid,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
  
              const SizedBox(height: 14),
  
              // ── MENU GRID ──────────────────────────────────────────────────
              Expanded(
                child: _isLoading
                    ? const Center(
                    child: CircularProgressIndicator(color: _purple))
                    : groupedItems.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorIconsRegular.coffee,
                          size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        'No items in this category',
                        style: GoogleFonts.poppins(
                            color: _textMid, fontSize: 14),
                      ),
                    ],
                  ),
                )
                    : RefreshIndicator(
                  onRefresh:       _fetchMenu,
                  color:           _purple,
                  backgroundColor: Colors.white,
                  child: GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    cacheExtent: 300,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:   2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing:  14,
                      childAspectRatio: 0.72,
                    ),
                    itemCount:   groupedItems.length,
                    itemBuilder: (context, index) =>
                        _buildItemCard(groupedItems[index]),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  
    Widget _buildItemCard(Map<String, dynamic> item) {
      final String        itemName  = item['name'] ?? 'Boba Drink';
      final String?       imageUrl  = _buildImageUrl(item['image']);
      final List<dynamic> variants  =
          item['variants'] as List<dynamic>? ?? [item];
  
      final double startingPrice = double.tryParse(
          item['sellingPrice']?.toString() ??
              item['price']?.toString() ??
              '0') ??
          0.0;
  
      final bool hasMultiplePrices = variants.length > 1 &&
          variants.any((v) {
            final p = double.tryParse(v['sellingPrice']?.toString() ??
                v['price']?.toString() ??
                '0') ??
                0.0;
            return p != startingPrice;
          });
  
      return GestureDetector(
        onTap: () {
          final List<Map<String, dynamic>> normalizedVariants =
          variants.map<Map<String, dynamic>>((v) {
            final map = Map<String, dynamic>.from(v as Map);
            final raw = map['sellingPrice'] ?? map['price'];
            map['price'] = (raw is double)
                ? raw
                : (raw is int)
                ? raw.toDouble()
                : double.tryParse(raw?.toString() ?? '0') ?? 0.0;
            map['image'] = _buildImageUrl(map['image']);
            return map;
          }).toList();
  
          final Map<String, dynamic> itemToPass = Map.from(item);
          itemToPass['image']    = imageUrl;
          itemToPass['price']    = startingPrice;
          itemToPass['variants'] = normalizedVariants;
  
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ItemCustomizationPage(
                item:          itemToPass,
                selectedStore: widget.selectedStore ?? '',
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEAEAF0), width: 1),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset:     const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18)),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? _SafeNetworkImage(
                      url:         imageUrl,
                      placeholder: _buildPlaceholderImage())
                      : _buildPlaceholderImage(),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment:  MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        itemName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize:   12,
                          color:      _textDark,
                          height:     1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              hasMultiplePrices
                                  ? 'from ₱${startingPrice.toStringAsFixed(0)}'
                                  : '₱${startingPrice.toStringAsFixed(0)}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                color:      _orange,
                                fontSize:   13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color:        _purple,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.add_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ],
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
  
    Widget _buildPlaceholderImage() {
      return Container(
        color: const Color(0xFFF2EEF8),
        width: double.infinity,
        child: const Center(
          child: Icon(PhosphorIconsRegular.coffee,
              color: Color(0xFF7C14D4), size: 36),
        ),
      );
    }
  }
  
  // ── Safe network image ─────────────────────────────────────────────────────
  class _SafeNetworkImage extends StatefulWidget {
    final String url;
    final Widget placeholder;
    static const int maxRetries = 3;
  
    const _SafeNetworkImage({
      required this.url,
      required this.placeholder,
    });
  
    @override
    State<_SafeNetworkImage> createState() => _SafeNetworkImageState();
  }
  
  class _SafeNetworkImageState extends State<_SafeNetworkImage> {
    int  _attempt = 0;
    bool _failed  = false;
    bool _ready   = false;
    late Key _imageKey;
  
    @override
    void initState() {
      super.initState();
      _imageKey = UniqueKey();
      final delay =
      Duration(milliseconds: (widget.url.hashCode.abs() % 3000) + 500);
      Future.delayed(delay, () {
        if (mounted) setState(() => _ready = true);
      });
    }
  
    void _retry() {
      if (!mounted) return;
      if (_attempt >= _SafeNetworkImage.maxRetries) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _failed = true);
        });
        return;
      }
      Future.delayed(Duration(seconds: _attempt + 1), () {
        if (mounted) {
          setState(() {
            _attempt++;
            _failed   = false;
            _imageKey = UniqueKey();
          });
        }
      });
    }
  
    @override
    Widget build(BuildContext context) {
      if (_failed) return widget.placeholder;
      if (!_ready) return widget.placeholder;
  
      return Image.network(
        widget.url,
        key:   _imageKey,
        width: double.infinity,
        fit:   BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ [Image] Failed to load: ${widget.url}');
          _retry();
          return widget.placeholder;
        },
      );
    }
  }