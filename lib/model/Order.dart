import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String customerId;
  final String customerName;
  final String? customerMobile;
  final String? customerAddress;
  final double totalAmount;
  final String status;
  final String orderType; // Dine in / Take away
  final String paymentType; // Cash / UPI
  final int itemCount;
  final List<OrderItem> items;
  final String? note; // Added for order instructions
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? businessDate;

  OrderModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    this.customerMobile,
    this.customerAddress,
    required this.totalAmount,
    required this.status,
    this.orderType = 'Take away',
    this.paymentType = 'Cash',
    required this.itemCount,
    required this.items,
    this.note,
    this.createdAt,
    this.updatedAt,
    this.businessDate,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return OrderModel(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? '',
      customerMobile: data['customerMobile'],
      customerAddress: data['customerAddress'],
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] ?? 'pending',
      orderType: data['orderType'] ?? 'Take away',
      paymentType: data['paymentType'] ?? 'Cash',
      itemCount: (data['itemCount'] as num?)?.toInt() ?? 0,
      items: (data['items'] as List?)
              ?.map((item) => OrderItem.fromMap(item))
              .toList() ??
          [],
      note: data['note'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      businessDate: data['businessDate'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerMobile': customerMobile,
      'customerAddress': customerAddress,
      'totalAmount': totalAmount,
      'status': status,
      'orderType': orderType,
      'paymentType': paymentType,
      'itemCount': itemCount,
      'items': items.map((item) => item.toMap()).toList(),
      'note': note,
      'businessDate': businessDate,
    };
  }
}

class OrderItem {
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final double totalPrice;
  final List<String> images;
  final String? productDetail;
  final String? optionId;
  final String? optionName;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.totalPrice,
    this.images = const [],
    this.productDetail,
    this.optionId,
    this.optionName,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0.0,
      images: List<String>.from(map['images'] ?? []),
      productDetail: map['productDetail'],
      optionId: map['optionId'],
      optionName: map['optionName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'images': images,
      'productDetail': productDetail,
      'optionId': optionId,
      'optionName': optionName,
    };
  }
}
