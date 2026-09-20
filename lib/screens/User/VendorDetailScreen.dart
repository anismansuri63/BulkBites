import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import '../../services/FirestoreService.dart';
import '../../utlity/AppColors.dart';
import '../../model/Order.dart';
import '../Vendor/Reports/PeakOrderInsightsScreen.dart';

class VendorDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? vendorData;
  final bool isEmbedded;

  const VendorDetailScreen({super.key, this.vendorData, this.isEmbedded = false});

  @override
  State<VendorDetailScreen> createState() => _VendorDetailScreenState();
}
class _VendorDetailScreenState extends State<VendorDetailScreen> with RouteAware {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  late String vendorId;
  Map<String, dynamic>? _vendorData;
  DateTimeRange? _selectedDateRange;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _vendorData = widget.vendorData;
    if (_vendorData != null) {
      vendorId = _vendorData!['id'];
    } else {
      vendorId = _firestoreService.vendorId ?? '';
      _loadVendorData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Refresh data when returning to this screen
    if (widget.vendorData == null) {
      _loadVendorData();
    }
  }

  Future<void> _loadVendorData() async {
    setState(() => _isLoading = true);
    final data = await _firestoreService.getVendorDetails();
    if (mounted) {
      setState(() {
        _vendorData = data;
        if (data != null && data['id'] != null) {
          vendorId = data['id'];
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              secondaryContainer: AppColors.primary2,
              onSecondaryContainer: AppColors.primary2,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  void _clearFilter() {
    setState(() {
      _selectedDateRange = null;
    });
  }

  String _getDateRangeString() {
    if (_selectedDateRange == null) return "All Time";
    
    String formatDay(DateTime date) {
      String suffix = 'th';
      int day = date.day;
      if (day >= 11 && day <= 13) {
        suffix = 'th';
      } else {
        switch (day % 10) {
          case 1: suffix = 'st'; break;
          case 2: suffix = 'nd'; break;
          case 3: suffix = 'rd'; break;
          default: suffix = 'th';
        }
      }
      return "$day$suffix ${DateFormat('MMM').format(date)}";
    }

    final start = formatDay(_selectedDateRange!.start);
    final end = formatDay(_selectedDateRange!.end);
    return "$start to $end";
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_vendorData == null) {
      return const Scaffold(body: Center(child: Text("Vendor data not found.")));
    }

    final content = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVendorHeader(),
          _buildDateRangeDisplay(),
          _buildStatsSection(),
          _buildActionButtons(),
          _buildInsightsSection(),
          _buildRecentOrdersSection(),
        ],
      ),
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_vendorData!['shopName'] ?? 'Vendor Details'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _selectDateRange,
            tooltip: "Select Date Range",
          ),
          if (_selectedDateRange != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearFilter,
              tooltip: "Clear Filter",
            ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildDateRangeDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          const Icon(Icons.date_range, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Showing: ${_getDateRangeString()}",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          if (widget.isEmbedded) ...[
            IconButton(
              icon: Icon(Icons.refresh, size: 20, color: AppColors.primary.withOpacity(0.7)),
              onPressed: _loadVendorData,
              tooltip: "Refresh Data",
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.calendar_month, size: 20, color: AppColors.primary),
              onPressed: _selectDateRange,
              tooltip: "Select Date Range",
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
          if (_selectedDateRange != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: _clearFilter,
              child: const Text("Clear"),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVendorHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: AppColors.primary.withOpacity(0.05),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary,
            backgroundImage: _vendorData!['shopLogo'] != null 
                ? NetworkImage(_vendorData!['shopLogo']) 
                : null,
            child: _vendorData!['shopLogo'] == null 
                ? const Icon(Icons.store, size: 40, color: Colors.white) 
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _vendorData!['shopName'] ?? 'Unnamed Shop',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _vendorData!['address'] ?? 'No address',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(
                  "Contact: ${_vendorData!['contact'] ?? 'N/A'}",
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    Query query = _firestore.collection('vendors').doc(vendorId).collection('orders');
    
    if (_selectedDateRange != null) {
      String startKey = DateFormat('yyyyMMdd').format(_selectedDateRange!.start);
      String endKey = DateFormat('yyyyMMdd').format(_selectedDateRange!.end);
      
      query = query
        .where('businessDate', isGreaterThanOrEqualTo: startKey)
        .where('businessDate', isLessThanOrEqualTo: endKey);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        int totalOrders = 0;
        double totalRevenue = 0;

        if (snapshot.hasData) {
          totalOrders = snapshot.data!.docs.length;
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            totalRevenue += (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
          }
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  _buildStatCard("Total Orders", totalOrders.toString(), Icons.shopping_bag, Colors.blue),
                  const SizedBox(width: 16),
                  _buildStatCard("Total Revenue", "₹${totalRevenue.toStringAsFixed(0)}", Icons.currency_rupee, Colors.green),
                ],
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('vendors').doc(vendorId).collection('customers').snapshots(),
                builder: (context, customerSnapshot) {
                  int totalCustomers = customerSnapshot.hasData ? customerSnapshot.data!.docs.length : 0;
                  return StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('vendors').doc(vendorId).collection('products').snapshots(),
                    builder: (context, productSnapshot) {
                      int totalProducts = productSnapshot.hasData ? productSnapshot.data!.docs.length : 0;
                      return Row(
                        children: [
                          _buildStatCard("Total Customers", totalCustomers.toString(), Icons.people, Colors.orange),
                          const SizedBox(width: 16),
                          _buildStatCard("Total Products", totalProducts.toString(), Icons.inventory_2, AppColors.secondary),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PeakOrderInsightsScreen()),
                );
              },
              icon: const Icon(Icons.analytics_outlined, size: 20),
              label: const Text("Peak Order Insights"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_selectedDateRange == null ? "Top Products (All Time)" : "Top Products (In Range)", 
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _selectedDateRange == null ? _buildAllTimeInsights() : _buildFilteredInsights(),
        ],
      ),
    );
  }

  Widget _buildAllTimeInsights() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('reports')
          .doc('products')
          .collection('items')
          .orderBy('totalSold', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text("No product sales data available.");
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: const Icon(Icons.fastfood, color: AppColors.primary, size: 20),
              ),
              title: Text(data['productName'] ?? 'Unknown'),
              subtitle: Text("Sold: ${data['totalSold']}"),
              trailing: Text("₹${(data['totalRevenue'] as num?)?.toStringAsFixed(0) ?? '0.00'}",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFilteredInsights() {
    String startKey = DateFormat('yyyyMMdd').format(_selectedDateRange!.start);
    String endKey = DateFormat('yyyyMMdd').format(_selectedDateRange!.end);

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('orders')
          .where('businessDate', isGreaterThanOrEqualTo: startKey)
          .where('businessDate', isLessThanOrEqualTo: endKey)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text("No product sales data for this period.");
        }

        // Aggregate product sales in memory
        Map<String, Map<String, dynamic>> productStats = {};
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final items = data['items'] as List? ?? [];
          for (var item in items) {
            final productId = item['productId'];
            final productName = item['productName'] ?? 'Unknown';
            final qty = (item['quantity'] as num?)?.toInt() ?? 0;
            final price = (item['totalPrice'] as num?)?.toDouble() ?? 0.0;

            if (productStats.containsKey(productId)) {
              productStats[productId]!['totalSold'] += qty;
              productStats[productId]!['totalRevenue'] += price;
            } else {
              productStats[productId] = {
                'productName': productName,
                'totalSold': qty,
                'totalRevenue': price,
              };
            }
          }
        }

        // Sort by total sold and take top 5
        var sortedProducts = productStats.values.toList();
        sortedProducts.sort((a, b) => b['totalSold'].compareTo(a['totalSold']));
        var topProducts = sortedProducts.take(5).toList();

        return Column(
          children: topProducts.map((data) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: const Icon(Icons.fastfood, color: AppColors.primary, size: 20),
              ),
              title: Text(data['productName']),
              subtitle: Text("Sold: ${data['totalSold']}"),
              trailing: Text("₹${data['totalRevenue'].toStringAsFixed(0)}",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildRecentOrdersSection() {
    Query query = _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('orders')
        .orderBy('createdAt', descending: true);

    if (_selectedDateRange != null) {
      String startKey = DateFormat('yyyyMMdd').format(_selectedDateRange!.start);
      String endKey = DateFormat('yyyyMMdd').format(_selectedDateRange!.end);
      
      query = _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('orders')
        .where('businessDate', isGreaterThanOrEqualTo: startKey)
        .where('businessDate', isLessThanOrEqualTo: endKey)
        .orderBy('businessDate', descending: true)
        .orderBy('createdAt', descending: true);
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_selectedDateRange == null ? "Recent Orders" : "Orders in Range", 
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: query.limit(10).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text("No orders found.");
              }

              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final order = OrderModel.fromFirestore(doc);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(order.customerName),
                      subtitle: Text(DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt ?? DateTime.now())),
                      trailing: Text("₹${order.totalAmount.toStringAsFixed(0)}",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
