import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Scanner extends StatefulWidget {
  const Scanner({super.key});

  @override
  State<Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<Scanner> {
  static const String _prefsKey = "registered_products";

  final AudioPlayer player = AudioPlayer();

  final MobileScannerController controller = MobileScannerController();

  // Starts with defaults; overwritten by anything loaded from storage.
  final Map<String, String> products = {
    "8997223500078": "PrimeBread Moka",
    "8997223500016": "PrimeBread Coklat",
  };

  final Map<String, int> qty = {};

  bool canScan = true;
  bool isLoadingProducts = true;

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);

    if (stored != null) {
      final Map<String, dynamic> decoded = jsonDecode(stored);
      products.addAll(decoded.map((key, value) => MapEntry(key, value.toString())));
    }

    setState(() {
      isLoadingProducts = false;
    });
  }

  Future<void> saveProducts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(products));
  }

  Future<void> scanBarcode(String code) async {
    if (!products.containsKey(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Product not registered"),
          duration: Duration(milliseconds: 800),
        ),
      );
      return;
    }

    qty.update(code, (value) => value + 1, ifAbsent: () => 1);

    await player.play(AssetSource("beep.mp3"));

    setState(() {});
  }

  void incrementQty(String barcode) {
    setState(() {
      qty.update(barcode, (value) => value + 1, ifAbsent: () => 1);
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

  void showRegisterDialog() {
    final barcodeController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Register Product"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: barcodeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Barcode Number",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Item Name",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final barcode = barcodeController.text.trim();
                final name = nameController.text.trim();

                if (barcode.isEmpty || name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Barcode and name are required"),
                      duration: Duration(milliseconds: 900),
                    ),
                  );
                  return;
                }

                setState(() {
                  products[barcode] = name;
                });

                await saveProducts();

                if (!context.mounted) return;
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Registered: $name"),
                    duration: const Duration(milliseconds: 800),
                  ),
                );
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void showManageProductsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Registered Products"),
          content: SizedBox(
            width: double.maxFinite,
            child: products.isEmpty
                ? const Text("No products registered yet.")
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final barcode = products.keys.elementAt(index);
                      final name = products[barcode]!;

                      return ListTile(
                        title: Text(name),
                        subtitle: Text(barcode),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                            setState(() {
                              products.remove(barcode);
                              qty.remove(barcode);
                            });
                            await saveProducts();
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingProducts) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Scanner"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: "Manage Products",
            onPressed: showManageProductsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: "Register Product",
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

                await Future.delayed(
                  const Duration(milliseconds: 700),
                );

                canScan = true;
              },
            ),
          ),

          Container(
            color: Colors.grey.shade200,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [

                const Text(
                  "Items Scanned",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),

                const Spacer(),

                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      qty.clear();
                    });
                  },
                  child: const Text("Clear"),
                )

              ],
            ),
          ),

          Expanded(
            flex: 5,
            child: ListView.builder(
              itemCount: qty.length,
              itemBuilder: (context, index) {

                String barcode = qty.keys.elementAt(index);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text("${index + 1}"),
                    ),
                    title: Text(products[barcode] ?? "Unknown"),
                    subtitle: Text(barcode),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => decrementQty(barcode),
                        ),
                        SizedBox(
                          width: 28,
                          child: Text(
                            qty[barcode].toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => incrementQty(barcode),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}