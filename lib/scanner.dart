import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:abwarehouse/models/products.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Scanner extends StatefulWidget {
  const Scanner({super.key});

  @override
  State<Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<Scanner> {
  final AudioPlayer player = AudioPlayer();
  final MobileScannerController controller = MobileScannerController();

  final Map<String, Product> products = {};
  final Map<String, int> qty = {};

  final supabase = Supabase.instance.client;

  bool canScan = true;
  bool isLoadingProducts = true;

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
  setState(() => isLoadingProducts = true);

  try {
    products.clear();

    final response = await supabase
        .from('master_produk')
        .select(
          'barcode, kode_produk, nama, kategori, sub_kategori, satuan',
        );

    for (final row in response) {
      final product = Product.fromJson(row);
      products[product.barcode] = product;
    }

    debugPrint("Loaded ${products.length} products");
  } catch (e) {
    debugPrint("Supabase error: $e");
  } finally {
    if (mounted) {
      setState(() => isLoadingProducts = false);
    }
  }
}

void showProductsDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Master Produk (${products.length})"),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products.values.elementAt(index);

            return ListTile(
              dense: true,
              title: Text(product.nama),
              subtitle: Text(
                "Barcode: ${product.barcode}\n"
                "Kode: ${product.kodeProduk}\n"
                "Kategori: ${product.kategori}\n"
                "Subkategori: ${product.subkategori}\n"
                "Satuan: ${product.satuan}",
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("OK"),
        ),
      ],
    ),
  );
}

  Future<void> scanBarcode(String code) async {
    if (!products.containsKey(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Product not registered")),
      );
      return;
    }

    qty.update(code, (v) => v + 1, ifAbsent: () => 1);
    await player.play(AssetSource("beep.mp3"));

    if (mounted) setState(() {});
  }

  void incrementQty(String barcode) {
    setState(() {
      qty.update(barcode, (v) => v + 1, ifAbsent: () => 1);
    });
  }

  void decrementQty(String barcode) {
    setState(() {
      final current = qty[barcode] ?? 0;
      if (current <= 1) {
        qty.remove(barcode);
      } else {
        qty[barcode] = current - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingProducts) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Scanner"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadProducts,
          ),
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: showProductsDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: MobileScanner(
              controller: controller,
              onDetect: (capture) async {
                if (!canScan) return;
                final code = capture.barcodes.first.rawValue;
                if (code == null) return;

                canScan = false;
                await scanBarcode(code);
                await Future.delayed(const Duration(milliseconds: 700));
                canScan = true;
              },
            ),
          ),
          Expanded(
            flex: 5,
            child: ListView.builder(
              itemCount: qty.length,
              itemBuilder: (context, index) {
                final barcode = qty.keys.elementAt(index);
                final product = products[barcode];

                return Card(
                  child: ListTile(
                    title: Text(product?.nama ?? "Unknown"),

                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Barcode : ${product?.barcode ?? ""}"),
                        Text("Kode : ${product?.kodeProduk ?? ""}"),
                        Text("Kategori : ${product?.kategori ?? ""}"),
                        Text("Subkategori : ${product?.subkategori ?? ""}"),
                        Text("Satuan : ${product?.satuan ?? ""}"),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: ()=>decrementQty(barcode),
                        ),
                        Text(qty[barcode].toString()),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: ()=>incrementQty(barcode),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
