import 'package:flutter/foundation.dart';
import 'Order.dart';

import '../screens/Vendor/TakeOrder/TakeOrderDetailScreen.dart';

class CartItem {
  final String productId;
  final String productName;
  final String? productDetail;

  // Selected option
  final String? optionId;
  final String? optionName;

  // Final selling price for this selection
  final double price;

  final List<String> images;

  int quantity;

  CartItem({
    required this.productId,
    required this.productName,
    this.productDetail,
    this.optionId,
    this.optionName,
    required this.price,
    required this.images,
    this.quantity = 1,
  });

  double get totalPrice => price * quantity;

  /// Unique key for cart.
  ///
  /// Same product + same option = same cart item.
  /// Same product + different option = different cart item.
  String get cartKey {
    if (optionId != null && optionId!.isNotEmpty) {
      return '${productId}_$optionId';
    }
    return productId;
  }

  CartItem copyWith({
    int? quantity,
  }) {
    return CartItem(
      productId: productId,
      productName: productName,
      productDetail: productDetail,
      optionId: optionId,
      optionName: optionName,
      price: price,
      images: images,
      quantity: quantity ?? this.quantity,
    );
  }
}



class CartManager with ChangeNotifier {
  final Map<String, CartItem> _items = {};
  DateTime? _customOrderDate;
  OrderModel? _originalOrder;

  Map<String, CartItem> get items => {..._items};
  
  /// Returns the custom date if set, otherwise returns current time.
  DateTime get selectedOrderDate => _customOrderDate ?? DateTime.now();

  /// returns null if no custom date is set.
  DateTime? get customOrderDate => _customOrderDate;

  OrderModel? get originalOrder => _originalOrder;
  String? get editingOrderId => _originalOrder?.id;

  void setSelectedOrderDate(DateTime? date) {
    _customOrderDate = date;
    notifyListeners();
  }

  void loadOrder(OrderModel order) {
    _items.clear();
    for (var item in order.items) {
      final cartItem = CartItem(
        productId: item.productId,
        productName: item.productName,
        productDetail: item.productDetail,
        optionId: item.optionId,
        optionName: item.optionName,
        price: item.price,
        images: item.images,
        quantity: item.quantity,
      );
      _items[cartItem.cartKey] = cartItem;
    }
    _originalOrder = order;
    _customOrderDate = order.createdAt;
    
    notifyListeners();
  }

  int get totalItems {
    return _items.values.fold(
      0,
          (sum, item) => sum + item.quantity,
    );
  }

  double get totalAmount {
    return _items.values.fold(
      0.0,
          (sum, item) => sum + item.totalPrice,
    );
  }

  // ============================================================
  // ADD ITEM (with option support)
  // ============================================================

  void addItem({
    required String productId,
    required String productName,
    required double price,
    required List<String> images,
    String? productDetail,
    String? optionId,
    String? optionName,
  }) {
    final item = CartItem(
      productId: productId,
      productName: productName,
      productDetail: productDetail,
      optionId: optionId,
      optionName: optionName,
      price: price,
      images: images,
      quantity: 1,
    );

    final key = item.cartKey;

    if (_items.containsKey(key)) {
      // If item exists with same product and option, increase quantity
      _items[key] = _items[key]!.copyWith(
        quantity: _items[key]!.quantity + 1,
      );
    } else {
      // New item
      _items[key] = item;
    }

    notifyListeners();
  }

  // Add to CartManager class

// ============================================================
// ADD COMBO ITEM
// ============================================================

  void addComboItem({
    required String productId,
    required String productName,
    required double price,
    required List<String> images,
    String? productDetail,
    required List<ComboItemData> comboItems,
  }) {
    // Create a special cart item for combo
    final item = CartItem(
      productId: productId,
      productName: productName,
      productDetail: productDetail,
      optionId: 'combo',
      optionName: 'Combo Pack',
      price: price,
      images: images,
      quantity: 1,
    );

    final key = item.cartKey;

    if (_items.containsKey(key)) {
      _items[key] = _items[key]!.copyWith(
        quantity: _items[key]!.quantity + 1,
      );
    } else {
      _items[key] = item;
    }

    notifyListeners();
  }
  // ============================================================
  // REMOVE ONE ITEM
  // ============================================================

  void removeItem(String cartKey) {
    if (!_items.containsKey(cartKey)) {
      return;
    }

    if (_items[cartKey]!.quantity > 1) {
      _items[cartKey] = _items[cartKey]!.copyWith(
        quantity: _items[cartKey]!.quantity - 1,
      );
    } else {
      _items.remove(cartKey);
    }

    notifyListeners();
  }

  // ============================================================
  // REMOVE ENTIRE ITEM
  // ============================================================

  void clearItem(String cartKey) {
    _items.remove(cartKey);
    notifyListeners();
  }

  // ============================================================
  // CLEAR CART
  // ============================================================

  void clear() {
    _items.clear();
    _customOrderDate = null;
    _originalOrder = null;
    notifyListeners();
  }

  void clearCart() => clear();

  // ============================================================
  // QUANTITY
  // ============================================================

  int getQuantity(String cartKey) {
    return _items[cartKey]?.quantity ?? 0;
  }

  // ============================================================
  // CHECK ITEM
  // ============================================================

  bool containsItem(String cartKey) {
    return _items.containsKey(cartKey);
  }

  // ============================================================
  // GET ITEMS BY PRODUCT ID
  // ============================================================

  List<CartItem> getItemsByProductId(String productId) {
    return _items.values
        .where((item) => item.productId == productId)
        .toList();
  }

  // ============================================================
  // GET TOTAL QUANTITY FOR A PRODUCT
  // ============================================================

  int getTotalQuantityForProduct(String productId) {
    return _items.values
        .where((item) => item.productId == productId)
        .fold(0, (sum, item) => sum + item.quantity);
  }
}