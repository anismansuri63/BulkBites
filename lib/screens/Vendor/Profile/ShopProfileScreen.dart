import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/FirestoreService.dart';
import '../../../utlity/AppColors.dart';
import '../../../widgets/CommonTextField.dart';
import 'StaffManagementScreen.dart';
import 'CustomizeBillScreen.dart';
import 'CustomizeKOTScreen.dart';
class ShopProfileScreen extends StatefulWidget {
  final bool isEmbedded;
  final VoidCallback? onProfileUpdate;
  const ShopProfileScreen({super.key, this.isEmbedded = false, this.onProfileUpdate});
  @override
  State<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends State<ShopProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();

  // Vendor Controllers
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _gstController = TextEditingController();
  final TextEditingController _openTimeController = TextEditingController();
  final TextEditingController _closeTimeController = TextEditingController();

  // User Profile Controllers
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _userEmailController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingLogo = false;
  bool _isCustomBusinessDay = false;
  bool _showHighDemand = true;
  String? _uid;

  // Image Upload State
  final ImagePicker _picker = ImagePicker();
  final CloudinaryPublic _cloudinary =
      CloudinaryPublic('dei574s6o', 'BulkBites', cache: false);
  File? _selectedImage;
  Uint8List? _webImageBytes;
  String? _existingLogoUrl;
  String? _newLogoUrl;

  @override
  void initState() {
    super.initState();
    _loadAllDetails();
  }

  Future<void> _loadAllDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _uid = prefs.getString("uid");

      final results = await Future.wait([
        _firestoreService.getVendorDetails(),
        if (_uid != null)
          _firestoreService.getUserProfile(_uid!)
        else
          Future.value(null),
      ]);

      final vendorDetails = results[0];
      final userDetails = results[1];

      if (vendorDetails != null) {
        setState(() {
          _shopNameController.text = vendorDetails['shopName'] ?? '';
          _addressController.text = vendorDetails['address'] ?? '';
          _contactController.text = vendorDetails['contact'] ?? '';
          _gstController.text = vendorDetails['gstNumber'] ?? '';
          _existingLogoUrl = vendorDetails['shopLogo'];
          _isCustomBusinessDay = vendorDetails['isCustomBusinessDay'] ?? false;
          _showHighDemand = vendorDetails['showHighDemand'] ?? true;
          
          // Display times in 12-hour format
          String open24 = vendorDetails['shopOpenTime'] ?? '18:00';
          String close24 = vendorDetails['shopCloseTime'] ?? '03:00';
          _openTimeController.text = _formatTo12Hour(open24);
          _closeTimeController.text = _formatTo12Hour(close24);
        });
      }

      if (userDetails != null) {
        setState(() {
          _userNameController.text = userDetails['name'] ?? '';
          _userEmailController.text = userDetails['email'] ?? '';
        });
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Error loading details: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _gstController.dispose();
    _openTimeController.dispose();
    _closeTimeController.dispose();
    _userNameController.dispose();
    _userEmailController.dispose();
    super.dispose();
  }
  Future<void> _selectTime(TextEditingController controller) async {
    TimeOfDay initialTime;
    try {
      final DateTime dt = DateFormat('hh:mm a').parse(controller.text);
      initialTime = TimeOfDay.fromDateTime(dt);
    } catch (e) {
      // Fallback for 24h format
      final parts = controller.text.split(':');
      initialTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1].split(' ')[0]), // handle any trailing text
      );
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      barrierColor: AppColors.secondary.withOpacity(0.35),
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              secondary: AppColors.secondary,
              onPrimary: Colors.white,
              onSecondary: Colors.white,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteColor: AppColors.secondary.withOpacity(0.15),
              hourMinuteTextColor: AppColors.primary,
              dialBackgroundColor: Colors.grey.shade100,
              dialHandColor: AppColors.primary,
              dialTextColor: Colors.black87,
              dayPeriodColor: AppColors.secondary.withOpacity(0.25),
              dayPeriodTextColor: AppColors.primary,
              cancelButtonStyle: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(AppColors.primary),
              ),
              confirmButtonStyle: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(AppColors.primary),
              ),
              entryModeIconColor: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        final now = DateTime.now();
        final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
        controller.text = DateFormat('hh:mm a').format(dt);
      });
    }
  }

  String _formatTo12Hour(String time24) {
    try {
      final parts = time24.split(':');
      final dt = DateTime(2024, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat('hh:mm a').format(dt);
    } catch (e) {
      return time24;
    }
  }

  String _formatTo24Hour(String time12) {
    try {
      final dt = DateFormat('hh:mm a').parse(time12);
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return time12;
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() {
      _isUploadingLogo = true;
    });

    try {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        _webImageBytes = bytes;
      } else {
        _selectedImage = File(pickedFile.path);
      }

      // 1. Upload to Cloudinary
      await _uploadLogo();

      // 2. If it's a quick image-only update, sync to Firestore immediately
      if (_newLogoUrl != null) {
        await _firestoreService.updateVendorDetails({'shopLogo': _newLogoUrl});
        // Sync local cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("shopLogo", _newLogoUrl!);
        
        if (widget.onProfileUpdate != null) {
          widget.onProfileUpdate!();
        }

        if (mounted) {
          setState(() {
            _existingLogoUrl = _newLogoUrl;
            _newLogoUrl = null;
            _selectedImage = null;
            _webImageBytes = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Logo updated successfully!"), backgroundColor: AppColors.success),
          );
        }
      }
    } catch (e) {
      debugPrint("Error picking/uploading image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload failed: $e"), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingLogo = false;
        });
      }
    }
  }

  Future<void> _uploadLogo() async {
    if (kIsWeb && _webImageBytes != null) {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromBytesData(
          _webImageBytes!,
          identifier: 'shop_logo_${DateTime.now().millisecondsSinceEpoch}',
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      _newLogoUrl = response.secureUrl;
    } else if (_selectedImage != null) {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          _selectedImage!.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      _newLogoUrl = response.secureUrl;
      print('_newLogoUrl');
      print(_newLogoUrl);
    }
  }
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isUploadingLogo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please wait for logo upload to finish")),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final Future vendorUpdate = _firestoreService.updateVendorDetails({
        'shopName': _shopNameController.text.trim(),
        'address': _addressController.text.trim(),
        'contact': _contactController.text.trim(),
        'gstNumber': _gstController.text.trim(),
        'shopLogo': _newLogoUrl ?? _existingLogoUrl,
        'isCustomBusinessDay': _isCustomBusinessDay,
        'showHighDemand': _showHighDemand,
        'shopOpenTime': _formatTo24Hour(_openTimeController.text),
        'shopCloseTime': _formatTo24Hour(_closeTimeController.text),
      });

      final Future? userUpdate = _uid != null
          ? _firestoreService.updateUserProfile(_uid!, {
              'name': _userNameController.text.trim(),
              'email': _userEmailController.text.trim(),
            })
          : null;

      await Future.wait([
        vendorUpdate,
        if (userUpdate != null) userUpdate,
      ]);

      // Update SharedPreferences to keep local cache in sync
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("name", _userNameController.text.trim()); // User Profile Name
      await prefs.setString("shopName", _shopNameController.text.trim()); // Shop Name
      await prefs.setString("email", _userEmailController.text.trim());
      if (_newLogoUrl != null) {
        await prefs.setString("shopLogo", _newLogoUrl!);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Profile updated successfully!"),
            backgroundColor: AppColors.success),
      );

      if (widget.onProfileUpdate != null) {
        widget.onProfileUpdate!();
      }

      if (widget.isEmbedded) {
        // Refresh local state to reflect new logo etc.
        setState(() {
          if (_newLogoUrl != null) {
            _existingLogoUrl = _newLogoUrl;
            _newLogoUrl = null;
          }
          // Clear local picked files so we show the network URL
          _selectedImage = null;
          _webImageBytes = null;
        });
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Failed to update profile: $e"),
            backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final bodyContent = _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: AppColors.primary))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLogoSection(),
                  const SizedBox(height: 32),
                  _buildSectionTitle("Personal Details"),
                  const SizedBox(height: 16),
                  CommonTextField(
                    controller: _userNameController,
                    label: "User Name",
                    prefixIcon: Icons.person,
                    hintText: "Enter your name",
                    validator: (v) =>
                        v!.isEmpty ? "This field is required" : null,
                  ),
                  const SizedBox(height: 16),
                  CommonTextField(
                    controller: _userEmailController,
                    label: "User Email",
                    prefixIcon: Icons.email,
                    hintText: "Enter your email",
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        v!.isEmpty ? "This field is required" : null,
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle("Shop Details"),
                  const SizedBox(height: 16),
                  CommonTextField(
                    controller: _shopNameController,
                    label: "Shop Name",
                    prefixIcon: Icons.store,
                    hintText: "Enter shop name",
                    validator: (v) =>
                        v!.isEmpty ? "This field is required" : null,
                  ),
                  const SizedBox(height: 16),
                  CommonTextField(
                    controller: _contactController,
                    label: "Contact Number",
                    prefixIcon: Icons.phone,
                    hintText: "Enter contact number",
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.isEmpty) return "This field is required";
                      if (v.length != 10) return "Enter valid 10-digit number";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  CommonTextField(
                    controller: _addressController,
                    label: "Address",
                    prefixIcon: Icons.location_on,
                    hintText: "Enter address",
                    maxLines: 2,
                    validator: (v) =>
                        v!.isEmpty ? "This field is required" : null,
                  ),
                  const SizedBox(height: 16),
                  CommonTextField(
                    controller: _gstController,
                    label: "GST/Tax Number",
                    prefixIcon: Icons.receipt_long,
                    hintText: "Enter GST number (optional)",
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle("Business Hours"),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text("Custom Business Day",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text(
                        "Group orders after midnight with the previous day"),
                    value: _isCustomBusinessDay,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() => _isCustomBusinessDay = val);
                    },
                  ),

                  if (_isCustomBusinessDay) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: CommonTextField(
                            controller: _openTimeController,
                            label: "Open Time",
                            prefixIcon: Icons.access_time,
                            readOnly: true,
                            onTap: () => _selectTime(_openTimeController),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CommonTextField(
                            controller: _closeTimeController,
                            label: "Close Time",
                            prefixIcon: Icons.access_time_filled,
                            readOnly: true,
                            onTap: () => _selectTime(_closeTimeController),
                          ),
                        ),
                      ],
                    ),
                  ],
                  SwitchListTile(
                    title: const Text("Show High Demand",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text(
                        "Show trending products today on order screen"),
                    value: _showHighDemand,
                    activeColor: AppColors.primary,
                    onChanged: (val) async {
                      setState(() => _showHighDemand = val);
                      try {
                        await _firestoreService.updateVendorDetails({'showHighDemand': val});
                      } catch (e) {
                        debugPrint("Error updating High Demand status: $e");
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildNavigationTile(
                    icon: Icons.people,
                    title: "Manage Staff Members",
                    subtitle: "Add or remove staff names for expenses",
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const StaffManagementScreen())),
                  ),
                  const SizedBox(height: 12),
                  _buildNavigationTile(
                    icon: Icons.receipt_long,
                    title: "Customize Bill",
                    subtitle: "Change logo, QR code, and footer text",
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CustomizeBillScreen())),
                  ),
                  const SizedBox(height: 12),
                  _buildNavigationTile(
                    icon: Icons.kitchen,
                    title: "Customize KOT",
                    subtitle: "Choose which info to show in the kitchen",
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CustomizeKOTScreen())),
                  ),
                  const SizedBox(height: 40),
                  SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Save Changes",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEmbedded ? "Admin - Shop Profile" : "Shop Profile",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: widget.isEmbedded
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              )
            : null,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      "Save",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: bodyContent,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    );
  }

  Widget _buildLogoSection() {
    Widget? imageWidget;

    if (kIsWeb && _webImageBytes != null) {
      imageWidget = Image.memory(_webImageBytes!, fit: BoxFit.cover);
    } else if (_selectedImage != null) {
      imageWidget = Image.file(_selectedImage!, fit: BoxFit.cover);
    } else if (_existingLogoUrl != null && _existingLogoUrl!.isNotEmpty) {
      imageWidget = Image.network(
        _existingLogoUrl!,
        key: ValueKey(_existingLogoUrl),
        fit: BoxFit.cover,
      );
    }

    return Center(
      child: Stack(
        children: [
          Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2), width: 2),
            ),
            child: ClipOval(
              child: _isUploadingLogo 
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : (imageWidget ?? const Icon(Icons.storefront, size: 64, color: AppColors.primary)),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _isUploadingLogo ? null : _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: _isUploadingLogo 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.camera_alt, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
