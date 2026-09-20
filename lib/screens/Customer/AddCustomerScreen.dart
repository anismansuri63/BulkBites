import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../model/Customer.dart';
import '../../services/FirestoreService.dart';
import '../../utlity/AppColors.dart';
import '../../widgets/CommonTextField.dart';

class AddCustomerScreen extends StatefulWidget {
  final Customer? customer;
  const AddCustomerScreen({super.key, this.customer});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();

  final FirestoreService _firestoreService = FirestoreService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.customer != null) {
      _nameController.text = widget.customer!.name;
      _mobileController.text = widget.customer!.mobile;
    }
  }

  // ============================================================
  // SAVE CUSTOMER UNDER VENDOR
  // ============================================================

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final data = {
      'name': _nameController.text.trim(),
      'mobile': _mobileController.text.trim(),
    };

    try {
      if (widget.customer == null) {
        // Adding new customer
        final fullData = {
          ...data,
          'orders': [],
          'totalOrders': 0,
          'totalSpent': 0.0,
        };
        await _firestoreService.addCustomer(fullData);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer added successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Updating existing customer
        await _firestoreService.updateCustomer(widget.customer!.id!, data);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer updated successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving customer: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.customer == null ? 'Add Customer' : 'Edit Customer',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveCustomer,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: AppColors.backgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Intro
              Text(
                widget.customer == null ? "Create New Customer" : "Edit Details",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textColor),
              ),
              const SizedBox(height: 8),
              Text(
                "Keep track of your customer's orders and spending history.",
                style: TextStyle(color: AppColors.textColor.withValues(alpha: 0.6), fontSize: 14),
              ),
              const SizedBox(height: 32),

              // Form Fields
              CommonTextField(
                controller: _nameController,
                label: 'Customer Name',
                prefixIcon: Icons.person,
                hintText: "Enter full name",
                validator: (val) => val == null || val.isEmpty ? 'Enter name' : null,
              ),

              const SizedBox(height: 20),

              CommonTextField(
                controller: _mobileController,
                label: 'Mobile Number',
                prefixIcon: Icons.phone,
                hintText: "10-digit number",
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter mobile number';
                  if (val.length != 10) return 'Enter valid 10-digit number';
                  return null;
                },
              ),
              const SizedBox(height: 40),
              
              // Bottom Save Button (Duplicate for convenience)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveCustomer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(widget.customer == null ? 'Save Customer' : 'Update Customer', 
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
