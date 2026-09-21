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
      _showMessage('Please enter category name', isError: true);
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

      _showMessage('Error: $e', isError: true);
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================
              // HEADER CARD WITH ICON
              // ==================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.textColor.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.category_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing ? 'Edit Category' : 'New Category',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isEditing
                                ? 'Update the details for this category'
                                : 'Add a new category to organize your menu',
                            style: TextStyle(
                              color: AppColors.textColor.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // FORM CARD
              // ==================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.textColor.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CATEGORY NAME
                    CommonTextField(
                      controller: _nameController,
                      label: 'Category Name',
                      hintText: 'e.g. Burgers, Beverages, Desserts',
                    ),

                    const SizedBox(height: 18),

                    // SORT ORDER
                    CommonTextField(
                      controller: _sortOrderController,
                      label: 'Display Order',
                      hintText: 'e.g. 1',
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 20),

                    Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.textColor.withValues(alpha: 0.06),
                    ),

                    const SizedBox(height: 16),

                    // AVAILABILITY SWITCH TILE
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isActive ? Colors.green : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Available',
                                style: TextStyle(
                                  color: AppColors.textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _isActive
                                    ? 'Visible on vendor & customer menus'
                                    : 'Hidden from menu',
                                style: TextStyle(
                                  color: AppColors.textColor.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isActive,
                          activeThumbColor: AppColors.primary,
                          activeTrackColor: AppColors.primary.withValues(alpha: 0.35),
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

              const SizedBox(height: 28),

              // ==================================================
              // SAVE BUTTON
              // ==================================================

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveCategory,
                  icon: _isSaving
                      ? const SizedBox.shrink()
                      : Icon(
                          _isEditing
                              ? Icons.check_circle_outline_rounded
                              : Icons.add_circle_outline_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                  label: _isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
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
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                    shadowColor: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}