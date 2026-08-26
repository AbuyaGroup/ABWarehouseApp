import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:abwarehouse/app_theme.dart';

/// Fitur utama: scan produk fisik per DC.
/// Alur: pilih DC (admin) -> pilih sesi opname aktif -> scan -> upload.
/// Tiap scan munculin dialog pilih SECTOR (produk bisa ada di lebih dari
/// satu sector) + isi qty. Hasil scan numpuk di device dulu (barcode +
/// sector + qty), baru beneran kekirim ke opname_entries pas tombol
/// Upload dipencet.
class Scanner extends StatefulWidget {
  const Scanner({super.key});

  @override
  State<Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<Scanner> {
  final supabase = Supabase.instance.client;
  final AudioPlayer player = AudioPlayer();
  final MobileScannerController controller = MobileScannerController();

  bool canScan = true;
  bool isLoading = true;
  bool isUploading = false;
  String? namaUser;
  String? role; // 'admin' atau 'scanner'

  List<Map<String, dynamic>> dcList = [];
  String? selectedDcId;

  // Sesi opname aktif -- bisa lebih dari satu jalan bersamaan per DC
  List<Map<String, dynamic>> sessionList = [];
  Map<String, dynamic>? selectedSession;

  // Hasil scan yang masih di device, belum di-upload ke opname_entries.
  // Key = "barcode|sectorId" (satu produk bisa kehitung di lebih dari satu
  // sector dalam batch yang sama, dan itu SENGAJA -- bukan bug). Value = {
  //   'barcode', 'product' (dari master_produk), 'sectorOptions' (cache
  //   semua sector yang valid buat barcode ini, biar gak query ulang),
  //   'sectorId', 'sectorLabel', 'qty'
  // }
  final Map<String, Map<String, dynamic>> scannedItems = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => init());
  }

  Future<void> init() async {
    setState(() => isLoading = true);
    await loadProfile();
    await loadDcs();
    if (selectedDcId != null) await loadSessions();
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> loadProfile() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final data =
        await supabase.from('profiles').select().eq('id', uid).maybeSingle();
    namaUser = data?['nama'] ?? supabase.auth.currentUser?.email ?? 'User';
    role = data?['role'] ?? 'scanner';
    if (role != 'admin') {
      selectedDcId = data?['dc_id'];
    }
  }

  Future<void> loadDcs() async {
    final data = await supabase.from('dcs').select().order('urutan');
    dcList = List<Map<String, dynamic>>.from(data);
  }

  /// Tarik SEMUA sesi opname yang statusnya aktif buat DC ini.
  Future<void> loadSessions() async {
    if (selectedDcId == null) return;
    try {
      final data = await supabase
          .from('opname_sessions')
          .select()
          .eq('dc_id', selectedDcId!)
          .eq('status', 'aktif')
          .order('created_at', ascending: false);
      sessionList = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint("Gagal load sesi: $e");
      sessionList = [];
    }
  }

  Future<void> pilihDc(String dcId) async {
    setState(() {
      selectedDcId = dcId;
      selectedSession = null;
      isLoading = true;
    });
    await loadSessions();
    if (mounted) setState(() => isLoading = false);
  }

  void pilihSesi(Map<String, dynamic> sesi) {
    setState(() {
      selectedSession = sesi;
      scannedItems.clear();
    });
  }

  /// Semua entry yang UDAH discan buat barcode ini, dari sector manapun aja.
  /// Satu barcode sekarang boleh punya lebih dari satu entry (multi-sector
  /// dalam satu batch) -- makanya ini balikin LIST, bukan satu match doang.
  List<MapEntry<String, Map<String, dynamic>>> _findExistingByBarcode(String barcode) {
    return scannedItems.entries.where((e) => e.value['barcode'] == barcode).toList();
  }

  /// Scan barcode -> cari di master_produk + sector yang valid buat barcode
  /// itu (tabel produk_sectors) -> munculin dialog pilih sector + isi qty.
  ///
  /// Kalau barcode ini UDAH pernah discan sebelumnya (di sector laen), dialog
  /// otomatis nyaranin sector yang BELUM kepake buat barcode ini -- jadi alur
  /// naturalnya: scan -> pilih Sector A -> scan lagi (barcode sama) -> udah
  /// keisi otomatis Sector B (yang belum) -> simpen. Dua-duanya numpuk bareng
  /// di scannedItems, siap di-upload sekaligus. Kalau semua sector yang valid
  /// buat barcode itu udah kepake semua, baru dianggep "edit ulang" -- dialog
  /// preselect ke sector pertama & qty lama ke-isi otomatis.
  Future<void> scanBarcode(String code) async {
    if (selectedSession == null) return;

    final existingEntries = _findExistingByBarcode(code);

    Map<String, dynamic> product;
    List<Map<String, dynamic>> sectorOptions;

    if (existingEntries.isNotEmpty) {
      // Udah pernah discan (di sector manapun) -> pake cache, gak query ulang
      product = existingEntries.first.value['product'] as Map<String, dynamic>;
      sectorOptions =
          existingEntries.first.value['sectorOptions'] as List<Map<String, dynamic>>;
    } else {
      try {
        final data = await supabase
            .from('master_produk')
            .select('barcode, nama, satuan')
            .eq('barcode', code)
            .maybeSingle();

        if (data == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Barcode $code gak ketemu di Master Produk")),
            );
          }
          return;
        }
        product = data;

        // Sector mana aja yang valid buat barcode ini (bisa lebih dari 1)
        final psData = await supabase
            .from('produk_sectors')
            .select('sector_id, sectors(nama, zone_id, zones(nama))')
            .eq('barcode', code);

        sectorOptions = List<Map<String, dynamic>>.from(psData).map((ps) {
          final sector = ps['sectors'] as Map<String, dynamic>?;
          final zone = sector?['zones'] as Map<String, dynamic>?;
          final parts = [zone?['nama'], sector?['nama']]
              .where((e) => e != null && e.toString().trim().isNotEmpty)
              .toList();
          // Dipaksa <String, dynamic> secara eksplisit -- kalau dibiarin
          // Dart nebak sendiri, semua value di map literal ini kebetulan
          // String semua, jadi Dart bakal infer Map<String, String>, bukan
          // Map<String, dynamic> yang dideklarasiin di atas. Beda tipe run-
          // time ini yang bikin firstWhere/orElse di bawah nanti crash.
          return <String, dynamic>{
            'sectorId': ps['sector_id'].toString(),
            'label': parts.isEmpty
                ? (ps['sector_id']?.toString() ?? '-')
                : parts.join(' · '),
          };
        }).toList();

        if (sectorOptions.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    "Produk ini belum di-assign ke sector manapun. Hubungi admin."),
              ),
            );
          }
          return;
        }
      } catch (e) {
        debugPrint("Gagal cari produk/sector: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Gagal cek barcode: $e")),
          );
        }
        return;
      }
    }

    // Suara "beep" -- dibungkus try/catch sendiri, soalnya di sebagian
    // device/emulator audio plugin-nya suka gagal (device audio gak
    // kedetect, dll). Kalau ini dibiarin throw tanpa ditangkep, seluruh
    // scanBarcode() ikut berhenti di tengah jalan dan canScan bisa kejebak.
    try {
      await player.play(AssetSource("beep.mp3"));
    } catch (e) {
      debugPrint("Gagal muter suara beep (diabaikan, lanjut scan): $e");
    }
    if (!mounted) return;

    // Sector-sector yang UDAH kepake buat barcode ini di batch sekarang
    final usedSectorIds =
        existingEntries.map((e) => e.value['sectorId'] as String).toSet();

    // Preselect ke sector PERTAMA YANG BELUM KEPAKE (biar alur "scan lagi buat
    // sector laen" natural). Kalau semua sector udah kepake semua, fallback ke
    // sector pertama (berarti mode edit ulang qty di sector itu).
    final sectorTerpilih = sectorOptions.firstWhere(
      (s) => !usedSectorIds.contains(s['sectorId']),
      orElse: () => sectorOptions.first,
    );
    final preselectedSectorId = sectorTerpilih['sectorId'] as String;

    // Qty awal cuma di-prefill kalau kombinasi barcode+sector INI PERSIS udah
    // punya entry sebelumnya (berarti emang mau diedit qty-nya). Kalau ini
    // sector baru yang belum pernah discan, field qty dibiarin kosong.
    final entryUntukSectorIni = scannedItems['$code|$preselectedSectorId'];
    final qtyAwal = entryUntukSectorIni?['qty'] as num?;

    final hasil = await showScanDialog(
      namaItem: product['nama'] ?? 'Unknown',
      satuan: product['satuan'] ?? '',
      sectorOptions: sectorOptions,
      preselectedSectorId: preselectedSectorId,
      qtyAwal: qtyAwal,
    );

    if (hasil == null) return; // dibatalin, gak ada perubahan

    final sectorId = hasil['sectorId'] as String;
    final qty = hasil['qty'] as num;
    final newKey = '$code|$sectorId';
    final sectorLabel =
        sectorOptions.firstWhere((s) => s['sectorId'] == sectorId)['label'] as String;

    setState(() {
      // CATATAN: gak ada lagi logic "hapus entry sector lama" di sini kaya
      // sebelumnya -- sekarang barcode yang sama BOLEH punya banyak entry,
      // satu per sector, dan semuanya numpuk bareng siap di-upload sekaligus.
      if (qty <= 0) {
        scannedItems.remove(newKey);
      } else {
        scannedItems[newKey] = {
          'barcode': code,
          'product': product,
          'sectorOptions': sectorOptions,
          'sectorId': sectorId,
          'sectorLabel': sectorLabel,
          'qty': qty,
        };
      }
    });
  }

  /// Buka dialog buat produk yang udah ada di list, tanpa perlu scan ulang.
  /// Bisa ubah qty ATAU pindah sector-nya dari sini. INI BEDA sama scanBarcode:
  /// disini user secara eksplisit ngedit SATU entry tertentu, jadi kalau
  /// sector-nya diganti, entry lama itu emang dipindah (bukan nambah baru) --
  /// kecuali kalau sector tujuannya udah kepake sama entry laen, di situ bakal
  /// ditanya dulu biar gak ketiban tanpa sadar.
  Future<void> editItem(String key) async {
    final current = scannedItems[key];
    if (current == null) return;

    final product = current['product'] as Map<String, dynamic>;
    final sectorOptions = current['sectorOptions'] as List<Map<String, dynamic>>;
    final barcode = current['barcode'] as String;

    final hasil = await showScanDialog(
      namaItem: product['nama'] ?? 'Unknown',
      satuan: product['satuan'] ?? '',
      sectorOptions: sectorOptions,
      preselectedSectorId: current['sectorId'] as String,
      qtyAwal: current['qty'] as num,
    );

    if (hasil == null) return;

    final sectorId = hasil['sectorId'] as String;
    final qty = hasil['qty'] as num;
    final newKey = '$barcode|$sectorId';
    final sectorLabel =
        sectorOptions.firstWhere((s) => s['sectorId'] == sectorId)['label'] as String;

    // Kalau user ganti ke sector laen yang KEBETULAN udah ada entry-nya
    // sendiri (dari scan terpisah), konfirmasi dulu biar gak ketiban diem2.
    if (newKey != key && scannedItems.containsKey(newKey)) {
      final overwrite = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("Sector Ini Udah Ada Entry-nya"),
          content: Text(
            "Sector $sectorLabel buat produk ini udah ada entry lain "
            "(qty ${scannedItems[newKey]!['qty']}). Timpa dengan qty $qty?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("Timpa"),
            ),
          ],
        ),
      );
      if (overwrite != true) return;
    }

    setState(() {
      if (key != newKey) scannedItems.remove(key);
      if (qty <= 0) {
        scannedItems.remove(newKey);
      } else {
        scannedItems[newKey] = {
          ...current,
          'sectorId': sectorId,
          'sectorLabel': sectorLabel,
          'qty': qty,
        };
      }
    });
  }

  /// Hapus item dari list hasil scan (dengan konfirmasi dulu).
  Future<void> hapusItem(String key) async {
    final current = scannedItems[key];
    if (current == null) return;
    final product = current['product'] as Map<String, dynamic>;
    final sectorLabel = current['sectorLabel'] as String;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Hapus Item"),
        content: Text(
          "Hapus \"${product['nama'] ?? current['barcode']}\" (sector $sectorLabel) dari list scan ini?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => scannedItems.remove(key));
    }
  }

  /// Dialog gabungan: pilih sector (dropdown, cuma muncul kalau produknya
  /// ke-assign ke lebih dari 1 sector) + isi qty fisik.
  Future<Map<String, dynamic>?> showScanDialog({
    required String namaItem,
    required String satuan,
    required List<Map<String, dynamic>> sectorOptions,
    required String preselectedSectorId,
    num? qtyAwal,
  }) {
    final qtyCtrl =
        TextEditingController(text: qtyAwal != null ? qtyAwal.toString() : '');
    String selectedSectorId = preselectedSectorId;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(namaItem),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sectorOptions.length > 1) ...[
                const Text("Sector",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedSectorId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: sectorOptions
                      .map((s) => DropdownMenuItem<String>(
                            value: s['sectorId'] as String,
                            child: Text(s['label'] as String,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    setDialogState(() => selectedSectorId = val);
                  },
                ),
                const SizedBox(height: 16),
              ] else ...[
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(sectorOptions.first['label'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(labelText: "Qty Fisik", suffixText: satuan),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () {
                final val = num.tryParse(qtyCtrl.text.trim()) ?? qtyAwal ?? 1;
                Navigator.pop(dialogContext, {
                  'sectorId': selectedSectorId,
                  'qty': val,
                });
              },
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  /// Pindahin semua hasil scan lokal ke tabel opname_entries sekaligus.
  Future<void> uploadEntries() async {
    if (selectedSession == null || scannedItems.isEmpty || isUploading) return;

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sesi login gak valid, coba login ulang")),
        );
      }
      return;
    }

    setState(() => isUploading = true);
    try {
      final sessionId = selectedSession!['id'];
      final payload = scannedItems.values.map((item) {
        return {
          'session_id': sessionId,
          'barcode': item['barcode'],
          'sector_id': item['sectorId'],
          'qty_fisik': item['qty'],
          'updated_by': uid, // UUID akun yang login, sesuai FK profiles(id)
          'updated_at': DateTime.now().toIso8601String(),
        };
      }).toList();

      // upsert -- BUKAN insert biasa. Kombinasi session_id+barcode+sector_id
      // itu punya UNIQUE constraint (opname_entries_session_barcode_sector_key)
      // di database, biar barcode+sector yang sama gak numpuk row dobel kalau
      // di-upload lagi di batch laen (misal: recount, atau upload kedua di
      // hari yang beda). upsert bikin row lama otomatis ke-REPLACE (qty &
      // updated_at ke-update), bukan ditolak kaya insert biasa.
      await supabase.from('opname_entries').upsert(
        payload,
        onConflict: 'session_id,barcode,sector_id',
      );

      final jumlah = scannedItems.length;
      if (mounted) {
        setState(() => scannedItems.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$jumlah produk berhasil di-upload")),
        );
      }
    } catch (e) {
      debugPrint("Gagal upload: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal upload: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 1. Admin belum pilih DC
    if (role == 'admin' && selectedDcId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Pilih DC untuk Scan")),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: dcList
              .map((dc) => Card(
                    child: ListTile(
                      title: Text(dc['nama'] ?? ''),
                      subtitle: Text(dc['sub'] ?? ''),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => pilihDc(dc['id']),
                    ),
                  ))
              .toList(),
        ),
      );
    }

    final dcNama = dcList.firstWhere(
      (d) => d['id'] == selectedDcId,
      orElse: () => {'nama': selectedDcId},
    )['nama'];

    // 2. Pilih sesi opname aktif
    if (selectedSession == null) {
      return PopScope(
        canPop: role != 'admin',
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (role == 'admin') setState(() => selectedDcId = null);
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text("$dcNama · Pilih Sesi"),
            leading: role == 'admin'
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() {
                      selectedDcId = null;
                      sessionList.clear();
                    }),
                  )
                : null,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  setState(() => isLoading = true);
                  await loadSessions();
                  if (mounted) setState(() => isLoading = false);
                },
              ),
            ],
          ),
          body: sessionList.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      "Belum ada sesi opname aktif.\nSuruh admin bikin sesi dulu, terus refresh di sini.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sessionList.length,
                  itemBuilder: (context, index) {
                    final sesi = sessionList[index];
                    final namaSesi = sesi['nama'] ?? 'Sesi Opname';
                    final tglRaw =
                        (sesi['tanggal'] ?? sesi['created_at'])?.toString() ?? '';
                    final tgl = tglRaw.length >= 10 ? tglRaw.substring(0, 10) : tglRaw;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.date_range, color: Colors.white),
                        ),
                        title: Text(namaSesi,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text("Tanggal: $tgl"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => pilihSesi(sesi),
                      ),
                    );
                  },
                ),
        ),
      );
    }

    final namaSesiTampil = selectedSession?['nama'] ?? 'Scan';

    // 3. Kamera scan + list hasil scan + tombol upload
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (scannedItems.isNotEmpty) {
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text("Belum di-upload"),
              content: Text(
                "Masih ada ${scannedItems.length} produk hasil scan yang belum "
                "di-upload. Yakin mau keluar? Data ini bakal ilang.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    setState(() => selectedSession = null);
                  },
                  child: const Text("Keluar"),
                ),
              ],
            ),
          );
        } else {
          setState(() => selectedSession = null);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(namaSesiTampil),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => selectedSession = null),
          ),
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
                  try {
                    await scanBarcode(code);
                  } catch (e, st) {
                    // Apapun yang error di dalem scanBarcode (query gagal,
                    // dialog error, dll) -- JANGAN sampe bikin canScan
                    // kejebak di false selamanya, soalnya itu bikin kamera
                    // keliatan jalan tapi gak pernah ngedetect apa-apa lagi.
                    debugPrint("Error pas scanBarcode: $e\n$st");
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Gagal proses scan: $e")),
                      );
                    }
                  } finally {
                    await Future.delayed(const Duration(milliseconds: 700));
                    canScan = true;
                  }
                },
              ),
            ),
            Expanded(
              flex: 5,
              child: scannedItems.isEmpty
                  ? const Center(child: Text("Mulai scan barcode barang..."))
                  : ListView(
                      children: scannedItems.entries.map((e) {
                        final key = e.key;
                        final barcode = e.value['barcode'] as String;
                        final product = e.value['product'] as Map<String, dynamic>;
                        final sectorLabel = e.value['sectorLabel'] as String;
                        final qty = e.value['qty'];

                        return Card(
                          margin:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            onTap: () => editItem(key),
                            title: Text(product['nama'] ?? "Unknown"),
                            subtitle: Text(
                              "${product['satuan'] ?? ''} · Sector: $sectorLabel\nBarcode: $barcode",
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: Text(
                                    "$qty",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      size: 20, color: AppColors.primary),
                                  onPressed: () => editItem(key),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 20, color: AppColors.danger),
                                  onPressed: () => hapusItem(key),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        scannedItems.isEmpty || isUploading ? null : uploadEntries,
                    icon: isUploading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_upload_outlined, color: Colors.white),
                    label: Text(
                      isUploading
                          ? "Mengupload..."
                          : "Upload${scannedItems.isEmpty ? '' : ' (${scannedItems.length})'}",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm + 1),
                      ),
                    ),
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
