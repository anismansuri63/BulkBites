import 'package:bulk_bites/widgets/CommonTextField.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_settings/app_settings.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../model/CartItem.dart';
import '../../model/Order.dart';
import '../../services/FirestoreService.dart';
import '../../services/PrinterService.dart';
import '../../utlity/AppColors.dart';
import '../../widgets/ExportOptionsSheet.dart';
import '../Vendor/TakeOrder/TakeOrderScreen.dart';

class OrderListScreen extends StatefulWidget {
  final bool isEmbedded;
  final VoidCallback? onFullEdit;
  const OrderListScreen({super.key, this.isEmbedded = false, this.onFullEdit});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final PrinterService _printerService = PrinterService();
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy hh:mm a');
  Map<String, dynamic>? _filters;
  Map<String, dynamic>? _vendorSettings;
  String _sortOrder = 'desc'; // 'asc' or 'desc'
  List<OrderModel> _allOrders = [];

  bool _isSelectionMode = false;
  final Set<String> _selectedOrderIds = {};

  late Stream<List<OrderModel>> _ordersStream;

  @override
  void initState() {
    super.initState();
    _ordersStream = _firestoreService.getOrdersStream();
    _loadVendorSettings();
  }

  void _updateStream() {
    setState(() {
      _ordersStream = _getFilteredOrders();
    });
  }

  bool _isDateSelected(List<OrderModel> orders) {
    return orders.every((o) => _selectedOrderIds.contains(o.id));
  }

  void _toggleDateSelection(List<OrderModel> orders) {
    setState(() {
      if (_isDateSelected(orders)) {
        for (var o in orders) {
          _selectedOrderIds.remove(o.id);
        }
        if (_selectedOrderIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        for (var o in orders) {
          _selectedOrderIds.add(o.id);
        }
        _isSelectionMode = true;
      }
    });
  }

  void _exportOrders() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => const ExportOptionsSheet(
        exportType: ExportType.orders,
        title: "Export Orders Report",
      ),
    );
  }

  Future<void> _loadVendorSettings() async {
    final settings = await _firestoreService.getVendorDetails();
    if (mounted) {
      _vendorSettings = settings;
      _updateStream();
    }
  }

  Stream<List<OrderModel>> _getFilteredOrders() {
    if (_filters == null) return _firestoreService.getOrdersStream();

    // Process filters to respect custom business day if active
    final Map<String, dynamic> processedFilters = Map.from(_filters!);
    final bool isCustomEnabled =
        _vendorSettings?['isCustomBusinessDay'] ?? false;

    if (isCustomEnabled && processedFilters["dateRange"] is DateTimeRange) {
      final range = processedFilters["dateRange"] as DateTimeRange;
      // We shift to businessDateRange filtering instead of createdAt
      processedFilters.remove("dateRange");
      processedFilters["businessDateRange"] = [
        DateFormat('yyyyMMdd').format(range.start),
        DateFormat('yyyyMMdd').format(range.end),
      ];
    }
    return _firestoreService.getOrdersStream(filters: processedFilters);
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
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
      child: StreamBuilder<List<OrderModel>>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final error = snapshot.error.toString();
            // Check if it's a missing index error
            bool isIndexError = error.contains('index') || error.contains('FAILED_PRECONDITION');
            
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      isIndexError ? "Database Index Required" : "Error loading orders",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isIndexError 
                        ? "This filter combination requires a Firestore index. Check the debug console for the link to create it." 
                        : error,
                      style: const TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            _allOrders = [];
            return _buildEmptyOrders();
          }
          final allOrders = snapshot.data!;
          _allOrders = allOrders;

          // Calculate Today's Total using Business Date logic
          final now = DateTime.now();
          final bool isCustomEnabled =
              _vendorSettings?['isCustomBusinessDay'] ?? false;

          // We'll calculate today's business date key to filter current sales
          String todayKey;
          if (isCustomEnabled) {
            final closeTimeStr = _vendorSettings?['shopCloseTime'] ?? '03:00';
            final List<String> parts = closeTimeStr.split(':');
            final int closeHour = int.parse(parts[0]);
            final int closeMinute = int.parse(parts[1]);

            DateTime businessDate = now;
            if (now.hour < closeHour ||
                (now.hour == closeHour && now.minute < closeMinute)) {
              businessDate = now.subtract(const Duration(days: 1));
            }
            todayKey = DateFormat('yyyyMMdd').format(businessDate);
          } else {
            todayKey = DateFormat('yyyy-MM-dd').format(now);
          }

          double todayTotal = 0;
          int orderCont = 0;
          for (var o in allOrders) {
            String oDateKey;
            if (isCustomEnabled) {
              oDateKey = o.businessDate ??
                  DateFormat('yyyyMMdd').format(o.createdAt ?? now);
            } else {
              oDateKey = DateFormat('yyyy-MM-dd').format(o.createdAt ?? now);
            }

            if (oDateKey == todayKey) {
              todayTotal += o.totalAmount;
              orderCont += 1;
            }
          }

          // 1. Group orders by date
          final Map<String, List<OrderModel>> groupedOrders = {};
          for (var order in allOrders) {
            String groupKey;
            if (isCustomEnabled) {
              groupKey = order.businessDate ??
                  DateFormat('yyyyMMdd').format(order.createdAt ?? now);
            } else {
              groupKey =
                  DateFormat('yyyy-MM-dd').format(order.createdAt ?? now);
            }

            if (!groupedOrders.containsKey(groupKey)) {
              groupedOrders[groupKey] = [];
            }
            groupedOrders[groupKey]!.add(order);
          }

          // 2. Sort orders within each group (Time sort inside the date)
          for (var date in groupedOrders.keys) {
            groupedOrders[date]!.sort((a, b) {
              final timeA = a.createdAt ?? now;
              final timeB = b.createdAt ?? now;
              // If Oldest First selected, show chronological (PM -> AM)
              // If Newest First selected, show reverse chronological (AM -> PM)
              return _sortOrder == 'asc'
                  ? timeA.compareTo(timeB)
                  : timeB.compareTo(timeA);
            });
          }

          // 3. Sort the dates themselves (Always most recent date on top)
          final sortedDates = groupedOrders.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          return Column(
            children: [
              _buildTodaySummary(
                  todayTotal,
                  isCustomEnabled ? "Business Day" : "Received Orders",
                  orderCont),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    _updateStream();
                    await _loadVendorSettings();
                  },
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.only(left: 16, right: 16, bottom: 80),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: sortedDates.length,
                    itemBuilder: (context, index) {
                      final dateKey = sortedDates[index];
                      final dateOrders = groupedOrders[dateKey]!;
                      return _buildDateGroup(dateKey, dateOrders);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (widget.isEmbedded) {
      return Scaffold(
        appBar: _isSelectionMode ? _buildSelectionAppBar() : null,
        body: content,
      );
    }

    return Scaffold(
      appBar: _isSelectionMode
          ? _buildSelectionAppBar()
          : AppBar(
              title: const Text(
                "Received Orders",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              backgroundColor: AppColors.primary,
              iconTheme: const IconThemeData(color: Colors.white),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.checklist_rtl, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = true;
                    });
                  },
                  tooltip: "Batch Edit",
                ),
                IconButton(
                  icon: const Icon(Icons.file_download, color: Colors.white),
                  onPressed: _exportOrders,
                  tooltip: "Export Orders",
                ),
                IconButton(
                  icon: const Icon(Icons.filter_list, color: Colors.white),
                  onPressed: _showFilterDialog,
                ),
              ],
            ),
      body: content,
    );
  }

  AppBar _buildSelectionAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      iconTheme: const IconThemeData(color: Colors.white),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          setState(() {
            _isSelectionMode = false;
            _selectedOrderIds.clear();
          });
        },
      ),
      title: Text(
        "${_selectedOrderIds.length} Selected",
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      actions: [
        TextButton(
          onPressed: _selectedOrderIds.isEmpty ? null : _batchMarkCompleted,
          child: const Text(
            "COMPLETED",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Future<void> _batchMarkCompleted() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.cardColor,
        title: const Text("Batch Update"),
        content: Text("Mark ${_selectedOrderIds.length} orders as COMPLETED?"),
        actions: [
          TextButton(
              style: ElevatedButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary)),
    );

    try {
      await _firestoreService.batchUpdateOrderStatus(
          _selectedOrderIds.toList(), 'completed');

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      setState(() {
        _isSelectionMode = false;
        _selectedOrderIds.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Orders updated successfully"),
            backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Failed to update: $e"),
            backgroundColor: AppColors.error),
      );
    }
  }

  Widget _buildTodaySummary(double total, String title, int orderCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        border: Border(
            bottom:
                BorderSide(color: AppColors.primary.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's $title",
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.grey)),
                Row(
                  children: [
                    Text("₹${total.toStringAsFixed(0)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: AppColors.primary)),
                    Text(" - $orderCount Orders",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.primary)),
                  ],
                )
              ],
            ),
          ),
          if (widget.isEmbedded) ...[
            IconButton(
              icon: const Icon(Icons.checklist_rtl,
                  color: AppColors.primary, size: 22),
              onPressed: () {
                setState(() {
                  _isSelectionMode = true;
                });
              },
              tooltip: "Batch Edit",
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
            ),
            IconButton(
              icon: const Icon(Icons.file_download,
                  color: AppColors.primary, size: 22),
              onPressed: _exportOrders,
              tooltip: "Export Orders",
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
            ),
            IconButton(
              icon: const Icon(Icons.filter_list,
                  color: AppColors.primary, size: 22),
              onPressed: _showFilterDialog,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateGroup(String dateKey, List<OrderModel> orders) {
    DateTime date;
    String formattedDate;
    final bool isCustomEnabled =
        _vendorSettings?['isCustomBusinessDay'] ?? false;

    if (isCustomEnabled && dateKey.length == 8) {
      // Parse yyyyMMdd
      int year = int.parse(dateKey.substring(0, 4));
      int month = int.parse(dateKey.substring(4, 6));
      int day = int.parse(dateKey.substring(6, 8));
      date = DateTime(year, month, day);
      formattedDate = DateFormat('dd MMM, yyyy').format(date);
    } else {
      date = DateTime.tryParse(dateKey) ?? DateTime.now();
      formattedDate = DateFormat('dd MMM, yyyy').format(date);
    }

    // Check if it's today
    final now = DateTime.now();
    String currentBusinessKey;
    if (isCustomEnabled) {
      // Need a synchronous way to calculate current business key or just compare formatted
      final closeTimeStr = _vendorSettings?['shopCloseTime'] ?? '03:00';
      final List<String> parts = closeTimeStr.split(':');
      final int closeHour = int.parse(parts[0]);
      final int closeMinute = int.parse(parts[1]);

      DateTime businessDate = now;
      if (now.hour < closeHour ||
          (now.hour == closeHour && now.minute < closeMinute)) {
        businessDate = now.subtract(const Duration(days: 1));
      }
      currentBusinessKey = DateFormat('yyyyMMdd').format(businessDate);
    } else {
      currentBusinessKey = DateFormat('yyyy-MM-dd').format(now);
    }
    if (dateKey == currentBusinessKey) {
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
              if (_isSelectionMode)
                IconButton(
                  icon: Icon(
                    _isDateSelected(orders)
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  onPressed: () => _toggleDateSelection(orders),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.only(right: 8),
                ),
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
            onEdit: () {
              _showUpdateOrderDialog(context, order);
            },
            onFullEdit: () {
              _editOrderFull(context, order);
            },
            onPrint: () => _printOrderBill(order),
            isSelectionMode: _isSelectionMode,
            isSelected: _selectedOrderIds.contains(order.id),
            onLongPress: () {
              setState(() {
                _isSelectionMode = true;
                _selectedOrderIds.add(order.id);
              });
            },
            onToggleSelection: () {
              setState(() {
                if (_selectedOrderIds.contains(order.id)) {
                  _selectedOrderIds.remove(order.id);
                  if (_selectedOrderIds.isEmpty) {
                    _isSelectionMode = false;
                  }
                } else {
                  _selectedOrderIds.add(order.id);
                }
              });
            },
          );
        }),
      ],
    );
  }

  Widget _buildSmallTotalBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
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
          SizedBox(height: 24),
          Text(
            "No orders yet",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor,
            ),
          ),
          SizedBox(height: 12),
          Text(
            "Orders will appear here",
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

  void _showUpdateOrderDialog(BuildContext context, OrderModel order) {
    showDialog(
      context: context,
      builder: (context) {
        String selectedStatus = order.status;
        String selectedPayment = order.paymentType;
        final TextEditingController noteController =
            TextEditingController(text: order.note ?? '');

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: AppColors.cardColor,
              title: const Text(
                "Update Order",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: "Status",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:  BorderSide(
                            color: AppColors.textColor.withValues(alpha: 0.1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.textColor.withValues(alpha: 0.1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.error,
                            width: 1,
                          ),
                        ),
                        labelStyle: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                        ),),
                      initialValue: selectedStatus,
                      items: ['cancelled', 'completed', 'pending', 'processing']
                          .map((s) => DropdownMenuItem(
                              value: s, child: Text(s.toUpperCase())))
                          .toList(),
                      onChanged: (val) =>
                          setDialogState(() => selectedStatus = val!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration:
                          InputDecoration(labelText: "Payment Mode",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.textColor.withValues(alpha: 0.1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.textColor.withValues(alpha: 0.1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.error,
                                width: 1,
                              ),
                            ),
                            labelStyle: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                            ),),
                      initialValue: selectedPayment,
                      items: ['Cash', 'Online']
                          .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) =>
                          setDialogState(() => selectedPayment = val!),
                    ),
                    const SizedBox(height: 16),
                    CommonTextField(
                      controller: noteController,
                      maxLines: 2,
                      label: 'Notes / Instructions',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _firestoreService.updateOrderFields(order.id, {
                      'status': selectedStatus,
                      'paymentType': selectedPayment,
                      'note': noteController.text.trim(),
                    });
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text("Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showOrderDetails(BuildContext context, OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _OrderDetailsSheet(
        order: order,
        dateFormat: _dateFormat,
        onPrint: () => _printOrderBill(order),
      ),
    );
  }

  void _editOrderFull(BuildContext context, OrderModel order) {
    final cartManager = Provider.of<CartManager>(context, listen: false);

    if (cartManager.totalItems > 0) {
      // Warn user that cart will be cleared
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.cardColor,
          title: const Text("Edit Full Order?"),
          content: const Text(
            "This will clear your current cart and load this order items for editing. Proceed?",
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                "Cancel",
                style: TextStyle(color: AppColors.error),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _processEditFull(cartManager, order);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Proceed"),
            ),
          ],
        ),
      );
    } else {
      _processEditFull(cartManager, order);
    }
  }

  void _printOrderBill(OrderModel order) async {
    final status = await _printerService.checkPrinterStatus();

    if (status != "ready") {
      if (mounted) {
        String message = "Printer not ready.";
        String actionLabel = "CONNECT";
        VoidCallback actionPressed =
            () => _printerService.showPrinterPicker(context);

        if (status == "permission_denied") {
          message = "Bluetooth permissions are required.";
          actionLabel = "SETTINGS";
          actionPressed =
              () => AppSettings.openAppSettings(type: AppSettingsType.settings);
        } else if (status == "bluetooth_off") {
          message = "Please turn on Bluetooth.";
          actionLabel = "SETTINGS";
          actionPressed = () =>
              AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
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

    await _printerService.printBill(
      orderData,
      shopName: _vendorSettings?['shopName'] ?? "HUNGRY BITES",
      shopAddress: _vendorSettings?['address'],
      shopContact: _vendorSettings?['contact'],
      ignoreEnabledFlag: true,
    );
  }

  void _processEditFull(CartManager cartManager, OrderModel order) {
    cartManager.loadOrder(order);
    if (widget.onFullEdit != null) {
      widget.onFullEdit!();
    } else if (widget.isEmbedded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Order loaded. Switch to 'Take Order' tab to edit."),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // Opened from drawer, navigate to Take Order
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TakeOrderScreen()),
      );
    }
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        String? selectedStatus = _filters?["status"];
        DateTimeRange? selectedDateRange = _filters?["dateRange"];
        String localSortOrder = _sortOrder;

        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Text(
                    "Filter & Sort",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Sort Order Section
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Time Wise Sort",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("Newest First"),
                          selected: localSortOrder == 'desc',
                          onSelected: (val) =>
                              setState(() => localSortOrder = 'desc'),
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: localSortOrder == 'desc'
                                ? AppColors.primary
                                : AppColors.textColor,
                            fontWeight: localSortOrder == 'desc'
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: localSortOrder == 'desc'
                                ? AppColors.primary
                                : Colors.grey.shade300,
                          ),
                          showCheckmark: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("Oldest First"),
                          selected: localSortOrder == 'asc',
                          onSelected: (val) =>
                              setState(() => localSortOrder = 'asc'),
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: localSortOrder == 'asc'
                                ? AppColors.primary
                                : AppColors.textColor,
                            fontWeight: localSortOrder == 'asc'
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: localSortOrder == 'asc'
                                ? AppColors.primary
                                : Colors.grey.shade300,
                          ),
                          showCheckmark: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Status Filter
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:  BorderSide(
                          color: AppColors.textColor.withValues(alpha: 0.1),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.textColor.withValues(alpha: 0.1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.error,
                          width: 1,
                        ),
                      ),
                      labelText: "Order Status",
                      labelStyle: TextStyle(
                        color: AppColors.primary
                      )
                    ),
                    initialValue: selectedStatus,
                    items: [
                      'cancelled',
                      'completed',
                      'pending',
                      'processing',
                    ].map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status.toUpperCase(), style: TextStyle(fontSize: 12),),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedStatus = value);
                    },

                  ),
                  SizedBox(height: 16),

                  // Date Range Filter
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text("Date Range"),
                    subtitle: Text(
                      selectedDateRange == null
                          ? "Not selected"
                          : "${DateFormat('MMM dd').format(selectedDateRange!.start)} - ${DateFormat('MMM dd').format(selectedDateRange!.end)}",
                    ),
                    trailing: Icon(Icons.date_range),
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2023),
                        lastDate: DateTime.now(),
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
                        setState(() => selectedDateRange = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context, {
                              "status": selectedStatus?.toLowerCase(),
                              "dateRange": selectedDateRange,
                              "sortOrder": localSortOrder,
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text("Apply"),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  // Reset Filters Button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          selectedStatus = null;
                          selectedDateRange = null;
                        });
                        Navigator.pop(context, {
                          "status": null,
                          "dateRange": null,
                          "sortOrder": 'desc',
                        });
                      },
                      child: const Text(
                        "Reset Filters",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((filters) {
      if (filters != null) {
        _filters = filters;
        if (filters["sortOrder"] != null) {
          _sortOrder = filters["sortOrder"];
        }
        _updateStream();
      }
    });
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final DateFormat dateFormat;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onFullEdit;
  final VoidCallback? onPrint;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onToggleSelection;

  const _OrderCard({
    required this.order,
    required this.dateFormat,
    required this.onTap,
    this.onEdit,
    this.onFullEdit,
    this.onPrint,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onLongPress,
    this.onToggleSelection,
  });

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      case 'processing':
        return Colors.orange;
      case 'pending':
        return AppColors.primary;
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
    final firestoreService = FirestoreService();
    final totalAmount = order.totalAmount;
    final status = order.status;
    final createdAt = order.createdAt ?? DateTime.now();
    final time = DateFormat('hh:mm a').format(createdAt);
    final itemCount = order.itemCount;
    final customerName = order.customerName;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: isSelectionMode ? onToggleSelection : onTap,
        onLongPress: isSelectionMode ? null : onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color:
                isSelected ? AppColors.primary.withValues(alpha: 0.08) : null,
            border: isSelected
                ? Border.all(color: AppColors.primary, width: 1.5)
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(10, 0, 0, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Top Row with Order ID, Status Chip & Delete Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
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
                      Text(
                        order.status.toUpperCase(),
                        style: TextStyle(
                          color: getOrderStatusColor(order.status),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),

                      /// Edit Icon
                      IconButton(
                        icon: const Icon(Icons.edit_note,
                            color: AppColors.primary, size: 24),
                        onPressed: onFullEdit,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                        tooltip: 'Edit Full Order',
                      ),

                      /// Status Icon
                      IconButton(
                        icon: Icon(Icons.edit_outlined,
                            color: AppColors.primary, size: 20),
                        onPressed: onEdit,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                        tooltip: 'Update Status/Note',
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 1),
                  Expanded(
                    child: Text(
                      "$customerName - [${order.customerMobile ?? 'N/A'}]",
                      style: TextStyle(
                        color: AppColors.textColor.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (order.customerMobile != null &&
                      order.customerMobile!.isNotEmpty)
                    IconButton(
                      icon:
                          const Icon(Icons.call, color: Colors.green, size: 18),
                      onPressed: () =>
                          _makeCall(context, order.customerMobile!),
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(time, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          _buildSmallBadge(order.orderType, Colors.blue),
                          const SizedBox(width: 4),
                          _buildSmallBadge(order.paymentType, Colors.orange),
                          const SizedBox(width: 4),
                          Icon(Icons.shopping_bag_outlined,
                              size: 14,
                              color: AppColors.textColor.withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          Text(
                            "$itemCount ${itemCount == 1 ? 'item' : 'items'}",
                            style: TextStyle(
                              color: AppColors.textColor.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  IconButton(
                    icon: const Icon(Icons.print_outlined, color: AppColors.primary, size: 20),
                    onPressed: onPrint,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    tooltip: 'Print Bill',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.error, size: 20),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          backgroundColor: AppColors.cardColor,
                          title: const Text(
                            "Delete Order",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          content: const Text(
                            "Are you sure you want to delete this order?",
                            style: TextStyle(color: AppColors.textColor),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(color: AppColors.error),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text("Delete"),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await firestoreService.deleteOrder(order.id);
                      }
                    },
                    constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 1),
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    "Total Amount",
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: AppColors.textColor.withValues(alpha: 0.7),
                    ),
                  ),
                  Spacer(),
                  Text(
                    "₹${totalAmount.toStringAsFixed(0)}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color getOrderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      default:
        return AppColors.textColor;
    }
  }

  Widget _buildSmallBadge(String text, Color color) {
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
}

class _OrderDetailsSheet extends StatelessWidget {
  final OrderModel order;
  final DateFormat dateFormat;
  final VoidCallback? onPrint;

  const _OrderDetailsSheet({
    required this.order,
    required this.dateFormat,
    this.onPrint,
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

    final maxHeight = MediaQuery.of(context).size.height * 0.8;

    return Container(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
      ),
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
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
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

            const SizedBox(height: 16),
            Text(
              "Order Items (${items.length})",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textColor,
              ),
            ),
            const SizedBox(height: 10),

            // Order Items
            ...items.map((item) => _OrderItemTile(item: item)),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
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

            const SizedBox(height: 14),
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
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon,
              size: 20, color: AppColors.textColor.withValues(alpha: 0.6)),
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
    final List<String> productImages = item.images;

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
          if (productImages.isNotEmpty)
            Image.network(
              productImages[0],
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.image_not_supported,
                  color: AppColors.textColor.withValues(alpha: 0.3),
                  size: 32,
                );
              },
            )
          else
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.shopping_bag,
                color: AppColors.primary,
                size: 32,
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
