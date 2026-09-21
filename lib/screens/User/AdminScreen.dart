// Dummy admin screen
import 'package:bulk_bites/screens/Customer/CustomerListScreen.dart';
import 'package:bulk_bites/screens/Vendor/Product/ProductListScreen.dart';
import 'package:bulk_bites/utlity/AppColors.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/FirestoreService.dart';
import '../Order/OrderListScreen.dart';
import '../Vendor/Category/CategoryListScreen.dart';
import '../Vendor/Category/AddCategoryScreen.dart';
import '../Vendor/Expanse/ExpenseListScreen.dart';
import '../Vendor/Profile/ShopProfileScreen.dart';
import '../Vendor/Reports/SalesDashboardScreen.dart';
import '../Vendor/TakeOrder/TakeOrderScreen.dart';
import 'LoginScreen.dart';
import 'VendorDetailScreen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _selectedIndex = 0;
  var username = "";
  var role = "";
  var shopName = "";
  var userEmail = "";
  String? shopLogo;

  final List<String> _pageTitles = [
    "Take Order",
    "Orders",
    "Products",
    "Shop Profile",
    "Sales Reports",
    "Sales Reports Insights",
    "Customers",
    "Category",
    "Expenses",
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear saved user
    FirestoreService().setVendorId(null); // Clear vendor state
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    // 1. Initial load from cache for speed
    setState(() {
      username = prefs.getString("username") ?? '';
      role = prefs.getString("role") ?? '';
      shopName = prefs.getString("shopName") ?? prefs.getString("name") ?? '';
      userEmail = prefs.getString("email") ?? '';
      shopLogo = prefs.getString("shopLogo");
    });

    // 2. Load fresh details from Firestore to sync updates
    try {
      final vendorDetails = await FirestoreService().getVendorDetails();
      if (vendorDetails != null) {
        final newLogo = vendorDetails['shopLogo'];
        final newShopName = vendorDetails['shopName'];

        setState(() {
          shopLogo = newLogo;
          if (newShopName != null) {
            shopName = newShopName;
          }
        });

        // Sync back to local cache
        if (newLogo != null) await prefs.setString("shopLogo", newLogo);
        if (newShopName != null) await prefs.setString("shopName", newShopName);
      }
    } catch (e) {
      debugPrint("Error syncing profile data: $e");
    }
  }

  Widget _getPageContent() {
    return IndexedStack(
      index: _selectedIndex < 4 ? _selectedIndex : 0,
      children: [
        const TakeOrderScreen(isEmbedded: true),
        OrderListScreen(
          isEmbedded: true,
          onFullEdit: () {
            setState(() {
              _selectedIndex = 0;
            });
          },
        ),
        const ProductListScreen(isEmbedded: true),
        ShopProfileScreen(
          isEmbedded: true,
          onProfileUpdate: _loadUserData,
        ),
      ],
    );
  }

  void _onDrawerItemTap(int index) async {
    Navigator.pop(context); // Close drawer

    Widget target;
    switch (index) {
      case 0:
        target = const TakeOrderScreen();
        break;
      case 1:
        target = const ProductListScreen();
        break;
      case 2:
        target = const OrderListScreen();
        break;
      case 3:
        target = const ShopProfileScreen();
        break;
      case 4:
        target = const SalesDashboardScreen();
        break;
      case 5:
        target = const VendorDetailScreen();
        break;
      case 6:
        target = const CustomerListScreen();
        break;
      case 7:
        target = const CategoryListScreen();
        break;
      case 8:
        target = const ExpenseListScreen();
        break;
      default:
        return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => target),
    );

    if (result == true || index == 3) {
      _loadUserData();
    }
  }
  @override
  Widget build(BuildContext context) {
    final bool showAdminAppBar = _selectedIndex != 3;
    print("Admin - ${_pageTitles[_selectedIndex]}");
    print(_pageTitles);
    print(_selectedIndex);
    return Scaffold(
      appBar: showAdminAppBar
          ? AppBar(
              backgroundColor: AppColors.primary,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                "Admin - ${_pageTitles[_selectedIndex]}",
                style: const TextStyle(color: AppColors.cardColor),
              ),
              actions: [
                if (_selectedIndex == 2)
                  IconButton(
                    icon: const Icon(Icons.category_outlined,
                        color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const CategoryListScreen()),
                      );
                    },
                    tooltip: "Add Category",
                  ),
              ],
            )
          : null,
      drawer: Drawer(
        child: SafeArea(
          top: false, // UserAccountsDrawerHeader already handles top
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                ),
                accountName: Text(shopName),
                accountEmail: Text(userEmail),
                currentAccountPicture: CircleAvatar(
                  key: ValueKey(shopLogo), // Force rebuild if logo URL changes
                  backgroundColor: AppColors.cardColor,
                  backgroundImage: (shopLogo != null && shopLogo!.isNotEmpty)
                      ? NetworkImage(shopLogo!)
                      : null,
                  child: (shopLogo == null || shopLogo!.isEmpty)
                      ? Icon(Icons.storefront, size: 40, color: AppColors.primary)
                      : null,
                ),
                otherAccountsPictures: [
                  GestureDetector(
                    onTap: () => _logout(context),
                    child: const CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.logout, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart, color: AppColors.textColor),
                title: const Text(
                  "Sales Reports",
                  style: TextStyle(color: AppColors.textColor),
                ),
                onTap: () => _onDrawerItemTap(4),
              ),
              ListTile(
                leading: const Icon(Icons.insights, color: AppColors.textColor),
                title: const Text(
                  "Sales Reports Insights",
                  style: TextStyle(color: AppColors.textColor),
                ),
                onTap: () => _onDrawerItemTap(5),
              ),
              const Divider(
                color: AppColors.secondary,
                height: 0.5,
              ),
              ListTile(
                leading: Icon(Icons.assignment,
                    color: _selectedIndex == 0
                        ? AppColors.primary
                        : AppColors.textColor),
                title: Text(
                  "Take Order",
                  style: TextStyle(
                      color: _selectedIndex == 0
                          ? AppColors.primary
                          : AppColors.textColor),
                ),
                selected: _selectedIndex == 0,
                onTap: () => _onDrawerItemTap(0),
              ),
              ListTile(
                leading: Icon(Icons.shopping_cart,
                    color: _selectedIndex == 2
                        ? AppColors.primary
                        : AppColors.textColor),
                title: Text(
                  "Orders",
                  style: TextStyle(
                      color: _selectedIndex == 2
                          ? AppColors.primary
                          : AppColors.textColor),
                ),
                selected: _selectedIndex == 2,
                onTap: () => _onDrawerItemTap(2),
              ),
              // ListTile(
              //   leading:
              //       const Icon(Icons.pending_actions, color: AppColors.textColor),
              //   title: const Text(
              //     "Pending Items",
              //     style: TextStyle(color: AppColors.textColor),
              //   ),
              //   onTap: () => _onDrawerItemTap(9),
              // ),

              const Divider(
                color: AppColors.secondary,
                height: 0.5,
              ),
              ListTile(
                leading: const Icon(Icons.group, color: AppColors.textColor),
                title: const Text(
                  "Customers",
                  style: TextStyle(color: AppColors.textColor),
                ),
                onTap: () => _onDrawerItemTap(6),
              ),
              const Divider(
                color: AppColors.secondary,
                height: 0.5,
              ),
              ListTile(
                leading: Icon(Icons.shopping_bag,
                    color: _selectedIndex == 1
                        ? AppColors.primary
                        : AppColors.textColor),
                title: Text(
                  "Product",
                  style: TextStyle(
                      color: _selectedIndex == 1
                          ? AppColors.primary
                          : AppColors.textColor),
                ),
                selected: _selectedIndex == 1,
                onTap: () => _onDrawerItemTap(1),
              ),
              ListTile(
                leading: const Icon(Icons.category, color: AppColors.textColor),
                title: const Text(
                  "Category",
                  style: TextStyle(color: AppColors.textColor),
                ),
                onTap: () => _onDrawerItemTap(7),
              ),
              const Divider(
                color: AppColors.secondary,
                height: 0.5,
              ),
              ListTile(
                leading: Icon(
                  Icons.storefront,
                  color:
                      _selectedIndex == 3 ? AppColors.primary : AppColors.textColor,
                ),
                title: Text(
                  "Shop Profile",
                  style: TextStyle(
                    color: _selectedIndex == 3
                        ? AppColors.primary
                        : AppColors.textColor,
                  ),
                ),
                selected: _selectedIndex == 3,
                onTap: () => _onDrawerItemTap(3),
              ),
              const Divider(
                color: AppColors.secondary,
                height: 0.5,
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long, color: AppColors.textColor),
                title: const Text(
                  "Expenses",
                  style: TextStyle(color: AppColors.textColor),
                ),
                onTap: () => _onDrawerItemTap(8),
              ),
            ],
          ),
        ),
      ),
      body: _getPageContent(),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Take Order',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront),
            label: 'Shop Profile',
          ),
        ],
        currentIndex: _selectedIndex < 4 ? _selectedIndex : 0,
        selectedItemColor: _selectedIndex < 4 ? AppColors.primary : Colors.grey,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
      ),
    );
  }
}
