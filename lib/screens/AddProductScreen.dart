import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../utlity/AppColors.dart';
class AddProductScreen extends StatefulWidget {
  const AddProductScreen({
    super.key,
    required this.title,
    this.productId, // For editing existing products
    this.initialData, // For pre-filling form data
  });

  final String title;
  final String? productId;
  final Map<String, dynamic>? initialData;

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _productDetailController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<File> _selectedImageFiles = [];
  final List<Uint8List> _selectedImageBytesList = [];
  final List<String> _uploadedImageUrls = [];
  List<String> _existingImageUrls = []; // For storing existing image URLs

  final picker = ImagePicker();
  final cloudinary = CloudinaryPublic(
    'dei574s6o',
    'BulkBites',
    cache: false,
  );
  bool _isSaving = false;
  bool _isEditing = false; // Flag to check if we're editing

  @override
  void initState() {
    super.initState();
    _isEditing = widget.productId != null;

    // Pre-fill form if we're editing an existing product
    if (_isEditing && widget.initialData != null) {
      _productNameController.text = widget.initialData!['productName'] ?? '';
      _productDetailController.text = widget.initialData!['productDetail'] ?? '';
      _priceController.text = widget.initialData!['price']?.toString() ?? '';
      _existingImageUrls = List<String>.from(widget.initialData!['images'] ?? []);
    }
  }


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

  Future<void> _saveToFirestore() async {
    if (_isSaving) return;

    // Check if we have at least one image (either existing or new)
    final hasNoImages = (kIsWeb && _selectedImageBytesList.isEmpty) ||
        (!kIsWeb && _selectedImageFiles.isEmpty);

    if (hasNoImages && _existingImageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please select at least one image"),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Upload new images if any
      await _uploadImages();

      // Combine existing and new image URLs
      final allImageUrls = [..._existingImageUrls, ..._uploadedImageUrls];

      if (_isEditing) {
        // Update existing product
        await _firestore.collection("products").doc(widget.productId).update({
          "productName": _productNameController.text.trim(),
          "productDetail": _productDetailController.text.trim(),
          "price": double.tryParse(_priceController.text.trim()) ?? 0,
          "images": allImageUrls,
          "updatedAt": FieldValue.serverTimestamp(),
        });
      } else {
        // Create new product
        await _firestore.collection("products").add({
          "productName": _productNameController.text.trim(),
          "productDetail": _productDetailController.text.trim(),
          "price": double.tryParse(_priceController.text.trim()) ?? 0,
          "images": allImageUrls,
          "createdAt": FieldValue.serverTimestamp(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? "Product updated successfully! ✅" : "Product saved successfully! ✅"),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      // Clear form only if it's a new product
      if (!_isEditing) {
        _productNameController.clear();
        _productDetailController.clear();
        _priceController.clear();
        setState(() {
          _selectedImageFiles.clear();
          _selectedImageBytesList.clear();
          _uploadedImageUrls.clear();
          _existingImageUrls.clear();
        });
      }

      setState(() {
        _isSaving = false;
      });

      // If editing, go back to previous screen
      if (_isEditing) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> imagePreviews = [];

    // Add existing images first
    List<Widget> existingImagePreviews = List.generate(_existingImageUrls.length, (index) {
      return Container(
        margin: EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(_existingImageUrls[index],
                  height: 100, width: 100, fit: BoxFit.cover),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: GestureDetector(
                onTap: () => _removeExistingImage(index),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      )
                    ],
                  ),
                  child: Icon(Icons.close, size: 18, color: AppColors.error),
                ),
              ),
            ),
          ],
        ),
      );
    });

    // Add new image previews
    if (kIsWeb && _selectedImageBytesList.isNotEmpty) {
      imagePreviews.addAll(List.generate(_selectedImageBytesList.length, (index) {
        return Container(
          margin: EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              )
            ],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_selectedImageBytesList[index],
                    height: 100, width: 100, fit: BoxFit.cover),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: GestureDetector(
                  onTap: () => _removeImage(index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    child: Icon(Icons.close, size: 18, color: AppColors.error),
                  ),
                ),
              ),
            ],
          ),
        );
      }));
    } else if (_selectedImageFiles.isNotEmpty) {
      imagePreviews.addAll(List.generate(_selectedImageFiles.length, (index) {
        return Container(
          margin: EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              )
            ],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_selectedImageFiles[index],
                    height: 100, width: 100, fit: BoxFit.cover),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: GestureDetector(
                  onTap: () => _removeImage(index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    child: Icon(Icons.close, size: 18, color: AppColors.error),
                  ),
                ),
              ),
            ],
          ),
        );
      }));
    }

    // Combine existing and new image previews
    final allImagePreviews = [...existingImagePreviews, ...imagePreviews];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: AppColors.backgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.cardColor, AppColors.cardColor.withOpacity(0.9)],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_isEditing ? "Edit Product" : "Add New Product",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            )
                        ),
                        SizedBox(height: 8),
                        Text(_isEditing ?
                        "Update the product details below" :
                        "Fill in the details below to add a new product",
                            style: TextStyle(
                              color: AppColors.textColor.withOpacity(0.7),
                              fontSize: 14,
                            )
                        ),
                        SizedBox(height: 20),
                        TextField(
                          controller: _productNameController,
                          decoration: InputDecoration(
                            labelText: "Product Name",
                            labelStyle: TextStyle(color: AppColors.textColor),
                            filled: true,
                            fillColor: AppColors.backgroundColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.primary, width: 2),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          style: TextStyle(color: AppColors.textColor),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: _productDetailController,
                          decoration: InputDecoration(
                            labelText: "Product Details",
                            labelStyle: TextStyle(color: AppColors.textColor),
                            filled: true,
                            fillColor: AppColors.backgroundColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.primary, width: 2),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          maxLines: 3,
                          style: TextStyle(color: AppColors.textColor),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: _priceController,
                          decoration: InputDecoration(
                            labelText: "Price",
                            labelStyle: TextStyle(color: AppColors.textColor),
                            filled: true,
                            fillColor: AppColors.backgroundColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.primary, width: 2),
                            ),
                            prefixText: "\₹ ",
                            prefixStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: AppColors.textColor),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Product Images",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textColor,
                            )
                        ),
                        SizedBox(height: 8),
                        Text("Add or remove images of your product",
                            style: TextStyle(
                              color: AppColors.textColor.withOpacity(0.7),
                              fontSize: 14,
                            )
                        ),
                        SizedBox(height: 16),
                        if (allImagePreviews.isNotEmpty)
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: allImagePreviews,
                          )
                        else
                          Container(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Icon(Icons.image, size: 50, color: AppColors.textColor.withOpacity(0.3)),
                                SizedBox(height: 8),
                                Text("No images selected", style: TextStyle(color: AppColors.textColor.withOpacity(0.5))),
                              ],
                            ),
                          ),
                        SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _pickImages,
                          icon: Icon(Icons.add_photo_alternate, color: Colors.white),
                          label: Text("Add More Images", style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                            shadowColor: AppColors.primary.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveToFirestore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isEditing ? AppColors.primary2 : AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      shadowColor: (_isEditing ? AppColors.primary2 : AppColors.secondary).withOpacity(0.4),
                    ),
                    child: _isSaving
                        ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Text(_isEditing ? "Update Product" : "Save Product",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// class AddProductScreen extends StatefulWidget {
//   const AddProductScreen({super.key, required this.title});
//
//   final String title;
//
//   @override
//   State<AddProductScreen> createState() => _AddProductScreenState();
// }
//
//
// class _AddProductScreenState extends State<AddProductScreen> {
//   final TextEditingController _productNameController = TextEditingController();
//   final TextEditingController _productDetailController = TextEditingController();
//   final TextEditingController _priceController = TextEditingController();
//
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//
//   final List<File> _selectedImageFiles = [];
//   final List<Uint8List> _selectedImageBytesList = [];
//   final List<String> _uploadedImageUrls = [];
//
//   final picker = ImagePicker();
//   final cloudinary = CloudinaryPublic(
//     'dei574s6o',
//     'BulkBites',
//     cache: false,
//   );
//
//   bool _isSaving = false;
//
//   Future<void> _pickImages() async {
//     final pickedFiles = await picker.pickMultiImage();
//     if (pickedFiles.isEmpty) return;
//
//     if (kIsWeb) {
//       for (final file in pickedFiles) {
//         final bytes = await file.readAsBytes();
//         _selectedImageBytesList.add(bytes);
//       }
//     } else {
//       for (final file in pickedFiles) {
//         _selectedImageFiles.add(File(file.path));
//       }
//     }
//
//     setState(() {});
//   }
//
//   void _removeImage(int index) {
//     setState(() {
//       if (kIsWeb) {
//         _selectedImageBytesList.removeAt(index);
//       } else {
//         _selectedImageFiles.removeAt(index);
//       }
//     });
//   }
//
//   Future<void> _uploadImages() async {
//     _uploadedImageUrls.clear();
//
//     if (kIsWeb && _selectedImageBytesList.isNotEmpty) {
//       for (var i = 0; i < _selectedImageBytesList.length; i++) {
//         final response = await cloudinary.uploadFile(
//           CloudinaryFile.fromBytesData(
//             _selectedImageBytesList[i],
//             identifier: 'upload_$i',
//             resourceType: CloudinaryResourceType.Image,
//           ),
//         );
//         _uploadedImageUrls.add(response.secureUrl);
//       }
//     } else if (_selectedImageFiles.isNotEmpty) {
//       for (var file in _selectedImageFiles) {
//         final response = await cloudinary.uploadFile(
//           CloudinaryFile.fromFile(
//             file.path,
//             resourceType: CloudinaryResourceType.Image,
//           ),
//         );
//         _uploadedImageUrls.add(response.secureUrl);
//       }
//     }
//   }
//
//   Future<void> _saveToFirestore() async {
//     if (_isSaving) return;
//
//     if ((kIsWeb && _selectedImageBytesList.isEmpty) || (!kIsWeb && _selectedImageFiles.isEmpty)) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text("Please select at least one image"),
//           backgroundColor: AppColors.error,
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//         ),
//       );
//       return;
//     }
//
//     setState(() {
//       _isSaving = true;
//     });
//
//     try {
//       await _uploadImages();
//
//       await _firestore.collection("products").add({
//         "productName": _productNameController.text.trim(),
//         "productDetail": _productDetailController.text.trim(),
//         "price": double.tryParse(_priceController.text.trim()) ?? 0,
//         "images": _uploadedImageUrls,
//         "createdAt": FieldValue.serverTimestamp(),
//       });
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text("Product saved successfully! ✅"),
//           backgroundColor: AppColors.success,
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//         ),
//       );
//
//       _productNameController.clear();
//       _productDetailController.clear();
//       _priceController.clear();
//       setState(() {
//         _selectedImageFiles.clear();
//         _selectedImageBytesList.clear();
//         _uploadedImageUrls.clear();
//         _isSaving = false;
//       });
//     } catch (e) {
//       setState(() => _isSaving = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text("Error: $e"),
//           backgroundColor: AppColors.error,
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//         ),
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     List<Widget> imagePreviews = [];
//
//     if (kIsWeb && _selectedImageBytesList.isNotEmpty) {
//       imagePreviews = List.generate(_selectedImageBytesList.length, (index) {
//         return Container(
//           margin: EdgeInsets.all(4),
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(12),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black12,
//                 blurRadius: 4,
//                 offset: Offset(0, 2),
//               )
//             ],
//           ),
//           child: Stack(
//             children: [
//               ClipRRect(
//                 borderRadius: BorderRadius.circular(12),
//                 child: Image.memory(_selectedImageBytesList[index], height: 100, width: 100, fit: BoxFit.cover),
//               ),
//               Positioned(
//                 right: 4,
//                 top: 4,
//                 child: GestureDetector(
//                   onTap: () => _removeImage(index),
//                   child: Container(
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       shape: BoxShape.circle,
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black26,
//                           blurRadius: 4,
//                           offset: Offset(0, 2),
//                         )
//                       ],
//                     ),
//                     child: Icon(Icons.close, size: 18, color: AppColors.error),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         );
//       });
//     } else if (_selectedImageFiles.isNotEmpty) {
//       imagePreviews = List.generate(_selectedImageFiles.length, (index) {
//         return Container(
//           margin: EdgeInsets.all(4),
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(12),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black12,
//                 blurRadius: 4,
//                 offset: Offset(0, 2),
//               )
//             ],
//           ),
//           child: Stack(
//             children: [
//               ClipRRect(
//                 borderRadius: BorderRadius.circular(12),
//                 child: Image.file(_selectedImageFiles[index], height: 100, width: 100, fit: BoxFit.cover),
//               ),
//               Positioned(
//                 right: 4,
//                 top: 4,
//                 child: GestureDetector(
//                   onTap: () => _removeImage(index),
//                   child: Container(
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       shape: BoxShape.circle,
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black26,
//                           blurRadius: 4,
//                           offset: Offset(0, 2),
//                         )
//                       ],
//                     ),
//                     child: Icon(Icons.close, size: 18, color: AppColors.error),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         );
//       });
//     }
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(widget.title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
//         backgroundColor: AppColors.primary,
//         elevation: 0,
//         iconTheme: IconThemeData(color: Colors.white),
//       ),
//       body: Container(
//         color: AppColors.backgroundColor,
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: SingleChildScrollView(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Card(
//                   elevation: 2,
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//                   child: Container(
//                     padding: EdgeInsets.all(20),
//                     decoration: BoxDecoration(
//                       color: AppColors.cardColor,
//                       borderRadius: BorderRadius.circular(16),
//                       gradient: LinearGradient(
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                         colors: [AppColors.cardColor, AppColors.cardColor.withOpacity(0.9)],
//                       ),
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text("Add New Product",
//                             style: TextStyle(
//                               fontSize: 22,
//                               fontWeight: FontWeight.w700,
//                               color: AppColors.primary,
//                             )
//                         ),
//                         SizedBox(height: 8),
//                         Text("Fill in the details below to add a new product",
//                             style: TextStyle(
//                               color: AppColors.textColor.withOpacity(0.7),
//                               fontSize: 14,
//                             )
//                         ),
//                         SizedBox(height: 20),
//                         TextField(
//                           controller: _productNameController,
//                           decoration: InputDecoration(
//                             labelText: "Product Name",
//                             labelStyle: TextStyle(color: AppColors.textColor),
//                             filled: true,
//                             fillColor: AppColors.backgroundColor,
//                             border: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(12),
//                               borderSide: BorderSide.none,
//                             ),
//                             focusedBorder: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(12),
//                               borderSide: BorderSide(color: AppColors.primary, width: 2),
//                             ),
//                             contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//                           ),
//                           style: TextStyle(color: AppColors.textColor),
//                         ),
//                         SizedBox(height: 16),
//                         TextField(
//                           controller: _productDetailController,
//                           decoration: InputDecoration(
//                             labelText: "Product Details",
//                             labelStyle: TextStyle(color: AppColors.textColor),
//                             filled: true,
//                             fillColor: AppColors.backgroundColor,
//                             border: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(12),
//                               borderSide: BorderSide.none,
//                             ),
//                             focusedBorder: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(12),
//                               borderSide: BorderSide(color: AppColors.primary, width: 2),
//                             ),
//                             contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//                           ),
//                           maxLines: 3,
//                           style: TextStyle(color: AppColors.textColor),
//                         ),
//                         SizedBox(height: 16),
//                         TextField(
//                           controller: _priceController,
//                           decoration: InputDecoration(
//                             labelText: "Price",
//                             labelStyle: TextStyle(color: AppColors.textColor),
//                             filled: true,
//                             fillColor: AppColors.backgroundColor,
//                             border: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(12),
//                               borderSide: BorderSide.none,
//                             ),
//                             focusedBorder: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(12),
//                               borderSide: BorderSide(color: AppColors.primary, width: 2),
//                             ),
//                             prefixText: "\$ ",
//                             prefixStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
//                             contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//                           ),
//                           keyboardType: TextInputType.numberWithOptions(decimal: true),
//                           style: TextStyle(color: AppColors.textColor),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//                 SizedBox(height: 20),
//                 Card(
//                   elevation: 2,
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//                   child: Container(
//                     padding: EdgeInsets.all(20),
//                     decoration: BoxDecoration(
//                       color: AppColors.cardColor,
//                       borderRadius: BorderRadius.circular(16),
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text("Product Images",
//                             style: TextStyle(
//                               fontSize: 18,
//                               fontWeight: FontWeight.w600,
//                               color: AppColors.textColor,
//                             )
//                         ),
//                         SizedBox(height: 8),
//                         Text("Add one or more images of your product",
//                             style: TextStyle(
//                               color: AppColors.textColor.withOpacity(0.7),
//                               fontSize: 14,
//                             )
//                         ),
//                         SizedBox(height: 16),
//                         if (imagePreviews.isNotEmpty)
//                           Wrap(
//                             spacing: 10,
//                             runSpacing: 10,
//                             children: imagePreviews,
//                           )
//                         else
//                           Container(
//                             padding: EdgeInsets.symmetric(vertical: 40),
//                             alignment: Alignment.center,
//                             child: Column(
//                               children: [
//                                 Icon(Icons.image, size: 50, color: AppColors.textColor.withOpacity(0.3)),
//                                 SizedBox(height: 8),
//                                 Text("No images selected", style: TextStyle(color: AppColors.textColor.withOpacity(0.5))),
//                               ],
//                             ),
//                           ),
//                         SizedBox(height: 20),
//                         ElevatedButton.icon(
//                           onPressed: _pickImages,
//                           icon: Icon(Icons.add_photo_alternate, color: Colors.white),
//                           label: Text("Select Images", style: TextStyle(color: Colors.white)),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: AppColors.primary,
//                             foregroundColor: Colors.white,
//                             padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                             elevation: 2,
//                             shadowColor: AppColors.primary.withOpacity(0.4),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//                 SizedBox(height: 20),
//                 Container(
//                   width: double.infinity,
//                   child: ElevatedButton(
//                     onPressed: _isSaving ? null : _saveToFirestore,
//                     child: _isSaving
//                         ? SizedBox(
//                       height: 20,
//                       width: 20,
//                       child: CircularProgressIndicator(
//                         strokeWidth: 2,
//                         valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                       ),
//                     )
//                         : Text("Save Product", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: AppColors.secondary,
//                       foregroundColor: Colors.white,
//                       padding: const EdgeInsets.symmetric(vertical: 16),
//                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                       elevation: 2,
//                       shadowColor: AppColors.secondary.withOpacity(0.4),
//                     ),
//                   ),
//                 ),
//                 SizedBox(height: 10),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }