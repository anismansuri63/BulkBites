import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_settings/app_settings.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../model/CartItem.dart';
import '../../model/Customer.dart';
import '../../model/Order.dart';
import '../../services/FirestoreService.dart';
import '../../services/PrinterService.dart';
import '../../utlity/AppColors.dart';
import '../../widgets/ExportOptionsSheet.dart';
import '../Vendor/TakeOrder/TakeOrderScreen.dart';


class CustomerOrderListScreen extends StatefulWidget {
  final String customerId;

  const CustomerOrderListScreen({super.key, required this.customerId});

  @override
  State<CustomerOrderListScreen> createState() => _CustomerOrderListScreenState();
}

class _CustomerOrderListScreenState extends State<CustomerOrderListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final PrinterService _printerService = PrinterService();
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy hh:mm a');
  Customer? _customer;
  bool _isLoading = true;
  List<OrderModel> _allOrders = [];

  @override
  void initState() {
    super.initState();
    _loadCustomerData();
  }

  void _exportCustomerOrders() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => ExportOptionsSheet(
        exportType: ExportType.orders,
        title: "Export Customer History",
        additionalFilters: {'customerId': widget.customerId},
      ),
    );
  }

  Future<void> _loadCustomerData() async {
    try {
      final customer = await _firestoreService.getCustomerById(widget.customerId);
      if (customer != null) {
        setState(() {
          _customer = customer;
        });
      }
    } catch (e) {
      debugPrint('Error loading customer data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Order History",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download, color: Colors.white),
            onPressed: _exportCustomerOrders,
            tooltip: "Export History",
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
            // Customer Info Card
            if (_customer != null) _buildCustomerInfoCard(),

            Expanded(
              child: StreamBuilder<List<OrderModel>>(
                stream: _firestoreService.getOrdersStream(
                  filters: {'customerId': widget.customerId},
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: AppColors.error),
                          const SizedBox(height: 16),
                          const Text("Error loading history", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(snapshot.error.toString(), style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    _allOrders = [];
                    return _buildEmptyOrders();
                  }
                  final allOrders = snapshot.data!;
                  _allOrders = allOrders;

                  // Calculate Total Spent
                  double totalSpent = 0;
                  for (var o in allOrders) {
                    totalSpent += o.totalAmount;
                  }

                  // Group orders by date
                  final Map<String, List<OrderModel>> groupedOrders = {};
                  for (var order in allOrders) {
                    final dateKey = DateFormat('yyyy-MM-dd').format(order.createdAt ?? DateTime.now());
                    if (!groupedOrders.containsKey(dateKey)) {
                      groupedOrders[dateKey] = [];
                    }
                    groupedOrders[dateKey]!.add(order);
                  }

                  final sortedDates = groupedOrders.keys.toList()..sort((a, b) => b.compareTo(a));

                  return Column(
                    children: [
                      _buildHistorySummary(totalSpent, allOrders.length),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
                          itemCount: sortedDates.length,
                          itemBuilder: (context, index) {
                            final dateKey = sortedDates[index];
                            final dateOrders = groupedOrders[dateKey]!;
                            return _buildDateGroup(dateKey, dateOrders);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySummary(double total, int orderCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        border: Border(bottom: BorderSide(color: AppColors.primary.withValues(alpha: 0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniStat("Total Spent", "₹${total.toStringAsFixed(0)}", Colors.green),
          Container(width: 1, height: 30, color: Colors.grey.withValues(alpha: 0.2)),
          _buildMiniStat("Total Orders", "$orderCount", AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
      ],
    );
  }

  Widget _buildDateGroup(String dateKey, List<OrderModel> orders) {
    DateTime date = DateTime.parse(dateKey);
    String formattedDate = DateFormat('dd MMM, yyyy').format(date);

    // Check if it's today
    final now = DateTime.now();
    if (dateKey == DateFormat('yyyy-MM-dd').format(now)) {
      formattedDate = "Today, $formattedDate";
    }

    double cashTotal = 0;
    double onlineTotal = 0;
    for (var order in orders) {
      if (order.paymentType.toLowerCase() == 'cash') {
        cashTotal += order.totalAmount;
      } else {
        onlineTotal += order.totalAmount;
      }
    }
    double dayTotal = cashTotal + onlineTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4, right: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(formattedDate,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                        fontSize: 12)),
              ),
              const SizedBox(width: 4),
              _buildSmallTotalBadge(
                  "₹${dayTotal.toStringAsFixed(0)}", AppColors.primary),
              const SizedBox(width: 4),
              _buildSmallTotalBadge(
                  "Cash: ₹${cashTotal.toStringAsFixed(0)}", Colors.green),
              const SizedBox(width: 4),
              _buildSmallTotalBadge(
                  "Online: ₹${onlineTotal.toStringAsFixed(0)}", Colors.blue),
            ],
          ),
        ),
        ...orders.map((order) {
          return _OrderCard(
            order: order,
            dateFormat: _dateFormat,
            onTap: () {
              _showOrderDetails(context, order);
            },
          );
        }),
      ],
    );
  }

  Widget _buildSmallTotalBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCustomerInfoCard() {
    final name = _customer!.name;
    final mobile = _customer!.mobile;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textColor,
                  ),
                ),
                if (mobile.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    mobile,
                    style: TextStyle(
                      color: AppColors.textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOrders() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 60,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "No orders found",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "This customer hasn't placed any orders yet",
            style: TextStyle(
              color: AppColors.textColor.withValues(alpha: 0.6),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(BuildContext context, OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _OrderDetailsSheet(
        order: order,
        dateFormat: _dateFormat,
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final DateFormat dateFormat;
  final VoidCallback onTap;


  const _OrderCard({
    required this.order,
    required this.dateFormat,
    required this.onTap,
  });

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      case 'processing':
        return Colors.orange;
      case 'delivered':
        return Colors.green;
      case 'shipped':
        return Colors.blue;
      default:
        return AppColors.primary;
    }
  }

  Future<void> _makeCall(BuildContext context, String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch dialer')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = order.totalAmount;
    final status = order.status;
    final createdAt = order.createdAt ?? DateTime.now();
    final itemCount = order.itemCount;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(

                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "#${order.id}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (order.customerMobile != null && order.customerMobile!.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.call, color: Colors.green, size: 18),
                          onPressed: () => _makeCall(context, order.customerMobile!),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.only(right: 8),
                        ),
                        Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              Row(
                children: [
                  Icon(Icons.shopping_bag, size: 16, color: AppColors.textColor.withValues(alpha: 0.6)),
                  const SizedBox(width: 8),
                  Text(
                    "$itemCount ${itemCount == 1 ? 'item' : 'items'}",
                    style: TextStyle(
                      color: AppColors.textColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: AppColors.textColor.withValues(alpha: 0.6)),
                  const SizedBox(width: 8),
                  Text(
                    dateFormat.format(createdAt),
                    style: TextStyle(
                      color: AppColors.textColor.withValues(alpha: 0.8),
                    ),
                  ),
                  const Spacer(),
                  _buildSmallBadge(order.orderType, Colors.blue),
                  const SizedBox(width: 4),
                  _buildSmallBadge(order.paymentType, Colors.orange),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Total Amount",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textColor,
                    ),
                  ),
                  Text(
                    "₹ ${totalAmount.toStringAsFixed(0)}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _OrderDetailsSheet extends StatelessWidget {
  final OrderModel order;
  final DateFormat dateFormat;
  const _OrderDetailsSheet({
    required this.order,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    final items = order.items;
    final totalAmount = order.totalAmount;
    final status = order.status;
    final createdAt = order.createdAt ?? DateTime.now();
    final customerName = order.customerName;
    final customerMobile = order.customerMobile ?? '';
    final customerAddress = order.customerAddress ?? '';

    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            "Order Details",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 20),

          // Order Information
          _DetailRow(
            icon: Icons.receipt,
            title: "Order ID",
            value: order.id,
          ),
          _DetailRow(
            icon: Icons.calendar_today,
            title: "Order Date",
            value: dateFormat.format(createdAt),
          ),
          _DetailRow(
            icon: Icons.person,
            title: "Customer",
            value: customerName,
          ),
          if (customerMobile.isNotEmpty)
            _DetailRow(
              icon: Icons.phone,
              title: "Mobile",
              value: customerMobile,
            ),
          if (customerAddress.isNotEmpty)
            _DetailRow(
              icon: Icons.location_on,
              title: "Address",
              value: customerAddress,
            ),
          _DetailRow(
            icon: Icons.inventory,
            title: "Status",
            value: status.toUpperCase(),
            valueColor: _getStatusColor(status),
          ),
          _DetailRow(
            icon: Icons.restaurant,
            title: "Order Type",
            value: order.orderType,
          ),
          _DetailRow(
            icon: Icons.payments,
            title: "Payment Type",
            value: order.paymentType,
          ),
          if (order.note != null && order.note!.isNotEmpty)
            _DetailRow(
              icon: Icons.note_alt,
              title: "Notes",
              value: order.note!,
            ),

          const SizedBox(height: 24),
          Text(
            "Order Items (${items.length})",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor,
            ),
          ),
          const SizedBox(height: 16),

          // Order Items
          ...items.map((item) => _OrderItemTile(item: item)),

          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Total Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total Amount",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),
              Text(
                "₹ ${totalAmount.toStringAsFixed(0)}",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Close"),
          ),
        ],
      ),
    )
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      case 'processing':
        return Colors.orange;
      case 'delivered':
        return Colors.green;
      case 'shipped':
        return Colors.blue;
      default:
        return AppColors.primary;
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textColor.withValues(alpha: 0.6)),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textColor.withValues(alpha: 0.8),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.textColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  final OrderItem item;

  const _OrderItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final productName = item.productName;
    final quantity = item.quantity;
    final price = item.price;
    final totalPrice = item.totalPrice;
    final productDetail = item.productDetail ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Product Image/Icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_bag,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (productDetail.isNotEmpty)
                  Text(
                    productDetail,
                    style: TextStyle(
                      color: AppColors.textColor.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Text(
                  "₹ ${price.toStringAsFixed(0)} × $quantity",
                  style: TextStyle(
                    color: AppColors.textColor.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            "₹ ${totalPrice.toStringAsFixed(0)}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
