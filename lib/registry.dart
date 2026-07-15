// registry.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegistryPage extends StatelessWidget {
  const RegistryPage({super.key});

  static const String _registryCollection = 'products';

  // ---------- ADD / EDIT DIALOG ----------
  Future<void> _showProductDialog(
    BuildContext context, {
    String? existingBarcode,
    String? existingName,
    String? existingUnit,
  }) async {
    final isEditing = existingBarcode != null;

    final barcodeController = TextEditingController(text: existingBarcode);
    final nameController = TextEditingController(text: existingName);
    final unitController = TextEditingController(text: existingUnit);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEditing ? "Edit Product" : "Add Product"),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: barcodeController,
                  enabled: !isEditing, // barcode is doc id, lock it when editing
                  decoration: const InputDecoration(labelText: "Barcode"),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? "Barcode is required"
                          : null,
                ),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Product Name"),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? "Product name is required"
                          : null,
                ),
                TextFormField(
                  controller: unitController,
                  decoration: const InputDecoration(labelText: "Unit"),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? "Unit is required"
                          : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final barcode = barcodeController.text.trim();
                final name = nameController.text.trim();
                final unit = unitController.text.trim();

                final collection = FirebaseFirestore.instance
                    .collection(_registryCollection);

                try {
                  if (isEditing) {
                    // barcode locked -> just update the existing doc
                    await collection.doc(existingBarcode).update({
                      'product_name': name,
                      'unit': unit,
                    });
                  } else {
                    // check for duplicate barcode before creating
                    final existingDoc = await collection.doc(barcode).get();
                    if (existingDoc.exists) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text("Barcode already exists"),
                          ),
                        );
                      }
                      return;
                    }
                    await collection.doc(barcode).set({
                      'product_name': name,
                      'unit': unit,
                    });
                  }

                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text("Error: $e")),
                    );
                  }
                }
              },
              child: Text(isEditing ? "Save" : "Add"),
            ),
          ],
        );
      },
    );
  }

  // ---------- DELETE CONFIRMATION ----------
  Future<void> _confirmDelete(BuildContext context, String barcode) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Product"),
        content: Text("Are you sure you want to delete \"$barcode\"?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection(_registryCollection)
            .doc(barcode)
            .delete();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error deleting: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F6FA),
      appBar: AppBar(
        title: const Text("Registry"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: "Add Product",
            onPressed: () => _showProductDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(_registryCollection)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text("No data found"));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xff174A93),
                ),
                headingTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                columns: const [
                  DataColumn(label: Text("Barcode")),
                  DataColumn(label: Text("Product Name")),
                  DataColumn(label: Text("Unit")),
                  DataColumn(label: Text("Actions")),
                ],
                rows: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final barcode = doc.id;
                  final name = data['product_name']?.toString() ?? '-';
                  final unit = data['unit']?.toString() ?? '-';

                  return DataRow(
                    cells: [
                      DataCell(Text(barcode)),
                      DataCell(Text(name)),
                      DataCell(Text(unit)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Color(0xff174A93),
                              ),
                              onPressed: () => _showProductDialog(
                                context,
                                existingBarcode: barcode,
                                existingName: name,
                                existingUnit: unit,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  _confirmDelete(context, barcode),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}