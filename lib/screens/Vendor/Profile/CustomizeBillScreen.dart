import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/FirestoreService.dart';
import '../../../utlity/AppColors.dart';
import '../../../widgets/CommonTextField.dart';

class CustomizeBillScreen extends StatefulWidget {
  const CustomizeBillScreen({super.key});

  @override
  State<CustomizeBillScreen> createState() => _CustomizeBillScreenState();
}

class _CustomizeBillScreenState extends State<CustomizeBillScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;

  // Settings
  bool _isEnabled = true;
  bool _showLogo = true;
  bool _showQrCode = false;
  bool _showFooter = true;
  final TextEditingController _footerController = TextEditingController();

  // Image Upload State
  final ImagePicker _picker = ImagePicker();
  final CloudinaryPublic _cloudinary =
      CloudinaryPublic('dei574s6o', 'BulkBites', cache: false);

  String? _existingLogoUrl;
  String? _newLogoUrl;
  bool _isUploadingLogo = false;

  String? _existingQrUrl;
  String? _newQrUrl;
  bool _isUploadingQr = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _firestoreService.getPrintSettings('bill');
      if (settings.isNotEmpty) {
        setState(() {
          _isEnabled = settings['enabled'] ?? true;
          _showLogo = settings['showLogo'] ?? true;
          _showQrCode = settings['showQrCode'] ?? false;
          _showFooter = settings['showFooter'] ?? true;
          _existingLogoUrl = settings['billLogo'];
          _existingQrUrl = settings['paymentQr'];
          _footerController.text =
              settings['footerText'] ?? 'THANK YOU! VISIT AGAIN';
        });
      } else {
        _footerController.text = 'THANK YOU! VISIT AGAIN';
      }
    } catch (e) {
      debugPrint("Error loading bill settings: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(bool isLogo) async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() {
      if (isLogo) {
        _isUploadingLogo = true;
      } else {
        _isUploadingQr = true;
      }
    });

    try {
      CloudinaryResponse response;
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        response = await _cloudinary.uploadFile(
          CloudinaryFile.fromBytesData(
            bytes,
            identifier: 'bill_${isLogo ? 'logo' : 'qr'}_${DateTime.now().millisecondsSinceEpoch}',
            resourceType: CloudinaryResourceType.Image,
          ),
        );
      } else {
        response = await _cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            pickedFile.path,
            resourceType: CloudinaryResourceType.Image,
          ),
        );
      }

      setState(() {
        if (isLogo) {
          _newLogoUrl = response.secureUrl;
        } else {
          _newQrUrl = response.secureUrl;
        }
      });
    } catch (e) {
      debugPrint("Error uploading image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload failed: $e"), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isLogo) {
            _isUploadingLogo = false;
          } else {
            _isUploadingQr = false;
          }
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isUploadingLogo || _isUploadingQr) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please wait for uploads to finish")),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _firestoreService.updatePrintSettings('bill', {
        'enabled': _isEnabled,
        'showLogo': _showLogo,
        'showQrCode': _showQrCode,
        'showFooter': _showFooter,
        'billLogo': _newLogoUrl ?? _existingLogoUrl,
        'paymentQr': _newQrUrl ?? _existingQrUrl,
        'footerText': _footerController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Bill settings updated successfully!"),
              backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Failed to update settings: $e"),
              backgroundColor: AppColors.error),
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
        title: const Text("Customize Bill",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle("Master Control"),
                    SwitchListTile(
                      title: const Text("Enable Bill Printing",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle:
                          const Text("Turn off if you don't use a bill printer"),
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
                            _buildSectionTitle("Visual Elements"),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _buildImagePicker(
                                  label: "Bill Logo",
                                  imageUrl: _newLogoUrl ?? _existingLogoUrl,
                                  isUploading: _isUploadingLogo,
                                  onTap: () => _pickImage(true),
                                  size: 85,
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text("Logo Visibility",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const Text(
                                          "Show your logo on physical bills",
                                          style: TextStyle(
                                              fontSize: 12, color: Colors.grey)),
                                      const SizedBox(height: 8),
                                      Switch(
                                        value: _showLogo,
                                        activeColor: AppColors.primary,
                                        onChanged: (val) =>
                                            setState(() => _showLogo = val),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Divider(),
                            _buildSectionTitle("Payment QR Code"),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _buildImagePicker(
                                  label: "QR Image",
                                  imageUrl: _newQrUrl ?? _existingQrUrl,
                                  isUploading: _isUploadingQr,
                                  onTap: () => _pickImage(false),
                                  size: 85,
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text("Enable QR Code",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const Text("Customers can scan to pay",
                                          style: TextStyle(
                                              fontSize: 12, color: Colors.grey)),
                                      const SizedBox(height: 8),
                                      Switch(
                                        value: _showQrCode,
                                        activeColor: AppColors.primary,
                                        onChanged: (val) =>
                                            setState(() => _showQrCode = val),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Divider(),
                            _buildSectionTitle("Footer Text"),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Enable Footer Message",
                                    style: TextStyle(fontWeight: FontWeight.bold)),
                                Switch(
                                  value: _showFooter,
                                  activeColor: AppColors.primary,
                                  onChanged: (val) =>
                                      setState(() => _showFooter = val),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            CommonTextField(
                              controller: _footerController,
                              label: "Footer Message",
                              hintText: "Add custom lines for your customers...",
                              maxLines: 5,
                              enabled: _showFooter,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "This text will appear at the very bottom of the bill. You can add up to 5 lines.",
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving
                ? const CircularProgressIndicator(
                    color: Colors.white)
                : const Text("Save Bill Customization",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
      ),
    );
  }

  Widget _buildImagePicker({
    required String label,
    required String? imageUrl,
    required bool isUploading,
    required VoidCallback onTap,
    double size = 150,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: isUploading ? null : onTap,
          child: Stack(
            children: [
              Container(
                height: size,
                width: size,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: isUploading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary,))
                    : imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(imageUrl, fit: BoxFit.contain),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo,
                                  color: Colors.grey.shade400, size: 24),
                              const SizedBox(height: 4),
                              const Text("Upload",
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 10)),
                            ],
                          ),
              ),
              if (!isUploading && imageUrl != null)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 14),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
