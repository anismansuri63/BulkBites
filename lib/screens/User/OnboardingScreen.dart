import 'package:flutter/material.dart';
import '../../services/FirestoreService.dart';
import '../../utlity/AppColors.dart';
import '../../widgets/CommonTextField.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _addressController = TextEditingController();
  
  bool _isLoading = false;
  bool _isCodeVerified = false;

  final FirestoreService _firestoreService = FirestoreService();

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestoreService.validateOnboardingCode(code);
      if (snapshot != null) {
        setState(() {
          _isCodeVerified = true;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showError("Invalid or already used code.");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print("Verification failed: $e");
      _showError("Verification failed: $e");
    }
  }

  Future<void> _completeOnboarding() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final vendorDetails = {
        'shopName': _shopNameController.text.trim(),
        'address': _addressController.text.trim(),
        'billingDetails': 'Standard Plan', // Example
      };

      await _firestoreService.onboardVendor(
        code: _codeController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        vendorDetails: vendorDetails,
      );

      if (!mounted) return;
      Navigator.pop(context, true); // Success
      _showMessage("Onboarding complete! Please login.");

    } catch (e) {
      setState(() => _isLoading = false);
      _showError("Onboarding failed: $e");

    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
    ));
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vendor Onboarding"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isCodeVerified ? "Step 2: Setup Your Shop" : "Step 1: Verify Code",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              Text(
                _isCodeVerified 
                  ? "Enter your account and shop details to get started."
                  : "Enter the unique onboarding code provided by the administrator.",
                style: TextStyle(color: AppColors.textColor.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 32),

              if (!_isCodeVerified) ...[
                CommonTextField(
                  controller: _codeController,
                  label: "Onboarding Code",
                  prefixIcon: Icons.vpn_key,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Verify Code"),
                  ),
                ),
              ] else ...[
                CommonTextField(
                  controller: _emailController,
                  label: "Email Address",
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v!.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 16),
                CommonTextField(
                  controller: _passwordController,
                  label: "Password",
                  prefixIcon: Icons.lock,
                  obscureText: true,
                  validator: (v) => v!.length < 6 ? "Min 6 chars" : null,
                ),
                const SizedBox(height: 16),
                CommonTextField(
                  controller: _shopNameController,
                  label: "Shop Name",
                  prefixIcon: Icons.store,
                  validator: (v) => v!.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 16),
                CommonTextField(
                  controller: _addressController,
                  label: "Address",
                  prefixIcon: Icons.location_on,
                  maxLines: 2,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _completeOnboarding,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Complete Setup"),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}