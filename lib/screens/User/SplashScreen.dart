import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../../services/FirestoreService.dart';
import 'AdminScreen.dart';
import 'LoginScreen.dart';
import 'SuperAdminScreen.dart';
import 'WhatsNewScreen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _startNavigationTimer();
  }

  void _startNavigationTimer() {
    // Keep the splash visible for a short duration
    Timer(const Duration(seconds: 3), () {
      _checkLoginStatus();
    });
  }

  Future<void> _checkLoginStatus() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final String? lastSeenVersion = prefs.getString("last_seen_version");
    final role = prefs.getString("role");
    final vendorId = prefs.getString("vendorId");

    // Check if we should show the "What's New" screen
    if (lastSeenVersion != WhatsNewScreen.currentVersion) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WhatsNewScreen(
            onDismiss: (validContext) {
              if (role != null) {
                if (vendorId != null) {
                  _firestoreService.setVendorId(vendorId);
                }
                _navigateBasedOnRole(validContext, role);
              } else {
                Navigator.pushReplacement(
                  validContext,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ),
      );
      return;
    }

    if (role != null) {
      if (vendorId != null) {
        _firestoreService.setVendorId(vendorId);
      }
      _navigateBasedOnRole(context, role);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }
  void _navigateBasedOnRole(BuildContext context, String role) {
    Widget targetScreen;
    targetScreen = const AdminScreen();
    if (role == "super_admin") {
      targetScreen = const SuperAdminScreen();
    } else if (role == "vendor_admin") {
      targetScreen = const AdminScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => targetScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Image.asset(
          'assets/splash/splash_icon.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.red.shade900,
            child: const Center(
              child: Icon(Icons.error_outline, color: Colors.white, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}
