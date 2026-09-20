import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/FirestoreService.dart';
import '../../utlity/AppColors.dart';
import '../../utlity/DateUtils.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'LoginScreen.dart';
import 'VendorDetailScreen.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}
class _SuperAdminScreenState extends State<SuperAdminScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: AppColors.cardColor,
        title: const Text(
          "Confirm Logout",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textColor,
          ),
        ),

        content: Text(
          "Are you sure you want to logout?",
          style: TextStyle(
            color: AppColors.textColor.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              "Cancel",
              style: TextStyle(color: AppColors.error),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      FirestoreService().setVendorId(null);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<void> _generateCode() async {
    final code = await _firestoreService.generateOnboardingCode();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: AppColors.cardColor,
        title: const Text(
          "Code Generated",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Share this code with the new vendor:",
              style: TextStyle(
                color: AppColors.textColor.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              code,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Super Admin Panel"),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _logout(context),
              tooltip: "Logout",
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: "Vendors", icon: Icon(Icons.store)),
              Tab(text: "Onboarding Codes", icon: Icon(Icons.vpn_key)),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _generateCode,
          label: const Text("Generate Code", style: TextStyle(
            color: AppColors.primary
          ),),
          icon: const Icon(Icons.add, color: AppColors.primary,),
          backgroundColor: Colors.white,
        ),
        body: TabBarView(
          children: [
            _buildVendorsList(),
            _buildCodesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('vendors').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No vendors onboarded yet."));

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final shopLogo = data['shopLogo'];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VendorDetailScreen(vendorData: data),
                    ),
                  );
                },
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  backgroundImage: shopLogo != null && shopLogo.toString().isNotEmpty 
                      ? NetworkImage(shopLogo) 
                      : null,
                  child: shopLogo == null || shopLogo.toString().isEmpty 
                      ? const Icon(Icons.store, color: AppColors.primary) 
                      : null,
                ),
                title: Text(data['shopName'] ?? 'Unnamed Shop'),
                subtitle: Text(data['address'] ?? 'No address'),
                trailing: const Icon(Icons.chevron_right),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCodesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('onboarding_codes').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No codes generated yet."));

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final bool isUsed = data['isUsed'] ?? false;
            final createdAt = BBDateUtils.parseDateTime(data['createdAt']);
            
            return ListTile(
              leading: Icon(Icons.vpn_key, color: isUsed ? Colors.grey : Colors.green),
              title: Text(data['code'] ?? 'N/A'),
              subtitle: Text(isUsed ? "Used" : "Available"),
              trailing: Text(
                createdAt != null ? DateFormat('dd MMM').format(createdAt) : '',
              ),
            );
          },
        );
      },
    );
  }
}
