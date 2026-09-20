import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/FirestoreService.dart';
import '../../utlity/AppColors.dart';
import 'AdminScreen.dart';
import 'OnboardingScreen.dart';
import 'SuperAdminScreen.dart';
import '../../widgets/CommonTextField.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
  }


  void _navigateBasedOnRole(String role) {
    if (role == "super_admin") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SuperAdminScreen()),
      );
    } else if (role == "vendor_admin") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminScreen()),
      );
    }
  }

  /// 🔹 Login logic (Firestore Only)
  Future<void> _loginUser() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError("Please enter both email and password");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 0. Super Admin Static Entry Check
      if (email == "anis" && password == "anis123") {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("username", email);
        await prefs.setString("role", "super_admin");
        await prefs.setString("name", "Super Admin");
        await prefs.setString("email", email);
        
        _navigateBasedOnRole("super_admin");
        return;
      }

      // 1. Fetch Profile and Verify Credentials from Firestore
      final userData = await _firestoreService.loginWithFirestore(email, password);

      if (userData != null) {
        String role = userData['role'] ?? 'normal';
        String name = userData['name'] ?? '';
        String vendorId = userData['vendorId'] ?? '';
        String uid = userData['uid'] ?? '';

        // 2. Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("username", email);
        await prefs.setString("role", role);
        await prefs.setString("name", name);
        await prefs.setString("email", email);
        if (uid.isNotEmpty) {
          await prefs.setString("uid", uid);
        }
        if (vendorId.isNotEmpty) {
          await prefs.setString("vendorId", vendorId);
          _firestoreService.setVendorId(vendorId);
        }

        _navigateBasedOnRole(role);
      } else {
        _showError("Invalid email or password ❌");
      }
    } catch (e) {
      _showError("Login failed: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primary.withValues(alpha: 0.8), AppColors.primary],
            ),
          ),
          child: Column(
            children: [
              // Header Section
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.only(top: 80),
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.cardColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.lock,
                          size: 50,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Swift Order",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cardColor,
                          fontFamily: 'Playfair',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Manage your business efficiently",
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.cardColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Login Form Section
              Expanded(
                flex: 4,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.cardColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(30.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Login",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textColor,
                            fontFamily: 'Playfair',
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Enter your credentials to continue",
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textColor.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Email Field
                        CommonTextField(
                          controller: _emailController,
                          label: "Email Address",
                          prefixIcon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),

                        // Password Field
                        CommonTextField(
                          controller: _passwordController,
                          label: "Password",
                          prefixIcon: Icons.lock,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              color: AppColors.textColor.withValues(alpha: 0.5),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 25),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _loginUser,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.cardColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 5,
                              shadowColor: AppColors.primary.withValues(alpha: 0.5),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                                : const Text(
                              "Login",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        
                        // Onboarding Section
                        Center(
                          child: Column(
                            children: [
                              Text(
                                "New Vendor?",
                                style: TextStyle(color: AppColors.textColor.withValues(alpha: 0.6)),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                                  );
                                },
                                child: const Text(
                                  "Onboard with Unique Code",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


