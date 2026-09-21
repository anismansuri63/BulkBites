import 'package:bulk_bites/screens/Vendor/Category/CategoryListScreen.dart';
import 'package:flutter/material.dart';

import '../../../model/Category.dart';
import '../../../model/Product.dart';
import '../../../services/FirestoreService.dart';
import '../../../utlity/AppColors.dart';
import 'AddProductScreen.dart';
import '../Category/AddCategoryScreen.dart';

class ProductListScreen extends StatefulWidget {
  final bool isEmbedded;
  const ProductListScreen({super.key, this.isEmbedded = false});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}


class _ProductListScreenState extends State<ProductListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final Set<String> _collapsedCategories = {};
  late Stream<List<Category>> _categoriesStream;
  late Stream<List<Product>> _productsStream;

  @override
  void initState() {
    super.initState();
    _categoriesStream = _firestoreService.getCategoriesStream();
    _productsStream = _firestoreService.getProductsStream();
  }

  Future<void> _deleteProduct(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: AppColors.cardColor,
        title: const Text(
          "Delete Product",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textColor,
          ),
        ),
        content: const Text(
          "Are you sure you want to delete this product?",
          style: TextStyle(color: AppColors.textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              "Cancel",
              style: TextStyle(color: AppColors.error),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return; // User cancelled

    try {
      await _firestoreService.deleteProduct(docId);
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to delete: $e"),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
  // In ProductListScreen
  void _editProduct(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductScreen(
          title: "Edit Product",
          productId: product.id, // Pass the document ID for updating
          initialData: product.toMap(), // Pass the existing product data
        ),
      ),
    );
  }
  void _showProductDetails(Product product) {
    final isCombo = product.isCombo;
    final comboItems = product.comboItems;
    final options = product.options;
    final hasOptions = options.isNotEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================
              // DRAG HANDLE
              // ==================================================

              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==================================================
              // HEADER
              // ==================================================

              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.productName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textColor,
                      ),
                    ),
                  ),
                  if (isCombo)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.dinner_dining,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'COMBO',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // ==================================================
              // IMAGE
              // ==================================================

              if (product.images.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    product.images[0],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.image_not_supported,
                            size: 48,
                            color: AppColors.textColor.withValues(alpha: 0.3),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 12),

              // ==================================================
              // DETAIL
              // ==================================================

              if (product.productDetail.isNotEmpty)
                Text(
                  product.productDetail,
                  style: TextStyle(
                    color: AppColors.textColor.withValues(alpha: 0.7),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),

              const SizedBox(height: 12),

              // ==================================================
              // PRICE
              // ==================================================

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "₹ ${product.price.toStringAsFixed(0)}",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    if (isCombo && comboItems.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• ${comboItems.length} items',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ==================================================
              // SCROLLABLE CONTENT
              // ==================================================

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // COMBO ITEMS
                      if (isCombo && comboItems.isNotEmpty) ...[
                        Text(
                          'Combo Includes:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...comboItems.map((item) {
                          final itemName = item.productName;
                          final quantity = item.quantity;
                          final price = item.price;
                          final optionName = item.optionName;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor:
                                  AppColors.primary.withOpacity(0.1),
                                  child: Text(
                                    '${comboItems.indexOf(item) + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    itemName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (optionName != null &&
                                    optionName.isNotEmpty)
                                  Text(
                                    '($optionName)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                      AppColors.textColor.withOpacity(0.5),
                                    ),
                                  ),
                                Text(
                                  ' ×$quantity',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textColor.withOpacity(0.6),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '₹${(price * quantity).toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                      ],

                      // OPTIONS
                      if (!isCombo && hasOptions) ...[
                        Text(
                          'Options Available:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...options.map((option) {
                          final optionName = option.name;
                          final optionPrice = option.price;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    optionName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textColor,
                                    ),
                                  ),
                                ),
                                Text(
                                  '₹${optionPrice.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ==================================================
              // CLOSE BUTTON
              // ==================================================

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryHeader(
    String title, {
    Key? key,
    required bool isCollapsed,
    required int itemCount,
  }) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          if (isCollapsed) {
            _collapsedCategories.remove(title);
          } else {
            _collapsedCategories.add(title);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(top: 16, bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$itemCount',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: isCollapsed ? -0.25 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.textColor.withValues(alpha: 0.7),
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Divider(
              color: AppColors.primary.withValues(alpha: 0.3),
              thickness: 1.5,
              height: 1,
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildProductCard(Product product, {Key? key}) {
    final isAvailable = product.active;

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAvailable
              ? AppColors.textColor.withValues(alpha: 0.08)
              : AppColors.textColor.withValues(alpha: 0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // ==================== TOP CONTENT ====================
            GestureDetector(
              onTap: () => _showProductDetails(product),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Image Container
                    Stack(
                      children: [
                        Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: AppColors.backgroundColor,
                            border: Border.all(
                              color: AppColors.textColor.withValues(alpha: 0.05),
                            ),
                          ),
                          child: product.images.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    product.images[0],
                                    width: 82,
                                    height: 82,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.image_not_supported_outlined,
                                        color: AppColors.textColor
                                            .withValues(alpha: 0.3),
                                        size: 28,
                                      );
                                    },
                                  ),
                                )
                              : Icon(
                                  Icons.fastfood_outlined,
                                  color: AppColors.textColor
                                      .withValues(alpha: 0.25),
                                  size: 32,
                                ),
                        ),
                        if (product.isCombo)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'COMBO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),

                    // Product Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  product.productName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isAvailable
                                        ? AppColors.textColor
                                        : AppColors.textColor
                                            .withValues(alpha: 0.5),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (product.productDetail.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              product.productDetail,
                              style: TextStyle(
                                color: AppColors.textColor
                                    .withValues(alpha: 0.55),
                                fontSize: 13,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          // Price Tag
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "₹ ${product.price.toStringAsFixed(0)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                fontSize: 15,
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

            // Divider
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.textColor.withValues(alpha: 0.06),
            ),

            // ==================== BOTTOM ACTIONS ====================
            Container(
              color: AppColors.backgroundColor.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Available Switch
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isAvailable ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Available",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isAvailable
                              ? AppColors.textColor.withValues(alpha: 0.85)
                              : AppColors.textColor.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        height: 28,
                        child: Transform.scale(
                          scale: 0.75,
                          child: Switch(
                            value: product.active,
                            activeThumbColor: AppColors.primary,
                            activeTrackColor:
                                AppColors.primary.withValues(alpha: 0.35),
                            onChanged: (bool value) async {
                              try {
                                await _firestoreService.updateProduct(
                                  product.id,
                                  {'active': value},
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text("Failed to update product: $e"),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit Button
                      InkWell(
                        onTap: () => _editProduct(product),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.edit_outlined,
                                size: 15,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Edit",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Delete Button
                      InkWell(
                        onTap: () => _deleteProduct(product.id),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.delete_outline,
                                size: 15,
                                color: AppColors.error,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Delete",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      child: StreamBuilder<List<Category>>(
        stream: _categoriesStream,
        builder: (context, categorySnapshot) {
          final categories = categorySnapshot.data ?? [];

          return StreamBuilder<List<Product>>(
            stream: _productsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2,
                        size: 64,
                        color: AppColors.textColor.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No products found",
                        style: TextStyle(
                          color: AppColors.textColor.withOpacity(0.5),
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Add a new product to get started",
                        style: TextStyle(
                          color: AppColors.textColor.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final products = snapshot.data!;

              // Group products by category name
              final Map<String, List<Product>> groupedProducts = {};

              // Initialize known categories in order
              for (final cat in categories) {
                if (cat.name.trim().isNotEmpty) {
                  groupedProducts[cat.name.trim()] = [];
                }
              }

              final categoryIdToName = {
                for (var cat in categories) cat.id: cat.name.trim()
              };

              // Group each product
              for (final product in products) {
                String catName = '';
                if (product.categoryName != null && product.categoryName!.trim().isNotEmpty) {
                  catName = product.categoryName!.trim();
                } else if (product.categoryId.isNotEmpty && categoryIdToName.containsKey(product.categoryId)) {
                  catName = categoryIdToName[product.categoryId]!;
                } else {
                  catName = 'Uncategorized';
                }

                groupedProducts.putIfAbsent(catName, () => []).add(product);
              }

              // Remove categories with no products
              groupedProducts.removeWhere((key, list) => list.isEmpty);

              // Flatten into a single list for ListView.builder based on collapsed state
              final List<dynamic> flatList = [];
              groupedProducts.forEach((categoryTitle, categoryProducts) {
                flatList.add(categoryTitle);
                if (!_collapsedCategories.contains(categoryTitle)) {
                  flatList.addAll(categoryProducts);
                }
              });

              return ListView.builder(
                padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80),
                itemCount: flatList.length,
                itemBuilder: (context, index) {
                  final item = flatList[index];

                  if (item is String) {
                    final isCollapsed = _collapsedCategories.contains(item);
                    final itemCount = groupedProducts[item]?.length ?? 0;
                    return _buildCategoryHeader(
                      item,
                      key: ValueKey('cat_$item'),
                      isCollapsed: isCollapsed,
                      itemCount: itemCount,
                    );
                  }

                  final product = item as Product;
                  return _buildProductCard(
                    product,
                    key: ValueKey('prod_${product.id}'),
                  );
                },
              );
            },
          );
        },
      ),
    );

    if (widget.isEmbedded) {
      return Scaffold(
        body: content,
        floatingActionButton: FloatingActionButton(
          foregroundColor: AppColors.cardColor,
          backgroundColor: AppColors.primary,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddProductScreen(title: 'Add Product')),
            );
          },
          child: const Icon(Icons.add),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Product List",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const CategoryListScreen()),
              );
            },
            tooltip: "Add Category",
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        foregroundColor: AppColors.cardColor,
        backgroundColor: AppColors.primary,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddProductScreen(title: 'Add Product')),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: content,
    );
  }
}
