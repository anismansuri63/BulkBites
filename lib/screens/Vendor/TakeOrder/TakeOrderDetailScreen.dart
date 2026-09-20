// product_detail_purchase_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../model/CartItem.dart';
import '../../../model/Product.dart';
import '../../../utlity/AppColors.dart';

class TakeOrderDetailScreen extends StatefulWidget {
  final Product product;
  final DateTime? orderDate;

  const TakeOrderDetailScreen({
    super.key,
    required this.product,
    this.orderDate,
  });

  @override
  State<TakeOrderDetailScreen> createState() =>
      _TakeOrderDetailScreenState();
}

class _TakeOrderDetailScreenState
    extends State<TakeOrderDetailScreen> {
  ProductOption? _selectedOption;

  // ============================================================
  // COMBO SPECIFIC STATE
  // ============================================================

  final Map<int, int> _comboItemQuantities = {};
  double _comboTotalPrice = 0;

  // ============================================================
  // GETTERS
  // ============================================================

  bool get isCombo => widget.product.isCombo;

  List<ComboItem> get comboItems => widget.product.comboItems;

  double get _currentPrice {
    if (isCombo) {
      return _comboTotalPrice > 0 ? _comboTotalPrice : _getComboBasePrice();
    }

    if (_selectedOption != null) {
      return _selectedOption!.price;
    }
    return widget.product.price;
  }

  String get _currentOptionName {
    if (_selectedOption != null) {
      return _selectedOption!.name;
    }
    return 'Default';
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    // Initialize combo item quantities
    if (isCombo) {
      for (var i = 0; i < comboItems.length; i++) {
        final item = comboItems[i];
        _comboItemQuantities[i] = item.quantity;
      }
      _updateComboTotal();
    }
  }

  // ============================================================
  // COMBO HELPER METHODS
  // ============================================================

  double _getComboBasePrice() {
    double total = 0;
    for (var i = 0; i < comboItems.length; i++) {
      final item = comboItems[i];
      final price = item.price;
      final quantity = _comboItemQuantities[i] ?? 1;
      total += price * quantity;
    }
    return total;
  }

  void _updateComboTotal() {
    double total = 0;
    for (var i = 0; i < comboItems.length; i++) {
      final item = comboItems[i];
      final price = item.price;
      final quantity = _comboItemQuantities[i] ?? 1;
      total += price * quantity;
    }
    setState(() {
      _comboTotalPrice = total;
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final cartManager = Provider.of<CartManager>(context);
    final productName = widget.product.productName;
    final productDetail = widget.product.productDetail;
    final images = widget.product.images;
    final options = widget.product.options;
    final hasOptions = options.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          productName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Combo badge in app bar
          if (isCombo)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.dinner_dining,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'COMBO',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Container(
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==================================================
                    // PRODUCT IMAGES
                    // ==================================================

                    _buildProductImage(images),

                    const SizedBox(height: 20),

                    // ==================================================
                    // PRODUCT INFO
                    // ==================================================

                    _buildProductInfo(productName, productDetail),

                    const SizedBox(height: 20),

                    // ==================================================
                    // COMBO ITEMS (if combo)
                    // ==================================================

                    if (isCombo) _buildComboItems(),

                    // ==================================================
                    // OPTIONS SECTION (if regular product with options)
                    // ==================================================

                    if (!isCombo && hasOptions) _buildOptions(options),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ==================================================
            // BOTTOM BAR
            // ==================================================

            _buildBottomBar(cartManager, productName, images, productDetail),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD METHODS
  // ============================================================

  Widget _buildProductImage(List<String> images) {
    if (images.isNotEmpty) {
      return Container(
        height: 280,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AppColors.cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.network(
            images.first,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported,
                      size: 48,
                      color: AppColors.textColor.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Image not available',
                      style: TextStyle(
                        color: AppColors.textColor.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.cardColor,
      ),
      child: Center(
        child: Icon(
          Icons.image,
          size: 64,
          color: AppColors.textColor.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildProductInfo(String productName, String productDetail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                productName,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),
            ),
            if (isCombo)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
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
        const SizedBox(height: 8),
        if (productDetail.isNotEmpty)
          Text(
            productDetail,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textColor.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "₹ ${_currentPrice.toStringAsFixed(0)}",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              if (isCombo && comboItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '(${comboItems.length} items)',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComboItems() {
    if (comboItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(thickness: 1),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.dinner_dining,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Combo Includes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textColor,
              ),
            ),
            const Spacer(),
            Text(
              '${comboItems.length} items',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(comboItems.length, (index) {
          final item = comboItems[index];
          final itemName = item.productName;
          final price = item.price;
          final optionName = item.optionName;
          final quantity = _comboItemQuantities[index] ?? 1;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.textColor.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Item number
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Item details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textColor,
                          fontSize: 15,
                        ),
                      ),
                      if (optionName != null && optionName.isNotEmpty)
                        Text(
                          'Option: $optionName',
                          style: TextStyle(
                            color: AppColors.textColor.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      Text(
                        '₹ ${price.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildOptions(List<ProductOption> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(thickness: 1),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.tune,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Select Option',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...options.map((option) {
          final isSelected = option.id == _selectedOption?.id;

          return GestureDetector(
            onTap: () {
              setState(() {
                if (_selectedOption?.id == option.id) {
                  _selectedOption = null;
                } else {
                  _selectedOption = option;
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : AppColors.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textColor.withValues(alpha: 0.08),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textColor,
                          ),
                        ),
                        Text(
                          "₹ ${option.price.toStringAsFixed(0)}",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 18,
                        color: Colors.white,
                      ),
                    )
                  else
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.textColor.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBottomBar(
      CartManager cartManager,
      String productName,
      List<String> images,
      String productDetail,
      ) {
    final hasOptions = widget.product.options.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isCombo
                        ? 'Combo Total'
                        : (hasOptions && _selectedOption == null
                        ? 'Select an option'
                        : 'Total'),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textColor.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    "₹ ${_currentPrice.toStringAsFixed(0)}",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  if (isCombo)
                    Text(
                      '${comboItems.length} items included',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textColor.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                // Validate option selection for regular products
                if (!isCombo && hasOptions && _selectedOption == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please select an option first"),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                // Add to cart
                if (isCombo) {
                  // For combo, we add the combo itself as a product
                  // The combo items are stored in the product data
                  cartManager.addComboItem(
                    productId: widget.product.id,
                    productName: productName,
                    price: _currentPrice,
                    images: images,
                    productDetail: productDetail,
                    comboItems: comboItems.map((item) {
                      return ComboItemData(
                        productId: item.productId,
                        productName: item.productName,
                        price: item.price,
                        optionId: item.optionId,
                        optionName: item.optionName,
                        quantity: item.quantity, // Using item.quantity from model
                      );
                    }).toList(),
                  );
                } else {
                  cartManager.addItem(
                    productId: widget.product.id,
                    productName: productName,
                    price: _currentPrice,
                    images: images,
                    productDetail: productDetail,
                    optionId: _selectedOption?.id,
                    optionName: _currentOptionName,
                  );
                }
                // Navigate back
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
                shadowColor: AppColors.primary.withValues(alpha: 0.3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.shopping_cart,
                    size: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Add to Cart',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
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

// ============================================================
// COMBO ITEM DATA MODEL
// ============================================================

class ComboItemData {
  final String productId;
  final String productName;
  final double price;
  final String? optionId;
  final String? optionName;
  final int quantity;

  ComboItemData({
    required this.productId,
    required this.productName,
    required this.price,
    this.optionId,
    this.optionName,
    required this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
      'optionId': optionId,
      'optionName': optionName,
      'quantity': quantity,
    };
  }
}