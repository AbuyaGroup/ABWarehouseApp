class Product {
  final String barcode;
  final String productName;
  final String unit;

  Product({
    required this.barcode,
    required this.productName,
    required this.unit,
  });

  factory Product.fromFirestore(String id, Map<String, dynamic> data) {
    return Product(
      barcode: id,
      productName: data['product_name'] ?? '',
      unit: data['unit'] ?? '',
    );
  }
}