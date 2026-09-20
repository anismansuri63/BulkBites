import 'package:flutter/material.dart';

import '../../../services/FirestoreService.dart';
import '../../../utlity/AppColors.dart';
import '../../../widgets/CommonTextField.dart';

class AddCategoryScreen extends StatefulWidget {
  const AddCategoryScreen({
    super.key,
    this.category,
  });

  // If category is provided -> Edit mode
  // If null -> Add mode
  final Map<String, dynamic>? category;

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _sortOrderController = TextEditingController();

  bool _isActive = true;
  bool _isSaving = false;

  bool get _isEditing => widget.category != null;

  String? _categoryId;

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      final category = widget.category!;

      _categoryId = category['id']?.toString();

      _nameController.text = category['name']?.toString() ?? '';

      _sortOrderController.text = category['sortOrder']?.toString() ?? '1';

      _isActive = category['active'] ?? true;
    } else {
      _sortOrderController.text = '1';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sortOrderController.dispose();

    super.dispose();
  }

  // ============================================================
  // SAVE CATEGORY
  // ============================================================

  Future<void> _saveCategory() async {
    if (_isSaving) return;

    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _showMessage(
        'Please enter category name',
        isError: true,
      );
      return;
    }

    final sortOrder = int.tryParse(_sortOrderController.text.trim()) ?? 1;

    setState(() {
      _isSaving = true;
    });

    try {
      final categoryData = {
        'name': name,
        'active': _isActive,
        'sortOrder': sortOrder,
      };

      if (_isEditing) {
        await _firestoreService.updateCategory(_categoryId!, categoryData);
      } else {
        await _firestoreService.addCategory(categoryData);
      }

      if (!mounted) return;

      _showMessage(
        _isEditing
            ? 'Category updated successfully!'
            : 'Category added successfully!',
      );

      // Return to category list
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Error: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Category' : 'Add Category',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
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
                // CATEGORY FORM
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
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.cardColor,
                          AppColors.cardColor.withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Edit Category' : 'Add New Category',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          _isEditing
                              ? 'Update the category details below'
                              : 'Fill in the details below to add a new category',
                          style: TextStyle(
                            color: AppColors.textColor.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // CATEGORY NAME
                        CommonTextField(
                          controller: _nameController,
                          label: 'Category Name',
                          hintText: 'e.g. Burgers',
                        ),

                        const SizedBox(height: 16),

                        // SORT ORDER
                        CommonTextField(
                          controller: _sortOrderController,
                          label: 'Display Order',
                          hintText: 'e.g. 1',
                          keyboardType: TextInputType.number,
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

                const SizedBox(height: 20),

                // ==================================================
                // SAVE BUTTON
                // ==================================================

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveCategory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary2,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          12,
                        ),
                      ),
                      elevation: 2,
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
                            _isEditing ? 'Update Category' : 'Save Category',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
