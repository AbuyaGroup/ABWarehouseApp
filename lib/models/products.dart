class Product {
  final String barcode;
  final String nama;
  final String? kodeProduk;
  final String? kategori;
  final String? subkategori;
  final String? satuan;

  Product({
    required this.barcode,
    required this.nama,
    this.kodeProduk,
    this.kategori,
    this.subkategori,
    this.satuan,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      barcode: json['barcode'] as String,
      nama: json['nama'] as String,
      kodeProduk: json['kode_produk'] as String?,
      kategori: json['kategori'] as String?,
      subkategori: json['sub_kategori'] as String?,
      satuan: json['satuan'] as String?,
    );
  }
}