import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../model/CartItem.dart';
import '../../../model/Category.dart';
import '../../../model/Product.dart';
import '../../../services/FirestoreService.dart';
import '../../../utlity/AppColors.dart';
import 'CartScreen.dart';
import 'TakeOrderDetailScreen.dart';

class TakeOrderScreen extends StatefulWidget {
  final bool isEmbedded;
  const TakeOrderScreen({super.key, this.isEmbedded = false});

  @override
  State<TakeOrderScreen> createState() => _TakeOrderScreenState();
}
class _TakeOrderScreenState extends State<TakeOrderScreen> {
  // ============================================================
  // SERVICES
  // ============================================================

  final FirestoreService _firestoreService = FirestoreService();

  // ============================================================
  // DATA
  // ============================================================

  List<Category> _categories = [];
  List<Product> _products = [];
  List<Product> _demandProducts = [];
  bool _isLoading = true;
  bool _showHighDemand = true;
  String? _selectedCategoryId;
  bool _isProgrammaticScroll = false;
  DateTime? _orderDate;

  // ============================================================
  // SCROLL CONTROLLERS
  // ============================================================

  final ScrollController _productScrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();

  // ============================================================
  // CATEGORY SECTION KEYS
  // ============================================================

  final Map<String, GlobalKey> _categoryKeys = {};

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _productScrollController.addListener(_onProductScroll);
    _loadData();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _productScrollController.removeListener(_onProductScroll);
    _productScrollController.dispose();
    _categoryScrollController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD CATEGORIES + PRODUCTS
  // ============================================================

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final String todayKey = await _firestoreService.getBusinessDateKey(DateTime.now());

      final results = await Future.wait([
        _firestoreService.getCategories(),
        _firestoreService.getActiveProducts(),
        _firestoreService.getDailyProductSalesReport(todayKey),
        _firestoreService.getVendorDetails(),
      ]);

      // ========================================================
      // CATEGORIES
      // ========================================================

      final loadedCategories = results[0] as List<Category>;
      final loadedProducts = results[1] as List<Product>;
      final salesReport = results[2] as List<Map<String, dynamic>>;
      final vendorDetails = results[3] as Map<String, dynamic>?;

      final showHighDemand = vendorDetails?['showHighDemand'] ?? true;
      
      // ========================================================
      // DEMAND PRODUCTS (at least 6 orders today)
      // ========================================================

      final demandProductIds = salesReport
          .where((report) => (report['totalSold'] as num? ?? 0) >= 6)
          .map((report) => report['id'])
          .toSet();

      final demandProducts = showHighDemand 
          ? loadedProducts.where((p) => demandProductIds.contains(p.id)).toList()
          : <Product>[];

      // ========================================================
      // CREATE GLOBAL KEYS
      // ========================================================

      _categoryKeys.clear();
      if (demandProducts.isNotEmpty) {
        _categoryKeys['demand'] = GlobalKey();
      }

      final activeCategories = loadedCategories
          .where((category) => category.active == true)
          .toList();

      activeCategories.sort(
        (a, b) => a.sortOrder.compareTo(b.sortOrder),
      );

      // ========================================================
      // PRODUCTS
      // ========================================================

      // We already have loadedProducts from results[1]

      // ========================================================
      // KEEP ONLY CATEGORIES THAT HAVE PRODUCTS
      // ========================================================

      final productCategoryIds = loadedProducts
          .map((p) => p.categoryId)
          .toSet();

      final visibleCategories = activeCategories.where(
        (category) => productCategoryIds.contains(category.id),
      ).toList();

      for (final category in visibleCategories) {
        _categoryKeys[category.id] = GlobalKey();
      }

      // ========================================================
      // SELECT FIRST CATEGORY
      // ========================================================

      String? selectedCategory;
      if (demandProducts.isNotEmpty) {
        selectedCategory = 'demand';
      } else if (visibleCategories.isNotEmpty) {
        selectedCategory = visibleCategories.first.id;
      }

      if (!mounted) return;

      setState(() {
        _categories = visibleCategories;
        _products = loadedProducts;
        _demandProducts = demandProducts;
        _showHighDemand = showHighDemand;
        _selectedCategoryId = selectedCategory;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load products: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load products: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ============================================================
  // GROUP PRODUCTS BY CATEGORY
  // ============================================================

  List<Product> _productsForCategory(String categoryId) {
    return _products.where(
          (p) => p.categoryId == categoryId,
    ).toList();
  }

  // ============================================================
  // CATEGORY TAP
  // ============================================================

  Future<void> _selectCategory(String categoryId) async {
    if (_selectedCategoryId == categoryId) return;

    setState(() {
      _selectedCategoryId = categoryId;
      _isProgrammaticScroll = true;
    });

    _scrollCategoryChipIntoView(categoryId);

    final key = _categoryKeys[categoryId];
    if (key == null) {
      setState(() => _isProgrammaticScroll = false);
      return;
    }
    
    final context = key.currentContext;
    if (context == null) {
      setState(() => _isProgrammaticScroll = false);
      return;
    }

    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: 0.0,
    );

    // Small delay to ensure scroll stopped before re-enabling listener logic
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() => _isProgrammaticScroll = false);
    }
  }

  // ============================================================
  // SCROLL CATEGORY CHIP INTO VIEW
  // ============================================================

  void _scrollCategoryChipIntoView(String categoryId) {
    int index = _categories.indexWhere(
          (category) => category.id == categoryId,
    );
    if (categoryId == 'demand') {
      index = 0;
    } else if (_demandProducts.isNotEmpty) {
      index += 1;
    }
    
    if (index < 0) return;
    final offset = (index * 110.0).clamp(
      0.0,
      _categoryScrollController.position.maxScrollExtent,
    );
    _categoryScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  // ============================================================
  // DETECT CATEGORY WHILE SCROLLING
  // ============================================================

  void _onProductScroll() {
    if (!_productScrollController.hasClients || _isProgrammaticScroll) return;

    String? visibleCategoryId;
    double bestDistance = double.infinity;

    // Check Demand Section
    if (_demandProducts.isNotEmpty) {
      final key = _categoryKeys['demand'];
      if (key != null && key.currentContext != null) {
        final renderBox = key.currentContext!.findRenderObject() as RenderBox;
        final top = renderBox.localToGlobal(Offset.zero).dy;
        const threshold = 120.0;
        if (top <= threshold + 50) {
          visibleCategoryId = 'demand';
        }
      }
    }

    if (visibleCategoryId == null) {
      for (final category in _categories) {
        final categoryId = category.id;

        final key = _categoryKeys[categoryId];
        if (key == null) continue;

        final context = key.currentContext;
        if (context == null) continue;

        final renderObject = context.findRenderObject();
        if (renderObject == null) continue;

        final renderBox = renderObject as RenderBox;
        final position = renderBox.localToGlobal(Offset.zero);
        final top = position.dy;

        // Threshold: AppBar height (~56) + CategoryBar height (~58) + small buffer
        const threshold = 120.0;

        if (top <= threshold + 50) {
          final distance = (top - threshold).abs();
          if (distance < bestDistance) {
            bestDistance = distance;
            visibleCategoryId = categoryId;
          }
        }
      }
    }

    if (_productScrollController.offset <= 10) {
      if (_categories.isNotEmpty) {
        visibleCategoryId = _demandProducts.isNotEmpty ? 'demand' : _categories.first.id;
      }
    }

    if (visibleCategoryId != null && visibleCategoryId != _selectedCategoryId) {
      setState(() {
        _selectedCategoryId = visibleCategoryId;
      });
      _scrollCategoryChipIntoView(visibleCategoryId);
    }
  }

  // ============================================================
  // PRODUCT TAP - Now opens product detail with options
  // ============================================================

  Future<void> _selectOrderDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _orderDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _orderDate = picked;
      });
      if (mounted) {
        Provider.of<CartManager>(context, listen: false).setSelectedOrderDate(picked);
      }
    }
  }

  void _openProduct(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TakeOrderDetailScreen(
          product: product,
          orderDate: _orderDate,
        ),
      ),
    );
  }

  // ============================================================
  // EMBEDDED TOOLBAR (For Tab View)
  // ============================================================

  Widget _buildEmbeddedToolbar(CartManager cartManager) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Date Selector
          GestureDetector(
            onTap: _selectOrderDate,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today, color: Colors.white, size: 14),
                const SizedBox(width: 8),
                Text(
                  _orderDate == null
                      ? "Current Time"
                      : DateFormat('dd MMM, yyyy').format(_orderDate!),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 20),
              ],
            ),
          ),
          const Spacer(),
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
            onPressed: _isLoading ? null : _loadData,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: "Refresh Products",
          ),
          const SizedBox(width: 16),
          // Cart
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () {
                  if (cartManager.totalItems > 0) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CartScreen(),
                      ),
                    );
                  }
                },
                child: const Icon(Icons.shopping_cart, color: Colors.white, size: 22),
              ),
              if (cartManager.totalItems > 0)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      cartManager.totalItems.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final cartManager = Provider.of<CartManager>(context);

    final content = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0.05),
            AppColors.backgroundColor,
          ],
        ),
      ),
      child: Column(
        children: [
          if (widget.isEmbedded) _buildEmbeddedToolbar(cartManager),
          if (!_isLoading && _categories.isNotEmpty) _buildCategoryBar(),
          Expanded(
            child: _buildProductContent(cartManager),
          ),
          if (cartManager.totalItems > 0)
            _buildCartBottomBar(cartManager),
        ],
      ),
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Take Order",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            GestureDetector(
              onTap: _selectOrderDate,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _orderDate == null
                        ? "Current Time"
                        : DateFormat('dd MMM, yyyy').format(_orderDate!),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 16),
                ],
              ),
            ),
          ],
        ),

        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isLoading ? null : _loadData,
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart, color: Colors.white),
                onPressed: () {
                  if (cartManager.totalItems > 0) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CartScreen(),
                      ),
                    );
                  }
                },
              ),
              if (cartManager.totalItems > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      cartManager.totalItems.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: content,
    );
  }

  // ============================================================
  // CATEGORY BAR
  // ============================================================

  Widget _buildCategoryBar() {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListView(
        controller: _categoryScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          if (_demandProducts.isNotEmpty)
            _buildCategoryChip('demand', 'Demand', _selectedCategoryId == 'demand'),
          ..._categories.map((category) => _buildCategoryChip(category.id, category.name, _selectedCategoryId == category.id)),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String id, String name, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => _selectCategory(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.backgroundColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.textColor.withValues(alpha: 0.15),
            ),
          ),
          child: Text(
            name,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PRODUCT CONTENT
  // ============================================================

  Widget _buildProductContent(CartManager cartManager) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (_products.isEmpty) {
      return _buildEmptyState();
    }

    if (_categories.isEmpty) {
      return _buildNoCategoriesState();
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        controller: _productScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            if (_demandProducts.isNotEmpty) _buildDemandSection(cartManager),
            for (final category in _categories)
              _buildCategorySection(category, cartManager),
            const SizedBox(height: 80), // Space for bottom bar
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DEMAND SECTION
  // ============================================================

  Widget _buildDemandSection(CartManager cartManager) {
    return Container(
      key: _categoryKeys['demand'],
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "High Demand",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.trending_up, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Divider(
                    color: Colors.orange.withValues(alpha: 0.1),
                    thickness: 1,
                  ),
                ),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.75,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _demandProducts.length,
            itemBuilder: (context, index) {
              final product = _demandProducts[index];
              return _ProductGridItem(
                product: product,
                onTap: () {
                  _openProduct(product);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CATEGORY SECTION
  // ============================================================

  Widget _buildCategorySection(
      Category category,
      CartManager cartManager,
      ) {
    final products = _productsForCategory(category.id);

    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      key: _categoryKeys[category.id],
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Divider(
                    color: AppColors.textColor.withValues(alpha: 0.1),
                    thickness: 1,
                  ),
                ),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.75,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _ProductGridItem(
                product: product,
                onTap: () {
                  _openProduct(product);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2,
            size: 64,
            color: AppColors.textColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            "No products available",
            style: TextStyle(
              color: AppColors.textColor.withValues(alpha: 0.5),
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NO CATEGORY STATE
  // ============================================================

  Widget _buildNoCategoriesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category_outlined,
            size: 64,
            color: AppColors.textColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            "No categories available",
            style: TextStyle(
              color: AppColors.textColor.withValues(alpha: 0.5),
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CART BOTTOM BAR
  // ============================================================

  Widget _buildCartBottomBar(CartManager cartManager) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${cartManager.totalItems} items",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textColor,
                    ),
                  ),
                  Text(
                    "₹ ${cartManager.totalAmount.toStringAsFixed(0)}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CartScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Checkout"),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PRODUCT GRID ITEM
// ============================================================================

class _ProductGridItem extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductGridItem({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cartManager = Provider.of<CartManager>(context);
    final totalQuantity = cartManager.getTotalQuantityForProduct(product.id);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE SECTION
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      color: AppColors.backgroundColor,
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: product.images.isNotEmpty
                          ? Image.network(
                              product.images.first,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),
                  ),
                  // QUANTITY BADGE
                  if (totalQuantity > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          totalQuantity.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // QUANTITY CONTROLS OVERLAY
                  Positioned(
                    bottom: 3,
                    right: 4,
                    left: 4,
                    child: totalQuantity > 0
                        ? Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  final items = cartManager.getItemsByProductId(product.id);
                                  if (items.isNotEmpty) {
                                    cartManager.removeItem(items.first.cartKey);
                                  }
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: const Center(
                                  child: Icon(
                                    Icons.remove,
                                    color: AppColors.primary,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Quantity
                          Text(
                            totalQuantity.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontSize: 14,
                            ),
                          ),

                          // Add
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  if (product.options.isNotEmpty) {
                                    onTap();
                                  } else {
                                    cartManager.addItem(
                                      productId: product.id,
                                      productName: product.productName,
                                      price: product.price,
                                      images: product.images,
                                      productDetail: product.productDetail,
                                    );
                                  }
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: const Center(
                                  child: Icon(
                                    Icons.add,
                                    color: AppColors.primary,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                        : Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.add_shopping_cart, color: AppColors.primary, size: 16),
                                onPressed: () {
                                  if (product.options.isNotEmpty) {
                                    onTap();
                                  } else {
                                    cartManager.addItem(
                                      productId: product.id,
                                      productName: product.productName,
                                      price: product.price,
                                      images: product.images,
                                      productDetail: product.productDetail,
                                    );
                                  }
                                },
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            // INFO SECTION
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: AppColors.textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    "₹${product.price.toStringAsFixed(0)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      fontSize: 12,
                    ),
                  ),
                  if (product.options.isNotEmpty)
                    const Text(
                      "Options+",
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 8,
                        fontWeight: FontWeight.w500,
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

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.image_outlined,
        color: AppColors.textColor.withValues(alpha: 0.2),
        size: 32,
      ),
    );
  }
}