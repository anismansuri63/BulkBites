// product_detail_purchase_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/CartItem.dart';
import '../utlity/AppColors.dart';


class ProductDetailPurchaseScreen extends StatelessWidget {
  final String productId;
  final Map<String, dynamic> productData;

  const ProductDetailPurchaseScreen({
    super.key,
    required this.productId,
    required this.productData,
  });

  @override
  Widget build(BuildContext context) {
    final cartManager = Provider.of<CartManager>(context);
    final currentQuantity = cartManager.getQuantity(productId);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Product Details",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: AppColors.backgroundColor,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Image
                    Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: AppColors.cardColor,
                      ),
                      child: productData["images"] != null && productData["images"].isNotEmpty
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          productData["images"][0],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.image_not_supported,
                              color: AppColors.textColor.withOpacity(0.3),
                              size: 64,
                            );
                          },
                        ),
                      )
                          : Center(
                        child: Icon(
                          Icons.image,
                          color: AppColors.textColor.withOpacity(0.3),
                          size: 64,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    // Product Name
                    Text(
                      productData["productName"] ?? "No Name",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textColor,
                      ),
                    ),
                    SizedBox(height: 10),
                    // Price
                    Text(
                      "₹ ${productData["price"]?.toStringAsFixed(2) ?? '0.00'}",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 20),
                    // Description
                    if (productData["productDetail"] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Description",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textColor,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            productData["productDetail"],
                            style: TextStyle(
                              color: AppColors.textColor.withOpacity(0.7),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            // Add to Cart Button
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (currentQuantity > 0)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove, color: AppColors.primary),
                              onPressed: () => cartManager.removeItem(productId),
                            ),
                            Text(
                              currentQuantity.toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                fontSize: 18,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.add, color: AppColors.primary),
                              onPressed: () => cartManager.addItem(
                                productId,
                                productData["productName"] ?? "No Name",
                                (productData["price"] ?? 0).toDouble(),
                                List<String>.from(productData["images"] ?? []),
                                productDetail: productData["productDetail"],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => cartManager.addItem(
                          productId,
                          productData["productName"] ?? "No Name",
                          (productData["price"] ?? 0).toDouble(),
                          List<String>.from(productData["images"] ?? []),
                          productDetail: productData["productDetail"],
                        ),
                        child: Text("Add to Cart"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}