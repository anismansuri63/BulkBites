import 'package:flutter/material.dart';

import '../../../model/Category.dart';
import '../../../services/FirestoreService.dart';
import '../../../utlity/AppColors.dart';
import 'AddCategoryScreen.dart';

class CategoryListScreen extends StatefulWidget {
  final bool isEmbedded;
  const CategoryListScreen({
    super.key,
    this.isEmbedded = false,
  });
  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late Stream<List<Category>> _categoriesStream;

  @override
  void initState() {
    super.initState();
    _categoriesStream = _firestoreService.getCategoriesStream();
  }

  // ============================================================
  // DELETE / DEACTIVATE
  // ============================================================

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final categoryId = category['id']?.toString();

    if (categoryId == null || categoryId.isEmpty) {
      _showMessage('Invalid category', isError: true);
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: AppColors.cardColor,
          title: const Text(
            'Delete Category',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textColor,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${category['name']}"?',
            style: TextStyle(color: AppColors.textColor.withValues(alpha: 0.7)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textColor),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await _firestoreService.deleteCategory(categoryId);
      if (!mounted) return;
      _showMessage('Category deleted successfully');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed to delete category: $e', isError: true);
    }
  }

  Future<void> _toggleCategory(Map<String, dynamic> category) async {
    final categoryId = category['id']?.toString();
    if (categoryId == null) return;

    try {
      await _firestoreService.toggleCategoryStatus(categoryId);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed to update category: $e', isError: true);
    }
  }

  // ============================================================
  // EDIT / ADD
  // ============================================================

  Future<void> _editCategory(Map<String, dynamic> category) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddCategoryScreen(category: category),
      ),
    );
  }

  Future<void> _addCategory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddCategoryScreen(),
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final content = Container(
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
      child: StreamBuilder<List<Category>>(
        stream: _categoriesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final categories = snapshot.data ?? [];

          if (categories.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.only(
              top: 16,
              left: 16,
              right: 16,
              bottom: 80,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];

              return _buildCategoryCard(
                category.toMap(),
                key: ValueKey('cat_${category.id}'),
              );
            },
          );
        },
      ),
    );

    if (widget.isEmbedded) {
      return Scaffold(
        body: content,
        floatingActionButton: FloatingActionButton(
          foregroundColor: AppColors.cardColor,
          backgroundColor: AppColors.primary,
          onPressed: _addCategory,
          child: const Icon(Icons.add),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Categories',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        foregroundColor: AppColors.cardColor,
        backgroundColor: AppColors.primary,
        onPressed: _addCategory,
        child: const Icon(Icons.add),
      ),
      body: content,
    );
  }

  // ============================================================
  // CATEGORY CARD
  // ============================================================

  Widget _buildCategoryCard(
    Map<String, dynamic> category, {
    Key? key,
  }) {
    final name = category['name']?.toString() ?? '';
    final active = category['active'] ?? true;
    final sortOrder = category['sortOrder']?.toString() ?? '';

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active
              ? AppColors.textColor.withValues(alpha: 0.08)
              : AppColors.textColor.withValues(alpha: 0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // ==================== TOP CONTENT ====================
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // CATEGORY ICON
                  Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.category_outlined,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),

                  const SizedBox(width: 14),

                  // NAME & ORDER
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: active
                                ? AppColors.textColor
                                : AppColors.textColor.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Order: $sortOrder',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textColor.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Divider
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.textColor.withValues(alpha: 0.06),
            ),

            // ==================== BOTTOM ACTIONS ====================
            Container(
              color: AppColors.backgroundColor.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Available Switch
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Available",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? AppColors.textColor.withValues(alpha: 0.85)
                              : AppColors.textColor.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        height: 28,
                        child: Transform.scale(
                          scale: 0.75,
                          child: Switch(
                            value: active,
                            activeThumbColor: AppColors.primary,
                            activeTrackColor:
                                AppColors.primary.withValues(alpha: 0.35),
                            onChanged: (bool value) {
                              _toggleCategory(category);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit Button
                      InkWell(
                        onTap: () => _editCategory(category),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.edit_outlined,
                                size: 15,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Edit",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Delete Button
                      InkWell(
                        onTap: () => _deleteCategory(category),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.delete_outline,
                                size: 15,
                                color: AppColors.error,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Delete",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 70,
              color: AppColors.textColor.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            Text(
              'No categories yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create categories like Burgers, Fries, Drinks, etc.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _addCategory,
              icon: const Icon(
                Icons.add,
                color: Colors.white,
              ),
              label: const Text(
                'Add Category',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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
    );
  }
}
