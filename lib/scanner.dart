import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:abwarehouse/models/products.dart';

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

    final snapshot = await FirebaseFirestore.instance
        .collection("products")
        .get();

    for (var doc in snapshot.docs) {
      products[doc.id] = Product.fromFirestore(
        doc.id,
        doc.data(),
      );
    }

    print("Loaded ${products.length} products");
  } catch (e) {
    print("Firestore error: $e");
  } finally {
    if (mounted) {
      setState(() => isLoadingProducts = false);
    }
  }
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

  Future<void> showRegisterDialog() async {
    final barcodeController = TextEditingController();
    final nameController = TextEditingController();
    final unitController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Register Product"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: barcodeController, decoration: const InputDecoration(labelText: "Barcode")),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Product Name")),
            TextField(controller: unitController, decoration: const InputDecoration(labelText: "Unit")),
          ],
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection("products")
                  .doc(barcodeController.text.trim())
                  .set({
                "product_name": nameController.text.trim(),
                "unit": unitController.text.trim(),
              });

              await loadProducts();

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
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
            icon: const Icon(Icons.add_box_outlined),
            onPressed: showRegisterDialog,
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
                    title: Text(product?.productName ?? "Unknown"),
                    subtitle: Text("$barcode\n${product?.unit ?? ""}"),
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
