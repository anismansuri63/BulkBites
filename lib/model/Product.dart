import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String productName;
  final String productDetail;
  final String categoryId;
  final String? categoryName;
  final double price;
  final List<String> images;
  final bool active;
  final List<ComboItem> comboItems;
  final bool isCombo;
  final double comboTotalPrice;
  final List<ProductOption> options;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product({
    required this.id,
    required this.productName,
    required this.productDetail,
    required this.categoryId,
    this.categoryName,
    required this.price,
    required this.images,
    required this.active,
    this.comboItems = const [],
    this.isCombo = false,
    this.comboTotalPrice = 0,
    this.options = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      productName: data['productName'] ?? '',
      productDetail: data['productDetail'] ?? '',
      categoryId: data['categoryId'] ?? '',
      categoryName: data['categoryName'],
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      images: List<String>.from(data['images'] ?? []),
      active: data['active'] ?? false,
      isCombo: data['isCombo'] ?? false,
      comboTotalPrice: (data['comboTotalPrice'] as num?)?.toDouble() ?? 0.0,
      comboItems: (data['comboItems'] as List?)
              ?.map((item) => ComboItem.fromMap(item))
              .toList() ??
          [],
      options: (data['options'] as List?)
              ?.map((item) => ProductOption.fromMap(item))
              .toList() ??
          [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productName': productName,
      'productDetail': productDetail,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'price': price,
      'images': images,
      'active': active,
      'isCombo': isCombo,
      'comboTotalPrice': comboTotalPrice,
      'comboItems': comboItems.map((item) => item.toMap()).toList(),
      'options': options.map((item) => item.toMap()).toList(),
    };
  }
}

class ComboItem {
  final String productId;
  final String productName;
  final double price;
  final String? optionId;
  final String? optionName;
  final int quantity;

  ComboItem({
    required this.productId,
    required this.productName,
    required this.price,
    this.optionId,
    this.optionName,
    this.quantity = 1,
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

  factory ComboItem.fromMap(Map<String, dynamic> map) {
    return ComboItem(
      productId: map['productId']?.toString() ?? '',
      productName: map['productName']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      optionId: map['optionId']?.toString(),
      optionName: map['optionName']?.toString(),
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}

class ProductOption {
  final String id;
  final String name;
  final double price;

  ProductOption({
    required this.id,
    required this.name,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
    };
  }

  factory ProductOption.fromMap(Map<String, dynamic> map) {
    return ProductOption(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
