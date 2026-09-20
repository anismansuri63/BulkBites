import 'package:flutter/material.dart';

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

  List<Map<String, dynamic>> _categories = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _loadCategories();
  }

  // ============================================================
  // LOAD CATEGORIES
  // ============================================================

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final loadedCategories = await _firestoreService.getCategories();

      // Sort by display order
      loadedCategories.sort(
        (a, b) => a.sortOrder.compareTo(b.sortOrder),
      );

      if (!mounted) return;

      setState(() {
        _categories = loadedCategories.map((c) => c.toMap()).toList();
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Failed to load categories: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // DELETE / DEACTIVATE
  // ============================================================

  Future<void> _deleteCategory(
    Map<String, dynamic> category,
  ) async {
    final categoryId = category['id']?.toString();

    if (categoryId == null || categoryId.isEmpty) {
      _showMessage(
        'Invalid category',
        isError: true,
      );
      return;
    }

    // Confirm before deleting
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
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textColor),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _firestoreService.deleteCategory(categoryId);

      if (!mounted) return;

      _showMessage(
        'Category deleted successfully',
      );

      // Refresh list
      await _loadCategories();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Failed to delete category: $e',
        isError: true,
      );
    }
  }

  Future<void> _toggleCategory(
    Map<String, dynamic> category,
  ) async {
    final categoryId = category['id']?.toString();

    if (categoryId == null) return;

    try {
      await _firestoreService.toggleCategoryStatus(categoryId);

      await _loadCategories();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Failed to update category: $e',
        isError: true,
      );
    }
  }

  // ============================================================
  // EDIT
  // ============================================================

  Future<void> _editCategory(Map<String, dynamic> category,) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddCategoryScreen(
          category: category,
        ),
      ),
    );

    if (result == true) {
      _loadCategories();
    }
  }

  // ============================================================
  // ADD
  // ============================================================

  Future<void> _addCategory() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddCategoryScreen(),
      ),
    );

    if (result == true) {
      _loadCategories();
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
      child: _isLoading
          ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
          : _categories.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _loadCategories,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];

                        return _buildCategoryCard(
                          category,
                        );
                      },
                    ),
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
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        actions: [
          IconButton(
            onPressed: _loadCategories,
            icon: const Icon(
              Icons.refresh,
              color: Colors.white,
            ),
          ),
        ],
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
  // OPTIONS BOTTOM SHEET
  // ============================================================

  void _showCategoryOptions(Map<String, dynamic> category) {
    final active = category['active'] ?? true;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            Text(
              category['name']?.toString() ?? 'Category Options',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 20),
            
            _buildOptionTile(
              icon: Icons.edit_outlined,
              title: "Edit Category",
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                _editCategory(category);
              },
            ),

            _buildOptionTile(
              icon: active ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              title: active ? "Deactivate Category" : "Activate Category",
              color: active ? Colors.orange : Colors.green,
              onTap: () {
                Navigator.pop(context);
                _toggleCategory(category);
              },
            ),

            _buildOptionTile(
              icon: Icons.delete_outline,
              title: "Delete Category",
              color: AppColors.error,
              onTap: () {
                Navigator.pop(context);
                _deleteCategory(category);
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textColor),
      ),
      onTap: onTap,
    );
  }

  // ============================================================
  // CATEGORY CARD
  // ============================================================

  Widget _buildCategoryCard(
    Map<String, dynamic> category,
  ) {
    final name = category['name']?.toString() ?? '';

    final active = category['active'] ?? true;

    final sortOrder = category['sortOrder']?.toString() ?? '';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          16,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(
          16,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(
            16,
          ),
        ),
        child: Row(
          children: [
            // CATEGORY ICON
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(
                  12,
                ),
              ),
              child: Icon(
                Icons.category_outlined,
                color: AppColors.primary,
                size: 26,
              ),
            ),

            const SizedBox(width: 14),

            // NAME
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textColor,
                    ),
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  Text(
                    'Order: $sortOrder',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),

            // ACTIVE STATUS
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(
                  20,
                ),
              ),
              child: Text(
                active ? 'Active' : 'Inactive',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.success : AppColors.error,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.more_vert,
                color: AppColors.textColor.withOpacity(0.6),
              ),
              onPressed: () => _showCategoryOptions(category),
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
        padding: const EdgeInsets.all(
          30,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 70,
              color: AppColors.textColor.withValues(alpha: 0.25),
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              'No categories yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textColor,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              'Create categories like Burgers, Fries, Drinks, etc.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            ElevatedButton.icon(
              onPressed: _addCategory,
              icon: const Icon(
                Icons.add,
                color: Colors.white,
              ),
              label: const Text(
                'Add Category',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
