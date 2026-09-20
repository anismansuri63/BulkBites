import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:provider/provider.dart';
import '../../../model/CartItem.dart';
import '../../../model/Customer.dart';
import '../../../services/FirestoreService.dart';
import '../../../services/PrinterService.dart';
import '../../../utlity/AppColors.dart';
import '../../../widgets/CommonTextField.dart';
import '../../Customer/CustomerListScreen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  Customer? _selectedCustomer;
  bool _isGuestOrder = false;

  String _selectedOrderType = 'Take away';
  String _selectedPaymentType = 'Cash';

  final FirestoreService _firestoreService = FirestoreService();
  final PrinterService _printerService = PrinterService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cartManager = Provider.of<CartManager>(context, listen: false);
      if (cartManager.editingOrderId != null) {
        final order = cartManager.originalOrder!;
        setState(() {
          _noteController.text = order.note ?? '';
          _selectedOrderType = order.orderType;
          _selectedPaymentType = order.paymentType;
          _nameController.text = order.customerName;
          _mobileController.text = order.customerMobile ?? '';

          if (order.customerId.isNotEmpty) {
            // Check if it's a known guest
            if ((order.customerMobile == null ||
                order.customerMobile!.isEmpty)) {
              _isGuestOrder = true;
            } else {
              // Try to find the customer object if we have an ID
              _loadOriginalCustomer(order.customerId);
            }
          } else {
            _isGuestOrder = true;
          }
        });
      }
    });
  }

  Future<void> _loadOriginalCustomer(String customerId) async {
    try {
      final customer = await _firestoreService.getCustomerById(customerId);
      if (customer != null && mounted) {
        setState(() {
          _selectedCustomer = customer;
        });
      }
    } catch (e) {
      debugPrint("Error loading original customer: $e");
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ============================================================
  // SELECT CUSTOMER
  // ============================================================

  Future<void> _selectCustomer() async {
    final customer = await Navigator.push<Customer>(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomerListScreen(
          isSelectionMode: true,
        ),
      ),
    );

    if (customer != null) {
      setState(() {
        _selectedCustomer = customer;
        _nameController.text = customer.name;
        _mobileController.text = customer.mobile;
      });
      if (!mounted) return;
    }
  }

  // ============================================================
  // ENSURE CUSTOMER IS SAVED
  // ============================================================

  Future<bool> _ensureCustomerSaved() async {
    if (_isGuestOrder) return true;
    if (_selectedCustomer != null) return true;

    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();

    if (name.isEmpty || mobile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text("Please add customer details or select a customer"),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return false;
    }

    if (mobile.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please enter a valid 10-digit mobile number"),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return false;
    }

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );

      // Check if customer with this mobile already exists
      final existingCustomer =
          await _firestoreService.findCustomerByMobile(mobile);

      if (!mounted) return false;
      Navigator.pop(context); // Close loading

      if (existingCustomer != null) {
        debugPrint('already exists');
        setState(() {
          _selectedCustomer = existingCustomer;
        });
        return true;
      }

      // If not exists, save new customer
      final data = {
        'name': name,
        'mobile': mobile,
        'orders': [],
        'totalOrders': 0,
        'totalSpent': 0.0,
      };

      final newCustomer = await _firestoreService.addCustomer(data);

      if (!mounted) return false;

      setState(() {
        _selectedCustomer = newCustomer;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Customer saved successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      Navigator.pop(context); // Close loading if still open
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving customer: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return false;
    }
  }

  // ============================================================
  // PRINTER SELECTION
  // ============================================================

  Future<void> _selectPrinter() async {
    await _printerService.showPrinterPicker(context);
  }

  Map<String, dynamic> _prepareOrderData(CartManager cartManager) {
    String customerName = _nameController.text.trim();
    if (customerName.isEmpty) customerName = "Guest Customer";

    String? customerMobile = _mobileController.text.trim();
    if (customerMobile.isEmpty) customerMobile = null;

    String? customerId = _selectedCustomer?.id;

    return {
      'customerId': customerId ?? '',
      'customerName': customerName,
      'customerMobile': customerMobile,
      'totalAmount': cartManager.totalAmount,
      'itemCount': cartManager.totalItems,
      'status': 'pending',
      'orderType': _selectedOrderType,
      'paymentType': _selectedPaymentType,
      'note': _noteController.text.trim(),
      'createdAt': Timestamp.fromDate(cartManager.selectedOrderDate),
      'items': cartManager.items.values.map((item) {
        return {
          'productId': item.productId,
          'productName': item.productName,
          'price': item.price,
          'quantity': item.quantity,
          'totalPrice': item.totalPrice,
          'images': item.images,
          'productDetail': item.productDetail,
          'optionId': item.optionId,
          'optionName': item.optionName,
        };
      }).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final cartManager = Provider.of<CartManager>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "My Cart",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _printerService.isConnected ? Icons.print : Icons.print_disabled,
              color: Colors.white,
            ),
            tooltip: "Select Printer",
            onPressed: _selectPrinter,
          ),
          if (cartManager.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: "Clear Cart",
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: AppColors.cardColor,
                    title: const Text(
                      "Clear Cart?",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textColor,
                      ),
                    ),
                    content: Text(
                      "Are you sure you want to remove all items from your cart?",
                      style: TextStyle(
                        color: AppColors.textColor.withValues(alpha: 0.7),
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
                        onPressed: () {
                          cartManager.clearCart();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text("Cart cleared successfully"),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text("Clear All"),
                      ),
                    ],
                  ),
                );
              },
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
            Expanded(
              child: cartManager.items.isEmpty
                  ? _buildEmptyCart(context)
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      children: [
                        _buildCustomerInfoSection(),
                        _buildOrderOptionsSection(),
                        _buildNoteSection(),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 8),
                          child: Row(
                            children: [
                              Icon(Icons.shopping_bag,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "${cartManager.totalItems} ${cartManager.totalItems == 1 ? 'item' : 'items'} in cart",
                                style: TextStyle(
                                  color: AppColors.textColor
                                      .withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...cartManager.items.values.map(
                          (item) => _CartItem(item: item),
                        ),
                        const SizedBox(height: 16),
                        _buildOrderSummary(cartManager),
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
            if (cartManager.items.isNotEmpty)
              _buildCheckoutButton(cartManager, context),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfoSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Customer Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textColor,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Guest",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isGuestOrder
                          ? AppColors.primary
                          : AppColors.textColor.withValues(alpha: 0.5),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Checkbox(
                      value: _isGuestOrder,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setState(() {
                          _isGuestOrder = val ?? false;
                          if (_isGuestOrder) {
                            _selectedCustomer = null;
                            _nameController.text = "";
                            _mobileController.clear();
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (_selectedCustomer != null)
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.error,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedCustomer = null;
                      _nameController.clear();
                      _mobileController.clear();
                    });
                  },
                  tooltip: 'Clear selection',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          if (_selectedCustomer != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedCustomer!.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textColor,
                          ),
                        ),
                        Text(
                          _selectedCustomer!.mobile,
                          style: TextStyle(
                            color: AppColors.textColor.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 20,
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CommonTextField(
                        controller: _nameController,
                        label: "Name",
                        hintText: "Enter name",
                        showCancleButton: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Visibility(
                      visible: !_isGuestOrder,
                      child: Expanded(
                        child: CommonTextField(
                          controller: _mobileController,
                          label: "Mobile",
                          hintText: "Enter number",
                          keyboardType: TextInputType.phone,
                          enabled: !_isGuestOrder,
                          showCancleButton: true,
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                        ),
                      ),
                    )
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextButton(
                    onPressed: _selectCustomer,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 0),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      "Search & Select",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildOrderOptionsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Order Type",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              _buildChoiceChip(
                label: "Take away",
                isSelected: _selectedOrderType == 'Take away',
                onSelected: (val) =>
                    setState(() => _selectedOrderType = 'Take away'),
              ),
              const SizedBox(width: 8),
              _buildChoiceChip(
                label: "Dine in",
                isSelected: _selectedOrderType == 'Dine in',
                onSelected: (val) =>
                    setState(() => _selectedOrderType = 'Dine in'),
              ),
            ],
          ),
          const Divider(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Payment",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              _buildChoiceChip(
                label: "Cash",
                isSelected: _selectedPaymentType == 'Cash',
                onSelected: (val) =>
                    setState(() => _selectedPaymentType = 'Cash'),
              ),
              const SizedBox(width: 8),
              _buildChoiceChip(
                label: "Online",
                isSelected: _selectedPaymentType == 'Online',
                onSelected: (val) =>
                    setState(() => _selectedPaymentType = 'Online'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoteSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.note_alt_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Notes / Instructions',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CommonTextField(
            controller: _noteController,
            label: "Instructions",
            hintText: "Add order notes here...",
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required Function(bool) onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textColor,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : Colors.grey.shade300,
      ),
      showCheckmark: false,
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
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
              Icons.shopping_cart_outlined,
              size: 60,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Your cart is empty",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Add some delicious items to get started!",
            style: TextStyle(
              color: AppColors.textColor.withValues(alpha: 0.6),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: const Text(
              "Browse Products",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(CartManager cartManager) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Order Summary",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textColor,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.primary),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Items Total",
                  style: TextStyle(
                    color: AppColors.textColor.withValues(alpha: 0.8),
                    fontSize: 16,
                  ),
                ),
                Text(
                  "₹ ${cartManager.totalAmount.toStringAsFixed(0)}",
                  style: const TextStyle(
                    color: AppColors.textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Total Amount",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  "₹ ${(cartManager.totalAmount).toStringAsFixed(0)}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutButton(CartManager cartManager, BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.cardColor,
          border: Border(
            top: BorderSide(color: AppColors.backgroundColor, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Total Amount: ",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textColor.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  "₹${(cartManager.totalAmount).toStringAsFixed(0)}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (cartManager.items.isEmpty) return;
                      await _printerService.showPrinterPicker(context);
                      // Wait 1 seconds
                      await Future.delayed(const Duration(milliseconds: 1000));

                      final bool isPrinterConnected =
                          await PrintBluetoothThermal.connectionStatus;
                      if (_printerService.isConnected) {
                        final orderData = _prepareOrderData(cartManager);
                        await _printerService.printKOT(orderData);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      "KOT",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (cartManager.items.isEmpty) return;

                      final bool isPrinterConnected = _printerService.isConnected;
                      print('isPrinterConnected: $isPrinterConnected');

                      // Show picker
                      await _printerService.showPrinterPicker(context);

                      // Wait 0.5 seconds
                      await Future.delayed(const Duration(milliseconds: 500));

                      // Check connection after delay
                      final bool isPrinterConnected1 =
                          _printerService.isConnected;
                      print('isPrinterConnected1: $isPrinterConnected1');

                      if (isPrinterConnected1) {
                        final orderData = _prepareOrderData(cartManager);
                        final vendorDetails =
                            await _firestoreService.getVendorDetails();

                        await _printerService.printBill(
                          orderData,
                          shopName: vendorDetails?['shopName'] ?? "HUNGRY BITES",
                          shopAddress: vendorDetails?['address'],
                          shopContact: vendorDetails?['contact'],
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      "Bill",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleCheckout(cartManager),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      cartManager.editingOrderId != null
                          ? "Update Order"
                          : "Save Bill",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCheckout(CartManager cartManager) async {
    if (await _ensureCustomerSaved()) {
      if (!mounted) return;
      try {
        final orderData = _prepareOrderData(cartManager);

        String orderId;
        if (cartManager.editingOrderId != null) {
          // UPDATE MODE
          orderId = cartManager.editingOrderId!;
          await _firestoreService.updateOrderFull(
            orderId,
            orderData,
            cartManager.originalOrder!,
          );
        } else {
          // CREATE MODE
          orderId = await _firestoreService.addOrder(orderData);
        }

        // Inject ID for printing
        orderData['id'] = orderId;
        debugPrint("Order saved with ID: $orderId");

        // 1. Print KOT (Checks internally if enabled)
        try {
          debugPrint("Attempting KOT print...");
          await _printerService.printKOT(orderData);
          debugPrint("KOT print task finished.");
        } catch (e) {
          debugPrint("KOT Printing Error: $e");
        }

        // 2. Print Bill if enabled (Asks user via popup)
        debugPrint("Fetching bill settings...");
        final billSettings = await _firestoreService.getPrintSettings('bill');
        final bool isBillEnabled = billSettings['enabled'] ?? true;
        debugPrint("Bill Printing Enabled: $isBillEnabled");

        if (isBillEnabled) {
          if (mounted) {
            debugPrint("Showing 'Print Bill?' dialog...");
            final bool? shouldPrint = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                backgroundColor: AppColors.cardColor,
                title: const Text("Print Bill?",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                content:
                    const Text("Would you like to print the customer receipt?"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text("NO",
                        style: TextStyle(
                            color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("YES"),
                  ),
                ],
              ),
            );
            debugPrint("User selected shouldPrint: $shouldPrint");

            if (shouldPrint == true) {
              final vendorDetails = await _firestoreService.getVendorDetails();
              await _printerService.printBill(
                orderData,
                shopName: vendorDetails?['shopName'] ?? "HUNGRY BITES",
                shopAddress: vendorDetails?['address'],
                shopContact: vendorDetails?['contact'],
              );
            }
          }
        }

        final isEdit = cartManager.editingOrderId != null;
        cartManager.clear();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit
                ? "Order updated successfully"
                : (_isGuestOrder
                    ? "Guest order saved successfully"
                    : "Order saved successfully for ${_selectedCustomer?.name}")),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save order: $e"),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _CartItem extends StatelessWidget {
  final CartItem item;

  const _CartItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final cartManager = Provider.of<CartManager>(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.backgroundColor,
                image: item.images.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(item.images[0]),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: item.images.isEmpty
                  ? Center(
                      child: Icon(
                        Icons.fastfood,
                        color: AppColors.primary.withValues(alpha: 0.3),
                        size: 28,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (item.optionName != null && item.optionName!.isNotEmpty)
                    Text(
                      "Option: ${item.optionName}",
                      style: TextStyle(
                        color: AppColors.primary.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (item.productDetail != null &&
                      item.productDetail!.isNotEmpty)
                    Text(
                      item.productDetail!,
                      style: TextStyle(
                        color: AppColors.textColor.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        "₹ ${item.price.toStringAsFixed(0)} × ${item.quantity}",
                        style: TextStyle(
                          color: AppColors.textColor,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "₹ ${item.totalPrice.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => cartManager.removeItem(item.cartKey),
                        borderRadius: BorderRadius.circular(16),
                        child: const SizedBox(
                          width: 28,
                          height: 28,
                          child: Icon(
                            Icons.remove,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      Container(
                        width: 24,
                        alignment: Alignment.center,
                        child: Text(
                          item.quantity.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => cartManager.addItem(
                          productId: item.productId,
                          productName: item.productName,
                          price: item.price,
                          images: item.images,
                          productDetail: item.productDetail,
                          optionId: item.optionId,
                          optionName: item.optionName,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        child: const SizedBox(
                          width: 28,
                          height: 28,
                          child: Icon(
                            Icons.add,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => cartManager.clearItem(item.cartKey),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline,
                      color: AppColors.error.withValues(alpha: 0.7),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
