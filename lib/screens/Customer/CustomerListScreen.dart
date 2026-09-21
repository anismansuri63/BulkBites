import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../model/Customer.dart';
import '../../services/FirestoreService.dart';
import '../../utlity/AppColors.dart';
import 'CustomerOrderListScreen.dart';
import 'AddCustomerScreen.dart';

class CustomerListScreen extends StatefulWidget {
  final bool isSelectionMode;
  final Function(Customer)? onCustomerSelected;
  final bool isEmbedded;

  const CustomerListScreen({
    super.key,
    this.isSelectionMode = false,
    this.onCustomerSelected,
    this.isEmbedded = false,
  });

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _sortBy = 'name'; // 'name', 'spent', 'orders'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Sort Customers By", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildSortOption("Name (A-Z)", 'name', Icons.sort_by_alpha),
            _buildSortOption("Total Spent (High to Low)", 'spent', Icons.currency_rupee),
            _buildSortOption("Total Orders (High to Low)", 'orders', Icons.shopping_bag),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String title, String value, IconData icon) {
    final isSelected = _sortBy == value;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppColors.primary : Colors.grey),
      title: Text(title, style: TextStyle(color: isSelected ? AppColors.primary : AppColors.textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
      onTap: () {
        setState(() => _sortBy = value);
        Navigator.pop(context);
      },
    );
  }

  void _openAddCustomer(BuildContext context, {Customer? customer}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddCustomerScreen(customer: customer),
      ),
    ).then((result) {
      if (result == true) {
        // The stream will automatically update
      }
    });
  }

  Future<void> _deleteCustomer(BuildContext context, Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: AppColors.cardColor,
        title: const Text(
          'Delete Customer',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textColor,
          ),
        ),
        content: Text(
          'Are you sure you want to delete ${customer.name}?',
          style: TextStyle(
            color: AppColors.textColor.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textColor),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestoreService.deleteCustomer(customer.id!);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Customer deleted successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting customer: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch dialer')),
        );
      }
    }
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
      child: StreamBuilder<List<Customer>>(
        stream: _firestoreService.getCustomersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(context);
          }

          List<Customer> customers = snapshot.data!;
          
          // 1. Filter
          if (_searchQuery.isNotEmpty) {
            customers = customers.where((customer) {
              final name = customer.name.toLowerCase();
              final phone = customer.mobile.toLowerCase();
              return name.contains(_searchQuery) || phone.contains(_searchQuery);
            }).toList();
          }

          // 2. Sort
          switch (_sortBy) {
            case 'spent':
              customers.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
              break;
            case 'orders':
              customers.sort((a, b) => b.orders.length.compareTo(a.orders.length));
              break;
            default:
              customers.sort((a, b) => a.name.compareTo(b.name));
          }

          if (customers.isEmpty && _searchQuery.isNotEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No results for "$_searchQuery"',
                    style: TextStyle(color: AppColors.textColor.withValues(alpha: 0.5), fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 100),
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              return widget.isSelectionMode
                  ? _buildSelectableCustomerCard(context, customer)
                  : _buildCustomerCard(context, customer);
            },
          );
        },
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isSelectionMode ? 'Select Customer' : 'Customers',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: true,
        actions: [
          if (!widget.isSelectionMode)
            IconButton(
              icon: const Icon(Icons.sort),
              onPressed: _showSortDialog,
              tooltip: "Sort Customers",
            ),
          if (widget.isSelectionMode)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: content),
        ],
      ),
      floatingActionButton: widget.isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openAddCustomer(context),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add),
              label: const Text("New Customer", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
          decoration: InputDecoration(
            hintText: "Search name or phone number...",
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.grey, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = "");
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          const Text("Error loading customers", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
              Icons.people_outline,
              size: 60,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.isSelectionMode ? 'No customers available' : 'No customers found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isSelectionMode
                ? 'Add a customer first to place an order'
                : 'Add your first customer to get started',
            style: TextStyle(
              color: AppColors.textColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _openAddCustomer(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text(
              'Add Customer',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(BuildContext context, Customer customer) {
    final orderCount = customer.orders.length;
    final totalSpent = customer.totalSpent;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textColor.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Top Content (Tappable for Customer Orders)
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CustomerOrderListScreen(
                      customerId: customer.id!,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text(
                        customer.name.isNotEmpty
                            ? customer.name.substring(0, 1).toUpperCase()
                            : 'C',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            customer.mobile,
                            style: TextStyle(
                              color: AppColors.textColor.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildQuickAction(
                      icon: Icons.call,
                      color: Colors.green,
                      onTap: () => _makeCall(customer.mobile),
                    ),
                  ],
                ),
              ),
            ),

            // Divider
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.textColor.withValues(alpha: 0.06),
            ),

            // Bottom Action Footer Bar with Stats & Buttons
            Container(
              color: AppColors.backgroundColor.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildStatItem(
                        label: "Orders",
                        value: orderCount.toString(),
                      ),
                      const SizedBox(width: 12),
                      _buildStatItem(
                        label: "Spent",
                        value: "₹${totalSpent.toStringAsFixed(0)}",
                      ),
                    ],
                  ),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit Button
                      InkWell(
                        onTap: () =>
                            _openAddCustomer(context, customer: customer),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.edit_outlined,
                                size: 15,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Edit",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Delete Button
                      InkWell(
                        onTap: () => _deleteCustomer(context, customer),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.delete_outline,
                                size: 15,
                                color: AppColors.error,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Delete",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildStatItem({required String label, required String value}) {
    return Row(
      children: [
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textColor)),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // SELECTABLE CUSTOMER CARD (Simple Selection)
  // ============================================================

  Widget _buildSelectableCustomerCard(BuildContext context, Customer customer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Icon(
            Icons.person,
            color: AppColors.primary,
          ),
        ),
        title: Text(
          customer.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              customer.mobile,
              style: TextStyle(
                color: AppColors.textColor.withValues(alpha: 0.7),
              ),
            ),
            if (customer.orders.isNotEmpty)
              Text(
                '${customer.orders.length} order${customer.orders.length > 1 ? 's' : ''}',
                style: TextStyle(
                  color: AppColors.primary.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.call, color: Colors.green),
              onPressed: () => _makeCall(customer.mobile),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.primary,
            ),
          ],
        ),
        onTap: () {
          // Return selected customer
          Navigator.pop(context, customer);
        },
      ),
    );
  }
}
