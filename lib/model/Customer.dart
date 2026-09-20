// customer.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String? id;
  final String name;
  final String mobile;
  final List<String> orders; // Order IDs
  final int totalOrders;
  final double totalSpent;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  Customer({
    this.id,
    required this.name,
    required this.mobile,
    this.orders = const [],
    this.totalOrders = 0,
    this.totalSpent = 0.0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Customer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Customer(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      mobile: data['mobile']?.toString() ?? '',
      orders: List<String>.from(data['orders'] ?? []),
      totalOrders: (data['totalOrders'] as num?)?.toInt() ?? 0,
      totalSpent: (data['totalSpent'] as num?)?.toDouble() ?? 0.0,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'mobile': mobile,
      'orders': orders,
      'totalOrders': totalOrders,
      'totalSpent': totalSpent,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  Customer copyWith({
    String? id,
    String? name,
    String? mobile,
    List<String>? orders,
    int? totalOrders,
    double? totalSpent,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      orders: orders ?? this.orders,
      totalOrders: totalOrders ?? this.totalOrders,
      totalSpent: totalSpent ?? this.totalSpent,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}