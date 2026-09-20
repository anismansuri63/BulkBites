import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../model/Product.dart';
import '../model/Category.dart';
import '../model/Customer.dart';
import '../model/Order.dart';
import '../model/Expense.dart';
import '../utlity/DateUtils.dart';

class FirestoreService {
  // Singleton pattern
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Current active vendor ID (Set after login)
  String? _currentVendorId;
  String? get vendorId => _currentVendorId;

  void setVendorId(String? id) {
    _currentVendorId = id;
  }

  // References
  DocumentReference get _vendorRef => _firestore.collection('vendors').doc(_currentVendorId);
  CollectionReference get _productsRef => _vendorRef.collection('products');
  CollectionReference get _customersRef => _vendorRef.collection('customers');
  CollectionReference get _ordersRef => _vendorRef.collection('orders');
  CollectionReference get _expensesRef => _vendorRef.collection('expenses');

  // ============================================================
  // EXPENSES
  // ============================================================

  Stream<List<Expense>> getExpensesStream({Map<String, dynamic>? filters}) {
    Query query = _expensesRef.orderBy('date', descending: true);

    if (filters != null) {
      if (filters["dateRange"] is DateTimeRange) {
        final range = filters["dateRange"] as DateTimeRange;
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start));
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(range.end));
      }
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList());
  }

  Future<void> addExpense(Map<String, dynamic> data) async {
    // Handle DateTime to Timestamp conversion
    DateTime dateValue = BBDateUtils.parseDateTime(data['date']) ?? DateTime.now();
    data['date'] = Timestamp.fromDate(dateValue);

    data['createdAt'] = FieldValue.serverTimestamp();
    await _expensesRef.add(data);

    // Update Daily Expense Report
    final String dateKey = "${dateValue.year}${dateValue.month.toString().padLeft(2, '0')}${dateValue.day.toString().padLeft(2, '0')}";
    
    final dailyReportRef = _vendorRef.collection('reports').doc('expenses').collection('daily').doc(dateKey);
    await dailyReportRef.set({
      'totalExpense': FieldValue.increment(data['amount']),
      'expenseCount': FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteExpense(String id, double amount, DateTime date) async {
    await _expensesRef.doc(id).delete();
    
    // Reverse Daily Expense Report
    final String dateKey = "${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}";
    final dailyReportRef = _vendorRef.collection('reports').doc('expenses').collection('daily').doc(dateKey);
    
    // Use set with merge true instead of update to avoid "not-found" error
    await dailyReportRef.set({
      'totalExpense': FieldValue.increment(-amount),
      'expenseCount': FieldValue.increment(-1),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateExpense(String id, Map<String, dynamic> data, double oldAmount, DateTime oldDate) async {
    // Handle DateTime to Timestamp conversion
    DateTime dateValue = BBDateUtils.parseDateTime(data['date']) ?? DateTime.now();
    data['date'] = Timestamp.fromDate(dateValue);
    data['updatedAt'] = FieldValue.serverTimestamp();

    await _expensesRef.doc(id).update(data);

    // Update Daily Expense Report if amount or date changed
    final String oldDateKey = "${oldDate.year}${oldDate.month.toString().padLeft(2, '0')}${oldDate.day.toString().padLeft(2, '0')}";
    final String newDateKey = "${dateValue.year}${dateValue.month.toString().padLeft(2, '0')}${dateValue.day.toString().padLeft(2, '0')}";

    if (oldDateKey == newDateKey) {
      if (oldAmount != data['amount']) {
        final dailyReportRef = _vendorRef.collection('reports').doc('expenses').collection('daily').doc(oldDateKey);
        await dailyReportRef.set({
          'totalExpense': FieldValue.increment(data['amount'] - oldAmount),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } else {
      // Reverse old date report
      final oldDailyReportRef = _vendorRef.collection('reports').doc('expenses').collection('daily').doc(oldDateKey);
      await oldDailyReportRef.set({
        'totalExpense': FieldValue.increment(-oldAmount),
        'expenseCount': FieldValue.increment(-1),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update new date report
      final newDailyReportRef = _vendorRef.collection('reports').doc('expenses').collection('daily').doc(newDateKey);
      await newDailyReportRef.set({
        'totalExpense': FieldValue.increment(data['amount']),
        'expenseCount': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // ============================================================
  // AUTH & ONBOARDING
  // ============================================================

  /// Check if an onboarding code is valid and unused
  Future<DocumentSnapshot?> validateOnboardingCode(String code) async {
    final snapshot = await _firestore
        .collection('onboarding_codes')
        .where('code', isEqualTo: code)
        .where('isUsed', isEqualTo: false)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first;
    }
    return null;
  }

  /// Create a new vendor and their admin user (Firestore Only)
  Future<void> onboardVendor({
    required String code,
    required String email,
    required String password,
    required Map<String, dynamic> vendorDetails,
  }) async {
    final WriteBatch batch = _firestore.batch();

    // 1. Create Vendor Document
    final vendorRef = _firestore.collection('vendors').doc();
    final String newVendorId = vendorRef.id;
    
    batch.set(vendorRef, {
      ...vendorDetails,
      'id': newVendorId,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });

    // 2. Create User Document (Storing password in Firestore)
    final userRef = _firestore.collection('users').doc(); // Auto ID
    final String uid = userRef.id;
    
    batch.set(userRef, {
      'uid': uid,
      'email': email,
      'password': password, // Simple password storage
      'name': vendorDetails['shopName'],
      'role': 'vendor_admin',
      'vendorId': newVendorId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3. Mark code as used
    final codeSnapshot = await validateOnboardingCode(code);
    if (codeSnapshot != null) {
      batch.update(codeSnapshot.reference, {
        'isUsed': true,
        'usedBy': uid,
        'usedAt': FieldValue.serverTimestamp(),
        'vendorId': newVendorId,
      });
    }

    await batch.commit();
    _currentVendorId = newVendorId;
  }

  /// Simple Login: Find user by email and password
  Future<Map<String, dynamic>?> loginWithFirestore(String email, String password) async {
    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .where('password', isEqualTo: password)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return {...snapshot.docs.first.data(), 'uid': snapshot.docs.first.id};
    }
    return null;
  }

  /// Get user role and vendorId after login
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  /// Update User Profile (Name and Email)
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get Current Vendor Details
  Future<Map<String, dynamic>?> getVendorDetails() async {
    if (_currentVendorId == null) return null;
    final doc = await _vendorRef.get();
    return doc.data() as Map<String, dynamic>?;
  }

  /// Update Vendor Details
  Future<void> updateVendorDetails(Map<String, dynamic> details) async {
    if (_currentVendorId == null) return;
    await _vendorRef.update({
      ...details,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get Staff List
  Future<List<String>> getStaffList() async {
    if (_currentVendorId == null) return [];
    final doc = await _vendorRef.get();
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return List<String>.from(data['staffMembers'] ?? []);
  }

  // ============================================================
  // PRINT SETTINGS
  // ============================================================

  Future<Map<String, dynamic>> getPrintSettings(String type) async {
    if (_currentVendorId == null) return {};
    final doc = await _vendorRef.collection('printSettings').doc(type).get();
    return doc.data() ?? {};
  }

  Future<void> updatePrintSettings(String type, Map<String, dynamic> settings) async {
    if (_currentVendorId == null) return;
    await _vendorRef.collection('printSettings').doc(type).set(
      {...settings, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  /// Add Staff Member
  Future<void> addStaffMember(String name) async {
    if (_currentVendorId == null) return;
    await _vendorRef.update({
      'staffMembers': FieldValue.arrayUnion([name]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove Staff Member
  Future<void> removeStaffMember(String name) async {
    if (_currentVendorId == null) return;
    await _vendorRef.update({
      'staffMembers': FieldValue.arrayRemove([name]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Super Admin: Generate a new onboarding code
  Future<String> generateOnboardingCode() async {
    final String code = "SO-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";
    await _firestore.collection('onboarding_codes').add({
      'code': code,
      'isUsed': false,
      'createdAt': FieldValue.serverTimestamp(),
      'role': 'vendor_admin',
    });
    return code;
  }

  // ============================================================
  // PRODUCTS
  // ============================================================

  Stream<List<Product>> getProductsStream() {
    return _productsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList());
  }

  Future<List<Product>> getActiveProducts() async {
    final snapshot = await _productsRef.where('active', isEqualTo: true).get();
    return snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
  }

  Future<void> addProduct(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _productsRef.add(data);
  }

  Future<void> updateProduct(String productId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _productsRef.doc(productId).update(data);
  }

  Future<void> deleteProduct(String productId) async {
    await _productsRef.doc(productId).delete();
  }

  // ============================================================
  // CATEGORIES
  // ============================================================

  Future<List<Category>> getCategories() async {
    final snapshot = await _vendorRef.get();
    final data = snapshot.data() as Map<String, dynamic>? ?? {};
    final List<dynamic> categoriesData =
        List<dynamic>.from(data['categories'] ?? []);

    return categoriesData
        .whereType<Map>()
        .map((cat) => Category.fromMap(Map<String, dynamic>.from(cat)))
        .toList();
  }

  Stream<List<Category>> getCategoriesStream() {
    return _vendorRef.snapshots().map((snapshot) {
      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      final List<dynamic> categoriesData =
          List<dynamic>.from(data['categories'] ?? []);

      final list = categoriesData
          .whereType<Map>()
          .map((cat) => Category.fromMap(Map<String, dynamic>.from(cat)))
          .toList();

      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return list;
    });
  }

  Future<void> addCategory(Map<String, dynamic> categoryData) async {
    final snapshot = await _vendorRef.get();
    final data = snapshot.data() as Map<String, dynamic>? ?? {};
    final List<dynamic> categories = List<dynamic>.from(data['categories'] ?? []);

    final newCategory = {
      ...categoryData,
      'id': 'cat_${DateTime.now().microsecondsSinceEpoch}',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    };

    categories.add(newCategory);
    await _vendorRef.update({'categories': categories});
  }

  Future<void> updateCategory(
      String categoryId, Map<String, dynamic> categoryData) async {
    final snapshot = await _vendorRef.get();
    final data = snapshot.data() as Map<String, dynamic>? ?? {};
    final List<dynamic> categories = List<dynamic>.from(data['categories'] ?? []);

    final updatedCategories = categories.map((item) {
      if (item is Map && item['id']?.toString() == categoryId) {
        return {
          ...item,
          ...categoryData,
          'id': categoryId,
          'updatedAt': Timestamp.now(),
        };
      }
      return item;
    }).toList();

    await _vendorRef.update({'categories': updatedCategories});
  }

  Future<void> deleteCategory(String categoryId) async {
    final snapshot = await _vendorRef.get();
    final data = snapshot.data() as Map<String, dynamic>? ?? {};
    final List<dynamic> categories = List<dynamic>.from(data['categories'] ?? []);

    categories.removeWhere(
        (item) => item is Map && item['id']?.toString() == categoryId);
    await _vendorRef.update({'categories': categories});
  }

  Future<void> toggleCategoryStatus(String categoryId) async {
    final snapshot = await _vendorRef.get();
    final data = snapshot.data() as Map<String, dynamic>? ?? {};
    final List<dynamic> categories = List<dynamic>.from(data['categories'] ?? []);

    final updatedCategories = categories.map((item) {
      if (item is Map && item['id']?.toString() == categoryId) {
        final currentStatus = item['active'] ?? true;
        return {
          ...item,
          'active': !currentStatus,
          'updatedAt': Timestamp.now(),
        };
      }
      return item;
    }).toList();

    await _vendorRef.update({'categories': updatedCategories});
  }

  // ============================================================
  // CUSTOMERS
  // ============================================================

  Stream<List<Customer>> getCustomersStream() {
    return _customersRef.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Customer.fromFirestore(doc)).toList();
    });
  }

  Future<Customer?> getCustomerById(String customerId) async {
    final doc = await _customersRef.doc(customerId).get();
    if (doc.exists) {
      return Customer.fromFirestore(doc);
    }
    return null;
  }

  Future<Customer> addCustomer(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    data['isActive'] = true;
    final docRef = await _customersRef.add(data);
    final doc = await docRef.get();
    return Customer.fromFirestore(doc);
  }

  Future<void> updateCustomer(String customerId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _customersRef.doc(customerId).update(data);
  }

  Future<Customer?> findCustomerByMobile(String mobile) async {
    final snapshot = await _customersRef
        .where('mobile', isEqualTo: mobile)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return Customer.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  Future<void> deleteCustomer(String customerId) async {
    await _customersRef.doc(customerId).delete();
  }

  // ============================================================
  // ORDERS
  // ============================================================

  Stream<List<OrderModel>> getOrdersStream({Map<String, dynamic>? filters}) {
    Query query = _ordersRef;

    try {
      if (filters != null) {
        // 1. Status Filter (Equality)
        var status = (filters["status"] ?? '').toString().toLowerCase();
        if (status.isNotEmpty) {
          query = query.where('status', isEqualTo: status);
        }

        // 2. Customer Filter (Equality)
        if (filters["customerId"] != null && filters["customerId"].isNotEmpty) {
          query = query.where('customerId', isEqualTo: filters["customerId"]);
        }

        // 3. Business Date (Equality)
        if (filters["businessDate"] != null) {
          query = query.where('businessDate', isEqualTo: filters["businessDate"]);
        }

        // 4. Business Date Range (Inequality)
        // Note: If this is used, the FIRST orderBy MUST be 'businessDate'
        if (filters["businessDateRange"] != null) {
          final List<String> range = List<String>.from(filters["businessDateRange"]);
          query = query.where('businessDate', isGreaterThanOrEqualTo: range[0]);
          query = query.where('businessDate', isLessThanOrEqualTo: range[1]);
          // Rule: orderBy must match inequality field first
          query = query.orderBy('businessDate', descending: true);
        }

        // 5. CreatedAt Range (Inequality)
        if (filters["dateRange"] is DateTimeRange) {
          final range = filters["dateRange"] as DateTimeRange;
          query = query.where('createdAt', isGreaterThanOrEqualTo: range.start);
          query = query.where('createdAt', isLessThanOrEqualTo: range.end);
        }
      }

      // Final sort - This often requires a Composite Index if where filters are present
      query = query.orderBy('createdAt', descending: true);

    } catch (e) {
      debugPrint("❌ Error building Firestore query: $e");
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
    }).handleError((error) {
      print(" ");
      print("🚨 [FIRESTORE ERROR] 🚨");
      print("This query failed because it likely needs a Composite Index.");
      print("Look for a URL below to create it automatically:");
      print(error.toString());
      print("🚨 ------------------ 🚨");
      throw error;
    });
  }

  /// Update specific fields of an order
  Future<void> updateOrderFields(String orderId, Map<String, dynamic> data) async {
    await _ordersRef.doc(orderId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> batchUpdateOrderStatus(List<String> orderIds, String newStatus) async {
    final batch = _firestore.batch();
    for (var id in orderIds) {
      batch.update(_ordersRef.doc(id), {
        'status': newStatus.toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    await updateOrderFields(orderId, {'status': newStatus.toLowerCase()});
  }

  Future<void> deleteOrder(String orderId) async {
    final doc = await _ordersRef.doc(orderId).get();
    if (!doc.exists) return;
    
    final order = OrderModel.fromFirestore(doc);
    final WriteBatch batch = _firestore.batch();
    
    final DateTime dateTime = order.createdAt ?? DateTime.now();
    final String dateKey = order.businessDate ?? await getBusinessDateKey(dateTime);
    final String monthKey = dateKey.substring(0, 6);

    // 1. Delete Order Document
    batch.delete(_ordersRef.doc(orderId));

    // 2. Reverse Reports
    final dailyReportRef = _vendorRef.collection('reports').doc('sales').collection('daily').doc(dateKey);
    batch.set(dailyReportRef, {
      'totalRevenue': FieldValue.increment(-order.totalAmount),
      'orderCount': FieldValue.increment(-1),
    }, SetOptions(merge: true));

    final monthlyReportRef = _vendorRef.collection('reports').doc('sales').collection('monthly').doc(monthKey);
    batch.set(monthlyReportRef, {
      'totalRevenue': FieldValue.increment(-order.totalAmount),
      'orderCount': FieldValue.increment(-1),
    }, SetOptions(merge: true));

    for (var item in order.items) {
      final productReportRef = _vendorRef.collection('reports').doc('products').collection('items').doc(item.productId);
      batch.set(productReportRef, {
        'totalSold': FieldValue.increment(-item.quantity),
        'totalRevenue': FieldValue.increment(-item.totalPrice),
      }, SetOptions(merge: true));
    }

    if (order.customerId.isNotEmpty) {
      final customerRef = _customersRef.doc(order.customerId);
      batch.update(customerRef, {
        'totalSpent': FieldValue.increment(-order.totalAmount),
        'totalOrders': FieldValue.increment(-1),
        'orders': FieldValue.arrayRemove([orderId]),
      });
    }

    await batch.commit();
  }

  Future<void> updateOrderFull(String orderId, Map<String, dynamic> newData, OrderModel oldOrder) async {
    final WriteBatch batch = _firestore.batch();
    
    final DateTime oldDateTime = oldOrder.createdAt ?? DateTime.now();
    final String oldDateKey = oldOrder.businessDate ?? await getBusinessDateKey(oldDateTime);
    final String oldMonthKey = oldDateKey.substring(0, 6);

    final DateTime newDateTime = newData['createdAt'] != null 
        ? (newData['createdAt'] as Timestamp).toDate() 
        : DateTime.now();
    final String newDateKey = await getBusinessDateKey(newDateTime);
    final String newMonthKey = newDateKey.substring(0, 6);

    // 1. Update Order Document
    newData['updatedAt'] = FieldValue.serverTimestamp();
    newData['businessDate'] = newDateKey;
    batch.update(_ordersRef.doc(orderId), newData);

    // 2. Reverse Old Reports
    final oldDailyReportRef = _vendorRef.collection('reports').doc('sales').collection('daily').doc(oldDateKey);
    batch.set(oldDailyReportRef, {
      'totalRevenue': FieldValue.increment(-oldOrder.totalAmount),
      'orderCount': FieldValue.increment(-1),
    }, SetOptions(merge: true));

    final oldMonthlyReportRef = _vendorRef.collection('reports').doc('sales').collection('monthly').doc(oldMonthKey);
    batch.set(oldMonthlyReportRef, {
      'totalRevenue': FieldValue.increment(-oldOrder.totalAmount),
      'orderCount': FieldValue.increment(-1),
    }, SetOptions(merge: true));

    for (var item in oldOrder.items) {
      final productReportRef = _vendorRef.collection('reports').doc('products').collection('items').doc(item.productId);
      batch.set(productReportRef, {
        'totalSold': FieldValue.increment(-item.quantity),
        'totalRevenue': FieldValue.increment(-item.totalPrice),
      }, SetOptions(merge: true));
    }

    if (oldOrder.customerId.isNotEmpty) {
       final customerRef = _customersRef.doc(oldOrder.customerId);
       batch.update(customerRef, {
         'totalSpent': FieldValue.increment(-oldOrder.totalAmount),
         'totalOrders': FieldValue.increment(-1),
         'orders': FieldValue.arrayRemove([orderId]),
       });
    }

    // 3. Apply New Reports
    final newDailyReportRef = _vendorRef.collection('reports').doc('sales').collection('daily').doc(newDateKey);
    batch.set(newDailyReportRef, {
      'totalRevenue': FieldValue.increment(newData['totalAmount']),
      'orderCount': FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final newMonthlyReportRef = _vendorRef.collection('reports').doc('sales').collection('monthly').doc(newMonthKey);
    batch.set(newMonthlyReportRef, {
      'totalRevenue': FieldValue.increment(newData['totalAmount']),
      'orderCount': FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final List newItemsList = newData['items'] as List;
    for (var item in newItemsList) {
      final productId = item['productId'];
      final qty = item['quantity'] ?? 1;
      final revenue = item['totalPrice'] ?? 0.0;

      // Overall
      final productReportRef = _vendorRef.collection('reports').doc('products').collection('items').doc(productId);
      batch.set(productReportRef, {
        'productName': item['productName'],
        'totalSold': FieldValue.increment(qty),
        'totalRevenue': FieldValue.increment(revenue),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Today
      final dailyProductReportRef = _vendorRef
          .collection('reports')
          .doc('sales')
          .collection('daily')
          .doc(newDateKey)
          .collection('products')
          .doc(productId);
      batch.set(dailyProductReportRef, {
        'productName': item['productName'],
        'totalSold': FieldValue.increment(qty),
        'totalRevenue': FieldValue.increment(revenue),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    final String? newCustomerId = newData['customerId'];
    if (newCustomerId != null && newCustomerId.isNotEmpty) {
      final customerRef = _customersRef.doc(newCustomerId);
      batch.update(customerRef, {
        'name': newData['customerName'],
        'mobile': newData['customerMobile'] ?? '',
        'totalSpent': FieldValue.increment(newData['totalAmount']),
        'totalOrders': FieldValue.increment(1),
        'orders': FieldValue.arrayUnion([orderId]),
        'lastOrderAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // ============================================================
  // ORDERS & REPORTS
  // ============================================================

  Future<String> getBusinessDateKey(DateTime date) async {
    final vendorDoc = await _vendorRef.get();
    final data = vendorDoc.data() as Map<String, dynamic>? ?? {};
    
    final bool isCustomEnabled = data['isCustomBusinessDay'] ?? false;
    if (!isCustomEnabled) {
      return "${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}";
    }
    final String closeTimeStr = data['shopCloseTime'] ?? '03:00';
    final List<String> parts = closeTimeStr.split(':');
    final int closeHour = int.parse(parts[0]);
    final int closeMinute = int.parse(parts[1]);

    // If time is between 12 AM and close time, it's part of the previous day
    DateTime businessDate = date;
    if (date.hour < closeHour || (date.hour == closeHour && date.minute < closeMinute)) {
      businessDate = date.subtract(const Duration(days: 1));
    }

    return "${businessDate.year}${businessDate.month.toString().padLeft(2, '0')}${businessDate.day.toString().padLeft(2, '0')}";
  }

  Future<String> addOrder(Map<String, dynamic> orderData) async {
    final DateTime orderDateTime = orderData['createdAt'] != null 
        ? (orderData['createdAt'] as Timestamp).toDate() 
        : DateTime.now();
    
    // Get Vendor Details to determine business date
    final vendorDoc = await _vendorRef.get();
    final vendorData = vendorDoc.data() as Map<String, dynamic>? ?? {};
    
    final bool isCustomEnabled = vendorData['isCustomBusinessDay'] ?? false;
    DateTime businessDate = orderDateTime;
    
    if (isCustomEnabled) {
      final String closeTimeStr = vendorData['shopCloseTime'] ?? '04:00';
      final List<String> parts = closeTimeStr.split(':');
      final int closeHour = int.parse(parts[0]);
      final int closeMinute = int.parse(parts[1]);

      // If current time is before the shop close time (e.g., 2 AM), 
      // it belongs to the previous calendar day's business session.
      if (orderDateTime.hour < closeHour || (orderDateTime.hour == closeHour && orderDateTime.minute < closeMinute)) {
        businessDate = orderDateTime.subtract(const Duration(days: 1));
      }
    }

    final String dateKey = "${businessDate.year}${businessDate.month.toString().padLeft(2, '0')}${businessDate.day.toString().padLeft(2, '0')}";
    final String monthKey = dateKey.substring(0, 6);
    final String idDateStr = DateFormat('dd-MMM-yy').format(businessDate).toUpperCase();

    return await _firestore.runTransaction<String>((transaction) async {
      // 1. Get and Increment Daily Counter
      final dailyReportRef = _vendorRef.collection('reports').doc('sales').collection('daily').doc(dateKey);
      final dailyDoc = await transaction.get(dailyReportRef);
      
      int nextCount = 1;
      if (dailyDoc.exists) {
        nextCount = (dailyDoc.data()?['orderCounter'] ?? 0) + 1;
      }
      
      final String orderId = "$idDateStr-- $nextCount";

      // 2. Create the Order Document
      orderData['createdAt'] = orderData['createdAt'] ?? FieldValue.serverTimestamp();
      orderData['updatedAt'] = FieldValue.serverTimestamp();
      orderData['businessDate'] = dateKey;
      transaction.set(_ordersRef.doc(orderId), orderData);

      // 3. Update Daily Sales Report (including the ID counter)
      transaction.set(dailyReportRef, {
        'totalRevenue': FieldValue.increment(orderData['totalAmount']),
        'orderCount': FieldValue.increment(1),
        'orderCounter': nextCount, // The running counter for IDs
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 4. Update Monthly Sales Report
      final monthlyReportRef = _vendorRef.collection('reports').doc('sales').collection('monthly').doc(monthKey);
      transaction.set(monthlyReportRef, {
        'totalRevenue': FieldValue.increment(orderData['totalAmount']),
        'orderCount': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 5. Update Product-wise Sales
      final List items = orderData['items'] as List;
      for (var item in items) {
        final productId = item['productId'];
        final qty = item['quantity'] ?? 1;
        final revenue = item['totalPrice'] ?? 0.0;

        // Overall product stats
        final productReportRef = _vendorRef.collection('reports').doc('products').collection('items').doc(productId);
        transaction.set(productReportRef, {
          'productName': item['productName'],
          'totalSold': FieldValue.increment(qty),
          'totalRevenue': FieldValue.increment(revenue),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Today's specific product stats
        final dailyProductReportRef = _vendorRef
            .collection('reports')
            .doc('sales')
            .collection('daily')
            .doc(dateKey)
            .collection('products')
            .doc(productId);
        transaction.set(dailyProductReportRef, {
          'productName': item['productName'],
          'totalSold': FieldValue.increment(qty),
          'totalRevenue': FieldValue.increment(revenue),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 6. Update Customer Order History
      final String? customerId = orderData['customerId'];
      if (customerId != null && customerId.isNotEmpty) {
        final customerRef = _customersRef.doc(customerId);
        transaction.update(customerRef, {
          'name': orderData['customerName'],
          'mobile': orderData['customerMobile'] ?? '',
          'totalSpent': FieldValue.increment(orderData['totalAmount']),
          'totalOrders': FieldValue.increment(1),
          'orders': FieldValue.arrayUnion([orderId]),
          'lastOrderAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return orderId;
    });
  }

  // Helper to get today's sales summary in 1 read
  Future<Map<String, dynamic>?> getDailySalesReport(String dateKey) async {
    final doc = await _vendorRef.collection('reports').doc('sales').collection('daily').doc(dateKey).get();
    return doc.data();
  }

  Future<Map<String, dynamic>?> getMonthlySalesReport(String monthKey) async {
    final doc = await _vendorRef.collection('reports').doc('sales').collection('monthly').doc(monthKey).get();
    return doc.data();
  }

  Future<List<Map<String, dynamic>>> getProductSalesReport() async {
    final snapshot = await _vendorRef.collection('reports').doc('products').collection('items').orderBy('totalSold', descending: true).get();
    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  Future<List<Map<String, dynamic>>> getDailyProductSalesReport(String dateKey) async {
    final snapshot = await _vendorRef
        .collection('reports')
        .doc('sales')
        .collection('daily')
        .doc(dateKey)
        .collection('products')
        .orderBy('totalSold', descending: true)
        .get();
    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }
}
