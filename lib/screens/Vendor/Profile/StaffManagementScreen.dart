import 'package:flutter/material.dart';
import '../../../services/FirestoreService.dart';
import '../../../utlity/AppColors.dart';
import '../../../widgets/CommonTextField.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _staffNameController = TextEditingController();
  
  List<String> _staffList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStaffList();
  }

  Future<void> _loadStaffList() async {
    setState(() => _isLoading = true);
    try {
      final list = await _firestoreService.getStaffList();
      setState(() {
        _staffList = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading staff: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addStaff() async {
    final name = _staffNameController.text.trim();
    if (name.isEmpty) return;

    if (_staffList.contains(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Staff member already exists!"), backgroundColor: AppColors.error),
      );
      return;
    }

    try {
      await _firestoreService.addStaffMember(name);
      _staffNameController.clear();
      _loadStaffList();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Staff member added!"), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _removeStaff(String name) async {
    try {
      await _firestoreService.removeStaffMember(name);
      _loadStaffList();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Staff member removed!"), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Staff Management", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildAddStaffSection(),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Current Staff Members", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: _buildStaffList()),
                ],
              ),
            ),
    );
  }

  Widget _buildAddStaffSection() {
    return Row(
      children: [
        Expanded(
          child: CommonTextField(
            controller: _staffNameController,
            label: "Staff Name",
            hintText: "Enter staff name",
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _addStaff,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Icon(Icons.add),
        ),
      ],
    );
  }

  Widget _buildStaffList() {
    if (_staffList.isEmpty) {
      return const Center(child: Text("No staff members added yet."));
    }

    return ListView.builder(
      itemCount: _staffList.length,
      itemBuilder: (context, index) {
        final name = _staffList[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person), foregroundColor: AppColors.primary,),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: () => _confirmDelete(name),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: AppColors.cardColor,
        title: const Text(
          "Remove Staff",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textColor,
          ),
        ),
        content: Text(
          "Are you sure you want to remove '$name'?",
          style: TextStyle(color: AppColors.textColor.withValues(alpha: 0.7)),
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
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _removeStaff(name);
    }
  }
}
