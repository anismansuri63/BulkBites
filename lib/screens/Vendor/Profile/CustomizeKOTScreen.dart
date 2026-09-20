import 'package:flutter/material.dart';
import '../../../services/FirestoreService.dart';
import '../../../utlity/AppColors.dart';

class CustomizeKOTScreen extends StatefulWidget {
  const CustomizeKOTScreen({super.key});

  @override
  State<CustomizeKOTScreen> createState() => _CustomizeKOTScreenState();
}

class _CustomizeKOTScreenState extends State<CustomizeKOTScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  bool _isLoading = true;
  bool _isSaving = false;

  // Settings
  bool _isEnabled = true;
  bool _showOrderType = true;
  bool _showCustomerName = true;
  bool _showCustomerMobile = true;
  bool _showInstructions = true;
  bool _showDate = true;
  bool _showOrderId = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _firestoreService.getPrintSettings('kot');
      if (settings.isNotEmpty) {
        setState(() {
          _isEnabled = settings['enabled'] ?? true;
          _showOrderType = settings['showOrderType'] ?? true;
          _showCustomerName = settings['showCustomerName'] ?? true;
          _showCustomerMobile = settings['showCustomerMobile'] ?? true;
          _showInstructions = settings['showInstructions'] ?? true;
          _showDate = settings['showDate'] ?? true;
          _showOrderId = settings['showOrderId'] ?? true;
        });
      }
    } catch (e) {
      debugPrint("Error loading KOT settings: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await _firestoreService.updatePrintSettings('kot', {
        'enabled': _isEnabled,
        'showOrderType': _showOrderType,
        'showCustomerName': _showCustomerName,
        'showCustomerMobile': _showCustomerMobile,
        'showInstructions': _showInstructions,
        'showDate': _showDate,
        'showOrderId': _showOrderId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("KOT settings updated successfully!"), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update settings: $e"), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Customize KOT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Master Control"),
                  SwitchListTile(
                    title: const Text("Enable KOT Printing",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle:
                        const Text("Turn off if you don't use a kitchen printer"),
                    value: _isEnabled,
                    activeColor: AppColors.primary,
                    onChanged: (val) => setState(() => _isEnabled = val),
                  ),
                  const Divider(),
                  Opacity(
                    opacity: _isEnabled ? 1.0 : 0.5,
                    child: AbsorbPointer(
                      absorbing: !_isEnabled,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle("Kitchen Information"),
                          _buildSwitch(
                              "Show Order ID",
                              _showOrderId,
                              (val) => setState(() => _showOrderId = val)),
                          _buildSwitch("Show Order Date/Time", _showDate,
                              (val) => setState(() => _showDate = val)),
                          _buildSwitch(
                              "Show Order Type (Take away/Dine in)",
                              _showOrderType,
                              (val) => setState(() => _showOrderType = val)),
                          _buildSwitch(
                              "Show Special Instructions",
                              _showInstructions,
                              (val) => setState(() => _showInstructions = val)),
                          const Divider(height: 32),
                          _buildSectionTitle("Customer Details"),
                          _buildSwitch(
                              "Show Customer Name",
                              _showCustomerName,
                              (val) => setState(() => _showCustomerName = val)),
                          _buildSwitch(
                              "Show Customer Mobile",
                              _showCustomerMobile,
                              (val) => setState(() => _showCustomerMobile = val)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("Save KOT Customization", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitch(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      value: value,
      activeThumbColor: AppColors.primary,
      onChanged: onChanged,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
      ),
    );
  }
}
