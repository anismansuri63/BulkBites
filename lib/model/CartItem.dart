import 'package:flutter/foundation.dart';

class CartItem {
  final String productId;
  final String productName;
  final String? productDetail;
  final double price;
  final List<String> images;
  int quantity;

  CartItem({
    required this.productId,
    required this.productName,
    this.productDetail,
    required this.price,
    required this.images,
    this.quantity = 1,
  });

  double get totalPrice => price * quantity;

  CartItem copyWith({
    int? quantity,
  }) {
    return CartItem(
      productId: productId,
      productName: productName,
      productDetail: productDetail,
      price: price,
      images: images,
      quantity: quantity ?? this.quantity,
    );
  }
}

class CartManager with ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => {..._items};

  int get totalItems => _items.values.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount => _items.values.fold(0.0, (sum, item) => sum + item.totalPrice);

  void addItem(String productId, String productName, double price, List<String> images, {String? productDetail}) {
    if (_items.containsKey(productId)) {
      _items[productId] = _items[productId]!.copyWith(quantity: _items[productId]!.quantity + 1);
    } else {
      _items[productId] = CartItem(
        productId: productId,
        productName: productName,
        productDetail: productDetail,
        price: price,
        images: images,
        quantity: 1,
      );
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    if (_items.containsKey(productId)) {
      if (_items[productId]!.quantity > 1) {
        _items[productId] = _items[productId]!.copyWith(quantity: _items[productId]!.quantity - 1);
      } else {
        _items.remove(productId);
      }
      notifyListeners();
    }
  }

  void clearItem(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  bool containsProduct(String productId) {
    return _items.containsKey(productId);
  }

  int getQuantity(String productId) {
    return _items[productId]?.quantity ?? 0;
  }
}
