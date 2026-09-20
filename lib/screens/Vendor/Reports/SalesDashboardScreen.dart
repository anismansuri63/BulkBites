import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_settings/app_settings.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../main.dart';
import '../../../model/Order.dart';
import '../../../services/FirestoreService.dart';
import '../../../services/PrinterService.dart';
import '../../../utlity/AppColors.dart';
import '../../../widgets/ExportOptionsSheet.dart';

class SalesDashboardScreen extends StatefulWidget {
  final bool isEmbedded;
  const SalesDashboardScreen({super.key, this.isEmbedded = false});

  @override
  State<SalesDashboardScreen> createState() => _SalesDashboardScreenState();
}
class _SalesDashboardScreenState extends State<SalesDashboardScreen> with RouteAware {
  final FirestoreService _firestoreService = FirestoreService();
  final PrinterService _printerService = PrinterService();
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  Map<String, dynamic>? _dailySales;
  Map<String, dynamic>? _monthlySales;
  Map<String, dynamic>? _selectedDateSales;
  List<Map<String, dynamic>> _productSales = [];
  List<OrderModel> _selectedDateOrders = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
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
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      // Current business date (respects custom business day for the "Today" card)
      final String dateKey = await _firestoreService.getBusinessDateKey(now);
      // The business date identifier for the date picked in the calendar
      final String selectedDateKey = DateFormat('yyyyMMdd').format(_selectedDate);
      final String monthKey = dateKey.substring(0, 6);

      // Get orders for selected date - filtered by the business date field
      final ordersStream = _firestoreService.getOrdersStream(filters: {
        "businessDate": selectedDateKey,
      });

      // We need to wait for the first emission of the stream
      final orders = await ordersStream.first;
      
      // Also fetch vendor settings for display logic if needed
      final vendorSettings = await _firestoreService.getVendorDetails();
      final bool isCustomEnabled = vendorSettings?['isCustomBusinessDay'] ?? false;

      final results = await Future.wait([
        _firestoreService.getDailySalesReport(dateKey),
        _firestoreService.getMonthlySalesReport(monthKey),
        _firestoreService.getProductSalesReport(),
        _firestoreService.getDailySalesReport(selectedDateKey),
      ]);

      setState(() {
        _dailySales = results[0] as Map<String, dynamic>?;
        _monthlySales = results[1] as Map<String, dynamic>?;
        _productSales = results[2] as List<Map<String, dynamic>>;
        _selectedDateSales = results[3] as Map<String, dynamic>?;
        
        // Ensure sorting: PM above AM for custom business day
        if (isCustomEnabled) {
          orders.sort((a, b) => (a.createdAt ?? now).compareTo(b.createdAt ?? now));
        }
        
        _selectedDateOrders = orders;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading dashboard: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadDashboardData();
    }
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => const ExportOptionsSheet(
        exportType: ExportType.orders,
        title: "Export Sales Report",
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : Container(
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCards(),
                  const SizedBox(height: 24),
                  _buildDateSelector(),
                  const SizedBox(height: 16),
                  _buildSelectedDateInsights(),
                  const SizedBox(height: 24),
                  const Text("Top Selling Products",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildProductStatsList(),
                ],
              ),
            ),
          );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text("Sales Dashboard",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            if (_isLoading) ...[
              const SizedBox(width: 10),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ],
          ],
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download, color: Colors.white),
            onPressed: _showExportOptions,
            tooltip: "Export Report",
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isLoading ? null : _loadDashboardData,
          ),
        ],
      ),
      body: SafeArea(child: content),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: "Today's Sales",
            amount: _dailySales?['totalRevenue'] ?? 0.0,
            count: _dailySales?['orderCount'] ?? 0,
            color: AppColors.primary,
            icon: Icons.today,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: "This Month",
            amount: _monthlySales?['totalRevenue'] ?? 0.0,
            count: _monthlySales?['orderCount'] ?? 0,
            color: AppColors.secondary,
            icon: Icons.calendar_month,
          ),
        ),
      ],
    );
  }
  Widget _buildProductStatsList() {
    if (_productSales.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        ),
        child: const Center(child: Text("No product sales data available")),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _productSales.length > 5 ? 5 : _productSales.length,
      itemBuilder: (context, index) {
        final item = _productSales[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text("${index + 1}",
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
            title: Text(item['productName'] ?? 'Unknown',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Sold: ${item['totalSold']} units"),
            trailing: Text("₹ ${item['totalRevenue']?.toStringAsFixed(0)}",
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  Widget _buildDateSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Detailed Insights",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Row(
          children: [
            if (widget.isEmbedded)
              IconButton(
                onPressed: _loadDashboardData,
                icon: Icon(Icons.refresh, size: 20, color: AppColors.primary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            if (widget.isEmbedded) const SizedBox(width: 12),
            TextButton.icon(
              onPressed: _selectDate,
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectedDateInsights() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat("Revenue", "₹ ${_selectedDateSales?['totalRevenue'] ?? 0}"),
                  _buildMiniStat("Orders", "${_selectedDateSales?['orderCount'] ?? 0}"),
                  _buildMiniStat("Avg Order",
                      "₹ ${((_selectedDateSales?['totalRevenue'] ?? 0) / (_selectedDateSales?['orderCount'] ?? 1)).toStringAsFixed(0)}"),
                ],
              ),
              if (_selectedDateOrders.isNotEmpty) ...[
                const Divider(height: 24),
                _buildPaymentBreakdown(),
                const Divider(height: 24),
                _buildDailyProductSummary(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_selectedDateOrders.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text("No orders on this date"),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedDateOrders.length,
            itemBuilder: (context, index) {
              final order = _selectedDateOrders[index];
              return _buildOrderListItem(order);
            },
          ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildPaymentBreakdown() {
    int cashCount = _selectedDateOrders.where((o) => o.paymentType.toLowerCase() == 'cash').length;
    int upiCount = _selectedDateOrders.where((o) => 
        o.paymentType.toLowerCase() == 'upi' || o.paymentType.toLowerCase() == 'online').length;

    return Row(
      children: [
        Expanded(
          child: _buildSmallInfo(Icons.money, "Cash: $cashCount", Colors.green),
        ),
        Expanded(
          child: _buildSmallInfo(Icons.qr_code_scanner, "Online: $upiCount", Colors.blue),
        ),
      ],
    );
  }

  Widget _buildDailyProductSummary() {
    Map<String, int> productCounts = {};
    for (var order in _selectedDateOrders) {
      for (var item in order.items) {
        productCounts[item.productName] = (productCounts[item.productName] ?? 0) + item.quantity;
      }
    }

    if (productCounts.isEmpty) return const SizedBox.shrink();

    var sortedProducts = productCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    var topProducts = sortedProducts.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Popular Today",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: topProducts.map((e) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
            ),
            child: Text("${e.key}: ${e.value}",
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildSmallInfo(IconData icon, String text, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _buildOrderListItem(OrderModel order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Row(
          children: [
            Expanded(child: Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text("₹ ${order.totalAmount.toStringAsFixed(0)}",
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ],
        ),
        subtitle: Row(
          children: [
            Text(DateFormat('hh:mm a').format(order.createdAt ?? DateTime.now()),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(order.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                order.status.toUpperCase(),
                style: TextStyle(fontSize: 10, color: _getStatusColor(order.status), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _printOrderBill(OrderModel order) async {
    final status = await _printerService.checkPrinterStatus();

    if (status != "ready") {
      if (mounted) {
        String message = "Printer not ready.";
        String actionLabel = "CONNECT";
        VoidCallback actionPressed = () => _printerService.showPrinterPicker(context);

        if (status == "permission_denied") {
          message = "Bluetooth permissions are required.";
          actionLabel = "SETTINGS";
          actionPressed = () => AppSettings.openAppSettings(type: AppSettingsType.settings);
        } else if (status == "bluetooth_off") {
          message = "Please turn on Bluetooth.";
          actionLabel = "SETTINGS";
          actionPressed = () => AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
        } else if (status == "not_connected") {
          message = "Printer not connected.";
          actionLabel = "CONNECT";
          actionPressed = () => _printerService.showPrinterPicker(context);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
            action: SnackBarAction(
              label: actionLabel,
              textColor: Colors.white,
              onPressed: actionPressed,
            ),
          ),
        );
      }
      return;
    }

    final orderData = order.toMap();
    orderData['id'] = order.id;

    // Fetch vendor details
    final vendorDetails = await _firestoreService.getVendorDetails();

    await _printerService.printBill(
      orderData,
      shopName: vendorDetails?['shopName'] ?? "HUNGRY BITES",
      shopAddress: vendorDetails?['address'],
      shopContact: vendorDetails?['contact'],
      ignoreEnabledFlag: true,
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final double amount;
  final int count;
  final Color color;
  final IconData icon;

  const _StatCard({required this.title, required this.amount, required this.count, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: AppColors.textColor.withValues(alpha: 0.7), fontSize: 13)),
          const SizedBox(height: 4),
          Text("₹ ${amount.toStringAsFixed(0)}", style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text("$count Orders", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
