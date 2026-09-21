import 'dart:io';

import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../model/Category.dart' as model;
import '../../../model/Product.dart';
import '../../../services/FirestoreService.dart';
import '../../../utlity/AppColors.dart';
import '../../../widgets/CommonTextField.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({
    super.key,
    required this.title,
    this.productId,
    this.initialData,
  });

  final String title;
  final String? productId;
  final Map<String, dynamic>? initialData;

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _ProductOptionController {
  String id;
  final TextEditingController nameController;
  final TextEditingController priceController;

  _ProductOptionController({
    required this.id,
    String name = '',
    String price = '',
  })  : nameController = TextEditingController(text: name),
        priceController = TextEditingController(text: price);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': nameController.text.trim(),
      'price': double.tryParse(priceController.text.trim()) ?? 0,
    };
  }

  void dispose() {
    nameController.dispose();
    priceController.dispose();
  }
}

class _AddProductScreenState extends State<AddProductScreen> {
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _productDetailController =
      TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  final FirestoreService _firestoreService = FirestoreService();

  final List<File> _selectedImageFiles = [];
  final List<Uint8List> _selectedImageBytesList = [];
  final List<String> _uploadedImageUrls = [];
  List<String> _existingImageUrls = [];

  bool _isActive = false;
  bool _isSaving = false;
  bool _isEditing = false;

  // ============================================================
  // CATEGORY
  // ============================================================

  String? _selectedCategoryId;
  String? _selectedCategoryName;
  List<model.Category> _categories = [];
  bool _isLoadingCategories = false;

  // ============================================================
  // PRODUCT OPTIONS / VARIANTS
  // ============================================================

  final List<_ProductOptionController> _options = [];

  // ============================================================
  // COMBO ITEMS
  // ============================================================

  final List<ComboItem> _comboItems = [];
  List<Product> _availableProducts = [];

  final picker = ImagePicker();
  final cloudinary = CloudinaryPublic(
    'dei574s6o',
    'BulkBites',
    cache: false,
  );

  @override
  void initState() {
    super.initState();
    _isEditing = widget.productId != null;
    _loadCategories();

    if (_isEditing && widget.initialData != null) {
      _loadInitialData();
    }
  }

  // ============================================================
  // LOAD INITIAL PRODUCT
  // ============================================================

  void _loadInitialData() {
    final data = widget.initialData!;

    _productNameController.text = data['productName']?.toString() ?? '';
    _productDetailController.text = data['productDetail']?.toString() ?? '';
    _priceController.text = data['price']?.toString() ?? '';
    _existingImageUrls = List<String>.from(data['images'] ?? []);
    _isActive = data['active'] ?? false;

    // Check if it's a combo
    final comboItems = data['comboItems'];
    if (comboItems != null && comboItems is List) {
      _comboItems.addAll(
        comboItems.map((item) => ComboItem.fromMap(item)).toList(),
      );
    }

    // Category
    _selectedCategoryId = data['categoryId']?.toString();
    _selectedCategoryName = data['categoryName']?.toString();

    // Options
    final options = data['options'];
    if (options is List) {
      for (final option in options) {
        if (option is Map) {
          _options.add(
            _ProductOptionController(
              id: option['id']?.toString() ??
                  DateTime.now().microsecondsSinceEpoch.toString(),
              name: option['name']?.toString() ?? '',
              price: option['price']?.toString() ?? '',
            ),
          );
        }
      }
    }
    // Load available products for combo editing
    if (_comboItems.isNotEmpty) {
      _loadAvailableProducts();
    }
  }

  // ============================================================
  // LOAD CATEGORIES
  // ============================================================

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final loadedCategories = await _firestoreService.getCategories();

      setState(() {
        _categories = loadedCategories;

        if (_selectedCategoryId != null) {
          for (final category in _categories) {
            if (category.id == _selectedCategoryId) {
              _selectedCategoryName = category.name;
              break;
            }
          }
        }
      });
    } catch (e) {
      debugPrint('Failed to load categories: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  // ============================================================
  // LOAD AVAILABLE PRODUCTS FOR COMBO
  // ============================================================

  Future<void> _loadAvailableProducts() async {
    try {
      final products = await _firestoreService.getActiveProducts();

      setState(() {
        // Filter out combo products themselves to avoid recursion
        _availableProducts = products.where((p) => p.isCombo != true).toList();
      });
    } catch (e) {
      debugPrint('Failed to load products: $e');
    }
  }

  // ============================================================
  // PICK IMAGES
  // ============================================================

  Future<void> _pickImages() async {
    final pickedFiles = await picker.pickMultiImage();

    if (pickedFiles.isEmpty) return;

    if (kIsWeb) {
      for (final file in pickedFiles) {
        final bytes = await file.readAsBytes();
        _selectedImageBytesList.add(bytes);
      }
    } else {
      for (final file in pickedFiles) {
        _selectedImageFiles.add(File(file.path));
      }
    }

    setState(() {});
  }

  void _removeImage(int index) {
    setState(() {
      if (kIsWeb) {
        _selectedImageBytesList.removeAt(index);
      } else {
        _selectedImageFiles.removeAt(index);
      }
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  // ============================================================
  // PRODUCT OPTIONS
  // ============================================================

  void _addOption() {
    setState(() {
      _options.add(
        _ProductOptionController(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
        ),
      );
    });
  }

  void _removeOption(int index) {
    setState(() {
      _options[index].dispose();
      _options.removeAt(index);
    });
  }

  // ============================================================
  // COMBO MANAGEMENT
  // ============================================================

  Future<void> _showAddComboItemDialog() async {
    if (_availableProducts.isEmpty) {
      await _loadAvailableProducts();
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ComboItemPickerDialog(
        availableProducts: _availableProducts,
        onAddItems: (List<ComboItem> items) {
          setState(() {
            _comboItems.addAll(items);
          });
        },
      ),
    );
  }

  void _removeComboItem(int index) {
    setState(() {
      _comboItems.removeAt(index);
    });
  }
  // ============================================================
  // UPLOAD IMAGES
  // ============================================================

  Future<void> _uploadImages() async {
    _uploadedImageUrls.clear();

    if (kIsWeb && _selectedImageBytesList.isNotEmpty) {
      for (var i = 0; i < _selectedImageBytesList.length; i++) {
        final response = await cloudinary.uploadFile(
          CloudinaryFile.fromBytesData(
            _selectedImageBytesList[i],
            identifier: 'upload_$i',
            resourceType: CloudinaryResourceType.Image,
          ),
        );
        _uploadedImageUrls.add(response.secureUrl);
      }
    } else if (_selectedImageFiles.isNotEmpty) {
      for (var file in _selectedImageFiles) {
        final response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            file.path,
            resourceType: CloudinaryResourceType.Image,
          ),
        );
        _uploadedImageUrls.add(response.secureUrl);
      }
    }
  }
  // ============================================================
  // VALIDATION
  // ============================================================

  bool _validateForm() {
    if (_productNameController.text.trim().isEmpty) {
      _showError('Please enter product name');
      return false;
    }

    if (_selectedCategoryId == null) {
      _showError('Please select a category');
      return false;
    }

    if (_comboItems.isNotEmpty) {
      // It's a combo
      if (_priceController.text.trim().isEmpty ||
          double.tryParse(_priceController.text.trim()) == null) {
        _showError('Please enter combo price');
        return false;
      }
    } else {
      if (_options.isEmpty &&
          (_priceController.text.trim().isEmpty ||
              double.tryParse(_priceController.text.trim()) == null)) {
        _showError('Please enter product price');
        return false;
      }

      // Validate options
      for (final option in _options) {
        if (option.nameController.text.trim().isEmpty) {
          _showError('Please enter option name');
          return false;
        }
        if (double.tryParse(option.priceController.text.trim()) == null) {
          _showError(
              'Please enter valid price for ${option.nameController.text}');
          return false;
        }
      }
    }

    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // SAVE FIRESTORE
  // ============================================================

  Future<void> _saveToFirestore() async {
    if (_isSaving) return;
    if (!_validateForm()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _uploadImages();

      final allImageUrls = [
        ..._existingImageUrls,
        ..._uploadedImageUrls,
      ];

      // Prepare product data based on type
      Map<String, dynamic> productData = {};

      if (_comboItems.isNotEmpty) {
        // COMBO PRODUCT
        final manualPrice = double.tryParse(_priceController.text.trim()) ?? 0;

        productData = {
          'productName': _productNameController.text.trim(),
          'productDetail': _productDetailController.text.trim(),
          'categoryId': _selectedCategoryId,
          'categoryName': _selectedCategoryName,
          'price': manualPrice,
          'images': allImageUrls,
          'active': _isActive,
          'comboItems': _comboItems.map((item) => item.toMap()).toList(),
          'isCombo': true,
          'comboTotalPrice': manualPrice,
        };
      } else {
        // REGULAR PRODUCT
        final options = _options.map((option) => option.toMap()).toList();
        double basePrice = double.tryParse(_priceController.text.trim()) ?? 0;

        if (_options.isNotEmpty) {
          basePrice =
              double.tryParse(_options.first.priceController.text.trim()) ?? 0;
        }

        productData = {
          'productName': _productNameController.text.trim(),
          'productDetail': _productDetailController.text.trim(),
          'categoryId': _selectedCategoryId,
          'categoryName': _selectedCategoryName,
          'price': basePrice,
          'options': options,
          'images': allImageUrls,
          'active': _isActive,
          'isCombo': false,
        };
      }

      if (_isEditing) {
        await _firestoreService.updateProduct(widget.productId!, productData);
      } else {
        await _firestoreService.addProduct(productData);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Product updated successfully!'
                : 'Product saved successfully!',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() {
        _isSaving = false;
      });

      if (_isEditing) {
        Navigator.pop(context);
      } else {
        _clearForm();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // CLEAR FORM
  // ============================================================

  void _clearForm() {
    _productNameController.clear();
    _productDetailController.clear();
    _priceController.clear();
    _comboItems.clear();

    for (final option in _options) {
      option.dispose();
    }

    setState(() {
      _selectedCategoryId = null;
      _selectedCategoryName = null;
      _options.clear();
      _selectedImageFiles.clear();
      _selectedImageBytesList.clear();
      _uploadedImageUrls.clear();
      _existingImageUrls.clear();
      _isActive = false;
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _productNameController.dispose();
    _productDetailController.dispose();
    _priceController.dispose();

    for (final option in _options) {
      option.dispose();
    }

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    List<Widget> imagePreviews = [];

    // Existing images
    final existingImagePreviews =
        List.generate(_existingImageUrls.length, (index) {
      return _buildImagePreview(
        child: Image.network(
          _existingImageUrls[index],
          height: 100,
          width: 100,
          fit: BoxFit.cover,
        ),
        onRemove: () => _removeExistingImage(index),
      );
    });

    // New images
    if (kIsWeb && _selectedImageBytesList.isNotEmpty) {
      imagePreviews.addAll(
        List.generate(
          _selectedImageBytesList.length,
          (index) {
            return _buildImagePreview(
              child: Image.memory(
                _selectedImageBytesList[index],
                height: 100,
                width: 100,
                fit: BoxFit.cover,
              ),
              onRemove: () => _removeImage(index),
            );
          },
        ),
      );
    } else if (_selectedImageFiles.isNotEmpty) {
      imagePreviews.addAll(
        List.generate(
          _selectedImageFiles.length,
          (index) {
            return _buildImagePreview(
              child: Image.file(
                _selectedImageFiles[index],
                height: 100,
                width: 100,
                fit: BoxFit.cover,
              ),
              onRemove: () => _removeImage(index),
            );
          },
        ),
      );
    }

    final allImagePreviews = [
      ...existingImagePreviews,
      ...imagePreviews,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.05),
              AppColors.backgroundColor,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==================================================
                // BASIC INFORMATION
                // ==================================================
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    decoration: BoxDecoration(
                      color: AppColors.cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Edit Product' : 'Add New Product',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // PRODUCT NAME
                        CommonTextField(
                          controller: _productNameController,
                          label: 'Product Name',
                          hintText: 'e.g. Cheese Burger',
                        ),
                        const SizedBox(height: 16),
                        // CATEGORY
                        _buildCategoryDropdown(),
                        const SizedBox(height: 16),
                        if (_selectedCategoryName?.toLowerCase() == 'combos')
                        // COMBO ITEMS SELECTION
                        _buildComboSelectionField(),
                        const SizedBox(height: 16),
                        // DETAILS
                        CommonTextField(
                          controller: _productDetailController,
                          label: 'Product Details',
                          maxLines: 3,
                          hintText: 'Describe your product...',
                        ),
                        const SizedBox(height: 16),
                        if (_options.isEmpty)
                          CommonTextField(
                            controller: _priceController,
                            label: 'Price',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            hintText: '0.00',
                          ),
                        const SizedBox(height: 16),
                        // ACTIVE
                        Row(
                          children: [
                            Text(
                              'Available',
                              style: TextStyle(
                                color: AppColors.textColor,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            Switch(
                              activeThumbColor: AppColors.primary,
                              value: _isActive,
                              onChanged: (value) {
                                setState(() {
                                  _isActive = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // ==================================================
                // PRODUCT OPTIONS
                // ==================================================

                if (_comboItems.isEmpty)
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Product Options',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Add sizes, variants or other choices',
                                      style: TextStyle(
                                        color: AppColors.textColor
                                            .withValues(alpha: 0.6),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _addOption,
                                icon: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Add Option',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_options.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'No options added.\nThe product will use the main price.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textColor.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ...List.generate(
                            _options.length,
                            (index) {
                              return _buildOptionRow(index);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 10),

                // ==================================================
                // IMAGES
                // ==================================================

                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product Images',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add or remove images of your product',
                          style: TextStyle(
                            color: AppColors.textColor.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (allImagePreviews.isNotEmpty)
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: allImagePreviews,
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Icon(
                                  Icons.image,
                                  size: 50,
                                  color: AppColors.textColor.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No images selected',
                                  style: TextStyle(
                                    color: AppColors.textColor.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _pickImages,
                          icon: const Icon(
                            Icons.add_photo_alternate,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Add More Images',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // SAVE
                // ==================================================

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveToFirestore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            _isEditing ? 'Update Product' : 'Save Product',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // COMBO SELECTION FIELD
  // ============================================================

  Widget _buildComboSelectionField() {
    return Column(
      children: [
        InkWell(
          onTap: _showAddComboItemDialog,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _comboItems.isEmpty
                        ? 'Select Combo Items (Optional)'
                        : '${_comboItems.length} items selected in combo',
                    style: TextStyle(
                      color: _comboItems.isEmpty
                          ? AppColors.textColor.withValues(alpha: 0.5)
                          : AppColors.textColor,
                    ),
                  ),
                ),
                Icon(
                  Icons.add_shopping_cart,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),

        // ==================================================
        // COMBO ITEMS
        // ==================================================

        if (_comboItems.isNotEmpty)
          Container(
            padding: const EdgeInsets.only(top: 10),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Combo Items',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Items added to this combo',
                            style: TextStyle(
                              color: AppColors.textColor
                                  .withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showAddComboItemDialog,
                      icon: const Icon(
                        Icons.add,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Add More',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...List.generate(
                  _comboItems.length,
                      (index) {
                    return _buildComboItemRow(index);
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ============================================================
  // CATEGORY DROPDOWN
  // ============================================================

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategoryId,
      decoration: InputDecoration(
        labelText: 'Category',
        labelStyle: TextStyle(
          color: AppColors.primary,
        ),
        filled: true,
        fillColor: AppColors.backgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:  BorderSide(
            color: AppColors.textColor.withValues(alpha: 0.1),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.textColor.withValues(alpha: 0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1,
          ),
        ),

      ),
      hint: _isLoadingCategories
          ? const Text('Loading categories...')
          : const Text('Select category'),
      items: _categories.map((category) {
        return DropdownMenuItem<String>(
          value: category.id,
          child: Text(
            category.name,
          ),
        );
      }).toList(),
      onChanged: _isLoadingCategories
          ? null
          : (value) {
              if (value == null) return;
              final category = _categories.firstWhere(
                (item) => item.id == value,
              );
              setState(() {
                _selectedCategoryId = value;
                _selectedCategoryName = category.name;
                // Clean up combo data when category changes
                _comboItems.clear();
              });
            },
    );
  }

  // ============================================================
  // COMBO ITEM ROW
  // ============================================================

  Widget _buildComboItemRow(int index) {
    final item = _comboItems[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          // Quantity Selector
          _buildQuantitySelector(
            quantity: item.quantity,
            onChanged: (newQty) {
              setState(() {
                _comboItems[index] = ComboItem(
                  productId: item.productId,
                  productName: item.productName,
                  price: item.price,
                  optionId: item.optionId,
                  optionName: item.optionName,
                  quantity: newQty,
                );
              });
            },
          ),
          const SizedBox(width: 12),
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textColor,
                  ),
                ),
                if (item.optionName != null && item.optionName!.isNotEmpty)
                  Text(
                    'Option: ${item.optionName}',
                    style: TextStyle(
                      color: AppColors.textColor.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                Text(
                  '₹ ${item.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Remove button
          IconButton(
            onPressed: () => _removeComboItem(index),
            icon: Icon(
              Icons.delete_outline,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector({
    required int quantity,
    required Function(int) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(Icons.remove, size: 16, color: AppColors.primary),
            onPressed: () {
              if (quantity > 1) onChanged(quantity - 1);
            },
          ),
          Text(
            quantity.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(Icons.add, size: 16, color: AppColors.primary),
            onPressed: () => onChanged(quantity + 1),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // OPTION ROW
  // ============================================================

  Widget _buildOptionRow(int index) {
    final option = _options[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: CommonTextField(
              controller: option.nameController,
              label: 'Option',
              hintText: 'e.g. Small',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: CommonTextField(
              controller: option.priceController,
              label: 'Price',
              hintText: '0.00',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),

          Container(
            width: 30,
            child: IconButton(
              onPressed: () => _removeOption(index),
              icon: Icon(
                Icons.delete_outline,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================
}

  // ============================================================
  // IMAGE PREVIEW
  // ============================================================

  Widget _buildImagePreview({
    required Widget child,
    required VoidCallback onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: child,
          ),
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


// ============================================================
// COMBO ITEM PICKER DIALOG
// ============================================================

class _ComboItemPickerDialog extends StatefulWidget {
  final List<Product> availableProducts;
  final Function(List<ComboItem>) onAddItems;

  const _ComboItemPickerDialog({
    required this.availableProducts,
    required this.onAddItems,
  });

  @override
  State<_ComboItemPickerDialog> createState() => _ComboItemPickerDialogState();
}

class _ComboItemPickerDialogState extends State<_ComboItemPickerDialog> {
  final Set<String> _selectedProductIds = {};
  List<Product> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _filteredProducts = widget.availableProducts;
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = widget.availableProducts;
      } else {
        _filteredProducts = widget.availableProducts.where((product) {
          final name = product.productName.toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  'Select Products for Combo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),
          // Search
          CommonTextField(
            label: 'Search Products',
            hintText: 'Search products...',
            prefixIcon: Icons.search,
            onChanged: _filterProducts,
          ),
          const SizedBox(height: 16),
          // Product selection
          Expanded(
            child: _filteredProducts.isEmpty
                ? Center(
                    child: Text(
                      'No products available',
                      style: TextStyle(
                        color: AppColors.textColor.withOpacity(0.5),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      final productId = product.id;
                      final isSelected = _selectedProductIds.contains(productId);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedProductIds.remove(productId);
                            } else {
                              _selectedProductIds.add(productId);
                            }
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : AppColors.backgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textColor.withValues(alpha: 0.1),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Checkbox / Icon
                              Icon(
                                isSelected
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textColor.withValues(alpha: 0.3),
                              ),
                              const SizedBox(width: 12),
                              // Product image
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: AppColors.cardColor,
                                  image: DecorationImage(
                                    image: NetworkImage(
                                      product.images.isNotEmpty
                                          ? product.images[0]
                                          : 'https://via.placeholder.com/50',
                                    ),
                                    fit: BoxFit.cover,
                                    onError: (_, __) {},
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.productName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textColor,
                                      ),
                                    ),
                                    Text(
                                      '₹ ${product.price.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          // Add button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedProductIds.isEmpty
                  ? null
                  : () {
                      final List<ComboItem> itemsToAdd = [];
                      for (final id in _selectedProductIds) {
                        final product = widget.availableProducts
                            .firstWhere((p) => p.id == id);
                        itemsToAdd.add(ComboItem(
                          productId: id,
                          productName: product.productName,
                          price: product.price,
                          quantity: 1,
                        ));
                      }
                      widget.onAddItems(itemsToAdd);
                      Navigator.pop(context);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _selectedProductIds.isEmpty
                    ? 'Select Items'
                    : 'Add Selected (${_selectedProductIds.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

