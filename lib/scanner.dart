import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fitur utama: scan produk fisik per DC.
/// Alur: pilih DC (admin) -> pilih sesi opname aktif -> scan -> upload.
/// Hasil scan cuma numpuk di device dulu (barcode + qty), baru beneran
/// kekirim ke opname_entries pas tombol Upload dipencet. Zona/sector
/// produk ditentuin belakangan (bukan bagian dari alur scan ini lagi).
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
  // Key = barcode, value = {'product': {...master_produk...}, 'qty': int}
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

  /// Scan barcode -> cari di master_produk (atau pake yang udah ada di
  /// batch ini) -> munculin dialog buat isi/edit qty.
  Future<void> scanBarcode(String code) async {
    if (selectedSession == null) return;

    Map<String, dynamic> product;
    num? qtyAwal;

    if (scannedItems.containsKey(code)) {
      // Udah pernah discan di batch ini -> buka dialog buat edit qty-nya
      product = scannedItems[code]!['product'] as Map<String, dynamic>;
      qtyAwal = scannedItems[code]!['qty'] as num;
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
      } catch (e) {
        debugPrint("Gagal cari produk: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Gagal cek barcode: $e")),
          );
        }
        return;
      }
    }

    await player.play(AssetSource("beep.mp3"));
    if (!mounted) return;

    final hasil = await showQtyDialog(
      namaItem: product['nama'] ?? 'Unknown',
      satuan: product['satuan'] ?? '',
      qtyAwal: qtyAwal,
    );

    if (hasil == null) return; // dibatalin, gak ada perubahan

    setState(() {
      if (hasil <= 0) {
        scannedItems.remove(code);
      } else {
        scannedItems[code] = {'product': product, 'qty': hasil};
      }
    });
  }

  /// Buka dialog qty buat produk yang udah ada di list, tanpa perlu scan ulang.
  Future<void> editQty(String barcode) async {
    final current = scannedItems[barcode];
    if (current == null) return;
    final product = current['product'] as Map<String, dynamic>;

    final hasil = await showQtyDialog(
      namaItem: product['nama'] ?? 'Unknown',
      satuan: product['satuan'] ?? '',
      qtyAwal: current['qty'] as num,
    );

    if (hasil == null) return;

    setState(() {
      if (hasil <= 0) {
        scannedItems.remove(barcode);
      } else {
        current['qty'] = hasil;
      }
    });
  }

  /// Hapus item dari list hasil scan (dengan konfirmasi dulu).
  Future<void> hapusItem(String barcode) async {
    final current = scannedItems[barcode];
    if (current == null) return;
    final product = current['product'] as Map<String, dynamic>;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Hapus Item"),
        content: Text("Hapus \"${product['nama'] ?? barcode}\" dari list scan ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => scannedItems.remove(barcode));
    }
  }

  Future<num?> showQtyDialog({
    required String namaItem,
    required String satuan,
    num? qtyAwal,
  }) {
    final qtyCtrl =
        TextEditingController(text: qtyAwal != null ? qtyAwal.toString() : '');

    return showDialog<num>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(namaItem),
        content: TextField(
          controller: qtyCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(labelText: "Qty Fisik", suffixText: satuan),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              final val = num.tryParse(qtyCtrl.text.trim()) ?? qtyAwal ?? 1;
              Navigator.pop(context, val);
            },
            child: const Text("Simpan"),
          ),
        ],
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
      final payload = scannedItems.entries.map((e) {
        return {
          'session_id': sessionId,
          'barcode': e.key,
          'qty_fisik': e.value['qty'],
          'updated_by': uid, // UUID akun yang login, sesuai FK profiles(id)
          'updated_at': DateTime.now().toIso8601String(),
        };
      }).toList();

      await supabase.from('opname_entries').insert(payload);

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
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xff174A93),
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
                  await scanBarcode(code);
                  await Future.delayed(const Duration(milliseconds: 700));
                  canScan = true;
                },
              ),
            ),
            Expanded(
              flex: 5,
              child: scannedItems.isEmpty
                  ? const Center(child: Text("Mulai scan barcode barang..."))
                  : ListView(
                      children: scannedItems.entries.map((e) {
                        final barcode = e.key;
                        final product = e.value['product'] as Map<String, dynamic>;
                        final qty = e.value['qty'];

                        return Card(
                          margin:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            onTap: () => editQty(barcode),
                            title: Text(product['nama'] ?? "Unknown"),
                            subtitle: Text(
                              "${product['satuan'] ?? ''} · Barcode: $barcode",
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xffF4F6FA),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "$qty",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      size: 20, color: Color(0xff174A93)),
                                  onPressed: () => editQty(barcode),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 20, color: Colors.red),
                                  onPressed: () => hapusItem(barcode),
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
                      backgroundColor: const Color(0xff174A93),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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
