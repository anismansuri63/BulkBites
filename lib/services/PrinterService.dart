import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import '../utlity/AppColors.dart';
import 'FirestoreService.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();

  factory PrinterService() => _instance;

  PrinterService._internal();

  bool _isConnected = false;

  bool get isConnected => _isConnected;

// ============================================================
// PERMISSIONS
// ============================================================

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      // For Android 12 (API 31) and higher
      final connectStatus = await Permission.bluetoothConnect.status;
      final scanStatus = await Permission.bluetoothScan.status;

      if (!connectStatus.isGranted || !scanStatus.isGranted) {
        final statuses = await [
          Permission.bluetoothConnect,
          Permission.bluetoothScan,
          Permission.bluetoothAdvertise,
          Permission.location,
        ].request();
        
        return statuses[Permission.bluetoothConnect]!.isGranted &&
               statuses[Permission.bluetoothScan]!.isGranted;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      return status.isGranted;
    }
    return true;
  }

// ============================================================
// CONNECTIVITY
// ============================================================

  Future<List<BluetoothInfo>> getBluetoothDevices() async {
    try {
      await requestPermissions();
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (e) {
      return [];
    }
  }

  Future<bool> connect(String address) async {
    try {
      await requestPermissions();
      final result = await PrintBluetoothThermal.connect(
        macPrinterAddress: address,
      );

      _isConnected = result;
      return result;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}

    _isConnected = false;
  }

  Future<bool> get connectionStatus async {
    try {
      // Use a timeout to prevent hanging on real devices
      return await PrintBluetoothThermal.connectionStatus.timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    }
  }

// ============================================================
// STATUS CHECK
// ============================================================

  /// Returns 'ready', 'bluetooth_off', 'permission_denied', or 'not_connected'
  Future<String> checkPrinterStatus() async {
    final bool permissionGranted = await requestPermissions();
    if (!permissionGranted) return "permission_denied";

    final bool bluetoothEnabled = await PrintBluetoothThermal.bluetoothEnabled;
    if (!bluetoothEnabled) return "bluetooth_off";

    final bool connected = await connectionStatus; // Uses the timeout method
    if (!connected) return "not_connected";

    return "ready";
  }

  Future<bool> isPrintingEnabled(String type) async {
    final settings = await FirestoreService().getPrintSettings(type);
    return settings['enabled'] ?? true;
  }

  Future<void> setPrintingEnabled(String type, bool value) async {
    await FirestoreService().updatePrintSettings(type, {'enabled': value});
  }

  // ============================================================
  // GLOBAL PRINTER PICKER
  // ============================================================

  Future<void> showPrinterPicker(BuildContext context) async {
    final String status = await checkPrinterStatus();

    if (status == "ready") {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Printer is already connected and ready!"),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (status == "permission_denied") {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Bluetooth permissions are required."),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: "SETTINGS",
              textColor: Colors.white,
              onPressed: () => AppSettings.openAppSettings(type: AppSettingsType.settings),
            ),
          ),
        );
      }
      return;
    }

    if (status == "bluetooth_off") {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Bluetooth is turned off."),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: "SETTINGS",
              textColor: Colors.white,
              onPressed: () => AppSettings.openAppSettings(type: AppSettingsType.bluetooth),
            ),
          ),
        );
      }
      return;
    }

    // Status is "not_connected", proceed with listing devices
    final List<BluetoothInfo> devices = await getBluetoothDevices();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Select Printer"),
        content: devices.isEmpty
            ? const Text("No paired Bluetooth devices found. Please pair your printer in system settings first.")
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: devices.length,
                  itemBuilder: (c, i) => ListTile(
                    title: Text(devices[i].name),
                    subtitle: Text(devices[i].macAdress),
                    onTap: () async {
                      Navigator.pop(ctx);
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      );
                      final connected = await connect(devices[i].macAdress);
                      if (context.mounted) Navigator.pop(context);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(connected ? "Connected to ${devices[i].name}" : "Failed to connect"),
                            backgroundColor: connected ? AppColors.success : AppColors.error,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close", style: TextStyle(color: AppColors.primary),)),
        ],
      ),
    );
  }

// ============================================================
// KOT
// ============================================================

  Future<bool> printKOT(Map<String, dynamic> orderData) async {
    // Fetch Customization Settings
    final kotSettings = await FirestoreService().getPrintSettings('kot');
    if (!(kotSettings['enabled'] ?? true)) return true; // Skip if disabled

    final status = await checkPrinterStatus();
    print('status');
    print(status);
    if (status != "ready") return false;
    await flushPrintBuffer();

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      // Header
      bytes += generator.text('KITCHEN ORDER',
          styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1, width: PosTextSize.size1));
      bytes += generator.hr();

      // Order Info
      if (kotSettings['showOrderId'] ?? true) {
        String orderId = (orderData['id'] ?? 'N/A').toString();
        String lastElement = orderId.split(' ').last;
        bytes += generator.text('KO ID: #$lastElement', styles: const PosStyles(bold: true));
      }

      if (kotSettings['showDate'] ?? true) {
        bytes += generator.text('DATE: ${DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now())}');
      }

      if (kotSettings['showOrderType'] ?? true) {
        final orderType = (orderData['orderType'] ?? 'TAKE AWAY').toString().toUpperCase();
        bytes += generator.text('TYPE: $orderType', styles: const PosStyles(bold: true));
      }

      // Customer Info
      bool showName = kotSettings['showCustomerName'] ?? true;
      bool showMobile = kotSettings['showCustomerMobile'] ?? true;
      
      if (showName || showMobile) {
        String customerLine = "C: ";
        if (showName) customerLine += (orderData['customerName'] ?? 'Guest').toString();
        if (showName && showMobile) customerLine += " - ";
        if (showMobile) customerLine += (orderData['customerMobile'] ?? '-').toString();
        bytes += generator.text(customerLine);
      }

      bytes += generator.hr();

      // Items Header
      bytes += generator.row([
        PosColumn(text: 'ITEM', width: 9, styles: const PosStyles(bold: true)),
        PosColumn(text: 'QTY', width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
      bytes += generator.hr();

      // Items
      final items = orderData['items'];
      if (items is List) {
        for (final item in items) {
          if (item is! Map) continue;
          bytes += generator.row([
            PosColumn(text: (item['productName'] ?? '').toString(), width: 9),
            PosColumn(text: (item['quantity'] ?? 0).toString(), width: 3, styles: const PosStyles(align: PosAlign.right, bold: true)),
          ]);

          final optionName = (item['optionName'] ?? '').toString();
          if (optionName.isNotEmpty && optionName.toLowerCase() != 'default') {
            bytes += generator.text('  -> $optionName', styles: const PosStyles(bold: true));
          }
        }
      }
      bytes += generator.hr();

      // Note
      if (kotSettings['showInstructions'] ?? true) {
        final note = (orderData['note'] ?? '').toString().trim();
        if (note.isNotEmpty) {
          bytes += generator.text('INSTRUCTIONS:', styles: const PosStyles(bold: true));
          bytes += generator.text(note);
          bytes += generator.hr();
        }
      }

      bytes += generator.cut();
      print('PrintBluetoothThermal.writeBytes(bytes);');
      await PrintBluetoothThermal.writeBytes(bytes);
      return true;
    } catch (e) {
      print('KOT printing error: $e');
      return false;
    }
  }

// ============================================================
// BILL
// ============================================================
  Future<bool> printBill(
    Map<String, dynamic> orderData, {
    String shopName = 'HUNGRY BITES',
    String? shopAddress,
    String? shopContact,
    bool ignoreEnabledFlag = false,
  }) async {
    // Fetch Customization Settings
    final billSettings = await FirestoreService().getPrintSettings('bill');
    if (!ignoreEnabledFlag && !(billSettings['enabled'] ?? true)) return true; // Skip if disabled in auto flow

    final status = await checkPrinterStatus();
    if (status != "ready") return false;
    await flushPrintBuffer();

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      // 1. SHOP LOGO
      bool showLogo = billSettings['showLogo'] ?? true;
      String? logoUrl = billSettings['billLogo'];
      
      // Fallback to main shop logo if bill-specific logo is missing
      if (logoUrl == null || logoUrl.isEmpty) {
        final vendorDetails = await FirestoreService().getVendorDetails();
        logoUrl = vendorDetails?['shopLogo'];
      }

      if (showLogo && logoUrl != null && logoUrl.isNotEmpty) {
        await _printImageFromUrl(generator, bytes, logoUrl, width: 180);
      }

      // 2. SHOP HEADER
      bytes += generator.text(shopName,
          styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
      if (shopAddress != null && shopAddress.trim().isNotEmpty) {
        bytes += generator.text(shopAddress, styles: const PosStyles(align: PosAlign.center));
      }
      if (shopContact != null && shopContact.trim().isNotEmpty) {
        bytes += generator.text('Ph: $shopContact', styles: const PosStyles(align: PosAlign.center));
      }
      bytes += generator.hr();

      // 3. ORDER INFO
      String orderId = (orderData['id'] ?? 'N/A').toString().toUpperCase();
      final customerName = (orderData['customerName'] ?? 'Guest').toString();
      final customerMobile = (orderData['customerMobile'] ?? '-').toString();
      bytes += generator.text('BILL: #$orderId');
      bytes += generator.text('DATE: ${DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now())}');
      bytes += generator.text('C: $customerName - $customerMobile');
      bytes += generator.hr();

      // 4. ITEMS HEADER
      bytes += generator.row([
        PosColumn(text: 'ITEM', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: 'PRICE', width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
        PosColumn(text: 'QTY', width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
      bytes += generator.hr();

      // 5. ITEMS
      final items = orderData['items'];
      if (items is List) {
        for (final item in items) {
          if (item is! Map) continue;
          final productName = (item['productName'] ?? '').toString();
          final double price = (item['price'] as num?)?.toDouble() ?? 0;
          final int quantity = (item['quantity'] as num?)?.toInt() ?? 0;

          bytes += generator.row([
            PosColumn(text: productName, width: 6),
            PosColumn(text: price.toStringAsFixed(0), width: 3, styles: const PosStyles(align: PosAlign.right)),
            PosColumn(text: quantity.toString(), width: 3, styles: const PosStyles(align: PosAlign.right)),
          ]);

          final optionName = (item['optionName'] ?? '').toString();
          if (optionName.isNotEmpty && optionName.toLowerCase() != 'default') {
            bytes += generator.text('  -> $optionName', styles: const PosStyles(bold: true));
          }
        }
      }
      bytes += generator.hr();

      // 6. TOTAL
      final double total = (orderData['totalAmount'] as num?)?.toDouble() ?? 0;
      bytes += generator.row([
        PosColumn(text: 'GRAND TOTAL', width: 7, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Rs ${total.toStringAsFixed(2)}', width: 5, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
      final paymentType = (orderData['paymentType'] ?? '').toString();
      bytes += generator.text('MODE: $paymentType', styles: const PosStyles(align: PosAlign.right));
      bytes += generator.hr();

      // 7. PAYMENT QR CODE
      bool showQr = billSettings['showQrCode'] ?? false;
      String? qrImageUrl = billSettings['paymentQr'];
      if (showQr && qrImageUrl != null && qrImageUrl.isNotEmpty) {
        bytes += generator.text("Scan to Pay", styles: const PosStyles(align: PosAlign.center, bold: true));
        await _printImageFromUrl(generator, bytes, qrImageUrl, width: 275);
      }

      // 8. FOOTER
      bool showFooter = billSettings['showFooter'] ?? false;
      if (showFooter) {
        String footerText = billSettings['footerText'] ?? 'THANK YOU! VISIT AGAIN';
        bytes += generator.text(footerText,
            styles: const PosStyles(align: PosAlign.center, bold: true));
      }

      bytes += generator.cut();
      await PrintBluetoothThermal.writeBytes(bytes);
      return true;
    } catch (e) {
      print('Bill printing error: $e');
      return false;
    }
  }

  /// Helper to download and add an image to the printer buffer
  Future<void> _printImageFromUrl(Generator generator, List<int> bytes, String url, {required int width}) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Uint8List imageBytes = response.bodyBytes;
        final img.Image? originalImage = img.decodeImage(imageBytes);
        if (originalImage != null) {
          final img.Image resizedImage = img.copyResize(originalImage, width: width);
          bytes.addAll(generator.image(resizedImage, align: PosAlign.center));
          bytes.addAll(generator.feed(1));
        }
      }
    } catch (e) {
      debugPrint("Image printing error ($url): $e");
    }
  }
  // ============================================================
// FLUSH/CANCEL PENDING PRINTS
// ============================================================
  
  Future<bool> flushPrintBuffer() async {
    try {
      // Send ESC/POS command to clear print buffer (ESC @ = initialize printer)
      // This resets the printer and clears any pending data
      final List<int> clearCommand = [0x1B, 0x40]; // ESC @
      await PrintBluetoothThermal.writeBytes(clearCommand);

      // Also try to flush the connection by reading any pending data
      // Some printers need a small delay to process the clear command
      await Future.delayed(const Duration(milliseconds: 200));

      return true;
    } catch (e) {
      print('Error flushing print buffer: $e');
      return false;
    }
  }
}
