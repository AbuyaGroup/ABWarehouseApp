// location.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _kPrimary = Color(0xff174A93);
const Color _kBg = Color(0xffF4F6FA);

class LocationPage extends StatelessWidget {
  const LocationPage({super.key});

  static const String _collection = 'location';

  // ---------------- LOCATION DIALOG ----------------
  Future<void> _showLocationDialog(
    BuildContext context, {
    String? existingDocId,
    String? existingCompanyCode,
    String? existingLocationCode,
  }) async {
    final isEditing = existingDocId != null;
    final companyController =
        TextEditingController(text: existingCompanyCode);
    final locationController =
        TextEditingController(text: existingLocationCode);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEditing ? "Edit Location" : "Add Location"),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: companyController,
                  enabled: !isEditing,
                  decoration: const InputDecoration(labelText: "Company Code"),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? "Required" : null,
                ),
                TextFormField(
                  controller: locationController,
                  enabled: !isEditing,
                  decoration: const InputDecoration(labelText: "Location Code"),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? "Required" : null,
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
                final companyCode = companyController.text.trim();
                final locationCode = locationController.text.trim();
                final docId = "${companyCode}_$locationCode";
                final collection =
                    FirebaseFirestore.instance.collection(_collection);

                try {
                  if (isEditing) {
                    await collection.doc(existingDocId).update({
                      'company_code': companyCode,
                      'location_code': locationCode,
                    });
                  } else {
                    final existingDoc = await collection.doc(docId).get();
                    if (existingDoc.exists) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                              content: Text("Location already exists")),
                        );
                      }
                      return;
                    }
                    await collection.doc(docId).set({
                      'company_code': companyCode,
                      'location_code': locationCode,
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

  Future<void> _confirmDelete(
    BuildContext context, {
    required String title,
    required String message,
    required Future<void> Function() onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
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
        await onConfirm();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error deleting: $e")),
          );
        }
      }
    }
  }

  // ---------------- ZONE DIALOG ----------------
  Future<void> _showZoneDialog(
    BuildContext context,
    CollectionReference zonesRef, {
    String? existingZoneCode,
  }) async {
    final isEditing = existingZoneCode != null;
    final zoneController = TextEditingController(text: existingZoneCode);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEditing ? "Edit Zone" : "Add Zone"),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: zoneController,
              enabled: !isEditing,
              decoration: const InputDecoration(labelText: "Zone Code"),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? "Required" : null,
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
                final zoneCode = zoneController.text.trim();

                try {
                  if (isEditing) {
                    await zonesRef
                        .doc(existingZoneCode)
                        .update({'zone_code': zoneCode});
                  } else {
                    final existingDoc = await zonesRef.doc(zoneCode).get();
                    if (existingDoc.exists) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text("Zone already exists")),
                        );
                      }
                      return;
                    }
                    await zonesRef.doc(zoneCode).set({'zone_code': zoneCode});
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

  // ---------------- SECTOR DIALOG ----------------
  Future<void> _showSectorDialog(
    BuildContext context,
    CollectionReference sectorsRef, {
    String? existingSectorCode,
  }) async {
    final isEditing = existingSectorCode != null;
    final sectorController = TextEditingController(text: existingSectorCode);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEditing ? "Edit Sector" : "Add Sector"),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: sectorController,
              enabled: !isEditing,
              decoration: const InputDecoration(labelText: "Sector Code"),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? "Required" : null,
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
                final sectorCode = sectorController.text.trim();

                try {
                  if (isEditing) {
                    await sectorsRef
                        .doc(existingSectorCode)
                        .update({'sector_code': sectorCode});
                  } else {
                    final existingDoc =
                        await sectorsRef.doc(sectorCode).get();
                    if (existingDoc.exists) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                              content: Text("Sector already exists")),
                        );
                      }
                      return;
                    }
                    await sectorsRef
                        .doc(sectorCode)
                        .set({'sector_code': sectorCode});
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

  @override
  Widget build(BuildContext context) {
    final locationsRef = FirebaseFirestore.instance.collection(_collection);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text("Locations"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: "Add Location",
            onPressed: () => _showLocationDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: locationsRef.snapshots(),
        builder: (context, locationSnap) {
          if (locationSnap.hasError) {
            return Center(child: Text("Error: ${locationSnap.error}"));
          }
          if (locationSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final locationDocs = locationSnap.data?.docs ?? [];
          if (locationDocs.isEmpty) {
            return const Center(child: Text("No locations found"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: locationDocs.length,
            itemBuilder: (context, i) {
              final locDoc = locationDocs[i];
              final locData = locDoc.data() as Map<String, dynamic>;
              final locId = locDoc.id;
              final companyCode = locData['company_code']?.toString() ?? '-';
              final locationCode =
                  locData['location_code']?.toString() ?? '-';
              final zonesRef = locDoc.reference.collection('zones');

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  leading: const Icon(Icons.apartment, color: _kPrimary),
                  title: Text(
                    "$companyCode / $locationCode",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("Doc ID: $locId"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add, size: 20, color: _kPrimary),
                        tooltip: "Add Zone",
                        onPressed: () => _showZoneDialog(context, zonesRef),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20, color: _kPrimary),
                        onPressed: () => _showLocationDialog(
                          context,
                          existingDocId: locId,
                          existingCompanyCode: companyCode,
                          existingLocationCode: locationCode,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        onPressed: () => _confirmDelete(
                          context,
                          title: "Delete Location",
                          message:
                              "Delete \"$locId\"? Zones/sectors underneath won't be auto-deleted.",
                          onConfirm: () => locDoc.reference.delete(),
                        ),
                      ),
                    ],
                  ),
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: zonesRef.snapshots(),
                      builder: (context, zoneSnap) {
                        if (zoneSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(),
                          );
                        }
                        final zoneDocs = zoneSnap.data?.docs ?? [];
                        if (zoneDocs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text("No zones yet",
                                  style: TextStyle(color: Colors.grey)),
                            ),
                          );
                        }

                        return Column(
                          children: zoneDocs.map((zoneDoc) {
                            final zoneData =
                                zoneDoc.data() as Map<String, dynamic>;
                            final zoneId = zoneDoc.id;
                            final zoneCode =
                                zoneData['zone_code']?.toString() ?? zoneId;
                            final sectorsRef =
                                zoneDoc.reference.collection('sectors');

                            return Padding(
                              padding: const EdgeInsets.only(left: 16, right: 8),
                              child: ExpansionTile(
                                leading:
                                    const Icon(Icons.grid_view_rounded, color: _kPrimary),
                                title: Text("Zone: $zoneCode"),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 18, color: _kPrimary),
                                      tooltip: "Add Sector",
                                      onPressed: () => _showSectorDialog(
                                          context, sectorsRef),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18, color: _kPrimary),
                                      onPressed: () => _showZoneDialog(
                                        context,
                                        zonesRef,
                                        existingZoneCode: zoneId,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                      onPressed: () => _confirmDelete(
                                        context,
                                        title: "Delete Zone",
                                        message:
                                            "Delete zone \"$zoneId\"? Sectors underneath won't be auto-deleted.",
                                        onConfirm: () =>
                                            zoneDoc.reference.delete(),
                                      ),
                                    ),
                                  ],
                                ),
                                children: [
                                  StreamBuilder<QuerySnapshot>(
                                    stream: sectorsRef.snapshots(),
                                    builder: (context, sectorSnap) {
                                      if (sectorSnap.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: CircularProgressIndicator(),
                                        );
                                      }
                                      final sectorDocs =
                                          sectorSnap.data?.docs ?? [];
                                      if (sectorDocs.isEmpty) {
                                        return const Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text("No sectors yet",
                                                style: TextStyle(
                                                    color: Colors.grey)),
                                          ),
                                        );
                                      }

                                      return Column(
                                        children: sectorDocs.map((sectorDoc) {
                                          final sectorData = sectorDoc.data()
                                              as Map<String, dynamic>;
                                          final sectorId = sectorDoc.id;
                                          final sectorCode = sectorData[
                                                      'sector_code']
                                                  ?.toString() ??
                                              sectorId;

                                          return ListTile(
                                            dense: true,
                                            contentPadding:
                                                const EdgeInsets.only(
                                                    left: 32, right: 8),
                                            leading: const Icon(
                                                Icons.crop_square,
                                                size: 18,
                                                color: _kPrimary),
                                            title:
                                                Text("Sector: $sectorCode"),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit,
                                                      size: 18,
                                                      color: _kPrimary),
                                                  onPressed: () =>
                                                      _showSectorDialog(
                                                    context,
                                                    sectorsRef,
                                                    existingSectorCode:
                                                        sectorId,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.delete,
                                                      size: 18,
                                                      color: Colors.red),
                                                  onPressed: () =>
                                                      _confirmDelete(
                                                    context,
                                                    title: "Delete Sector",
                                                    message:
                                                        "Delete sector \"$sectorId\"?",
                                                    onConfirm: () =>
                                                        sectorDoc.reference
                                                            .delete(),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}