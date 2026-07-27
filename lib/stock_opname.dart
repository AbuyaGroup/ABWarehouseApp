import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StockOpname extends StatefulWidget {
  const StockOpname({super.key});

  @override
  State<StockOpname> createState() => _StockOpnameState();
}

class _StockOpnameState extends State<StockOpname> {
  final supabase = Supabase.instance.client;
  final AudioPlayer player = AudioPlayer();
  final MobileScannerController controller = MobileScannerController();

  bool canScan = true;
  bool isLoading = true;
  String? namaUser;
  String? role; // 'admin' atau 'user'

  List<Map<String, dynamic>> dcList = [];
  String? selectedDcId;
  String? selectedZona;
  Map<String, dynamic>? activeSession;
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
    if (selectedDcId != null) await loadActiveSession();
    setState(() => isLoading = false);
  }

  Future<void> loadProfile() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final data = await supabase.from('profiles').select().eq('id', uid).maybeSingle();
    namaUser = data?['nama'] ?? supabase.auth.currentUser?.email ?? 'User';
    role = data?['role'] ?? 'user';
    if (role != 'admin') {
      selectedDcId = data?['dc_id'];
    }
  }

  Future<void> loadDcs() async {
    final data = await supabase.from('dcs').select().order('urutan');
    dcList = List<Map<String, dynamic>>.from(data);
  }

  Future<void> loadActiveSession() async {
    if (selectedDcId == null) return;
    try {
      final data = await supabase
          .from('opname_sessions')
          .select()
          .eq('dc_id', selectedDcId!)
          .eq('status', 'aktif')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      activeSession = data;
    } catch (e) {
      debugPrint("Gagal load sesi aktif: $e");
    }
    scannedItems.clear();
  }

  Future<void> pilihDc(String dcId) async {
    setState(() { selectedDcId = dcId; selectedZona = null; isLoading = true; });
    await loadActiveSession();
    setState(() => isLoading = false);
  }

  void pilihZona(String zona) {
    setState(() {
      selectedZona = zona;
      scannedItems.clear();
    });
  }

  static const List<String> zonaOptions = [
    'A','B','C','D','E','F','G','H','I','J','K','L','M',
    'N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
  ];

  Future<void> scanBarcode(String code) async {
    if (selectedDcId == null || activeSession == null || selectedZona == null) return;

    try {
      final item = await supabase
          .from('produk')
          .select('id, nama, satuan, barcode, zona, sector')
          .eq('dc_id', selectedDcId!)
          .eq('barcode', code)
          .maybeSingle();

      if (item == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Barcode $code belum terdaftar di DC ini")),
          );
        }
        return;
      }

      final produkId = item['id'] as String;
      final sessionId = activeSession!['id'] as String;

      final existingEntry = await supabase
          .from('opname_entries')
          .select()
          .eq('session_id', sessionId)
          .eq('produk_id', produkId)
          .maybeSingle();

      await player.play(AssetSource("beep.mp3"));

      if (!mounted) return;
      final hasil = await showQtyDialog(
        namaItem: item['nama'] ?? 'Unknown',
        satuan: item['satuan'] ?? '',
        qtyAwal: existingEntry?['qty_fisik'],
        sectorAwal: item['sector'],
      );

      if (hasil == null) return; // dibatalin

      final entryPayload = {
        'session_id': sessionId,
        'produk_id': produkId,
        'qty_fisik': hasil['qty'],
        'catatan': existingEntry?['catatan'],
        'updated_by': namaUser,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await supabase.from('opname_entries').upsert(
        entryPayload, onConflict: 'session_id,produk_id',
      );

      // Zona dari pilihan di awal (level app), Sector dari popup barusan.
      // Disimpen permanen di tabel produk, biar web otomatis kegroup.
      final produkUpdate = <String, dynamic>{'zona': selectedZona};
      if (hasil['sector'] != null) produkUpdate['sector'] = hasil['sector'];
      await supabase.from('produk').update(produkUpdate).eq('id', produkId);
      final itemTampil = {...item, ...produkUpdate};

      setState(() {
        scannedItems[produkId] = {'item': itemTampil, 'entry': entryPayload};
      });
    } catch (e) {
      debugPrint("Gagal proses scan: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal sync ke server: $e")),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> showQtyDialog({
    required String namaItem,
    required String satuan,
    num? qtyAwal,
    String? sectorAwal,
  }) {
    final qtyCtrl = TextEditingController(text: qtyAwal != null ? qtyAwal.toString() : '');
    final sectorCtrl = TextEditingController(text: sectorAwal ?? '');

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(namaItem),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(labelText: "Qty Fisik", suffixText: satuan),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: sectorCtrl,
              decoration: const InputDecoration(labelText: "Sector"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () {
              final val = num.tryParse(qtyCtrl.text.trim());
              Navigator.pop(context, {
                'qty': val ?? 0,
                'sector': sectorCtrl.text.trim().isEmpty ? null : sectorCtrl.text.trim(),
              });
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
    if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Admin belum pilih DC -> tampilin pilihan DC dulu
    if (role == 'admin' && selectedDcId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Pilih DC"),
          actions: [IconButton(icon: const Icon(Icons.logout), onPressed: logout)],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: dcList.map((dc) => Card(
            child: ListTile(
              title: Text(dc['nama'] ?? ''),
              subtitle: Text(dc['sub'] ?? ''),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => pilihDc(dc['id']),
            ),
          )).toList(),
        ),
      );
    }

    final dcNama = dcList.firstWhere(
      (d) => d['id'] == selectedDcId,
      orElse: () => {'nama': selectedDcId},
    )['nama'];

    // DC udah dipilih tapi Zona belum -> tampilin pilihan Zona dulu
    if (selectedZona == null) {
      return PopScope(
        canPop: role != 'admin',
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (role == 'admin') setState(() => selectedDcId = null);
        },
        child: Scaffold(
        appBar: AppBar(
          title: Text("$dcNama · Pilih Zona"),
          leading: role == 'admin'
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => selectedDcId = null),
                )
              : null,
          actions: [IconButton(icon: const Icon(Icons.logout), onPressed: logout)],
        ),
        body: GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: zonaOptions.map((z) => InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => pilihZona(z),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xffF4F6FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xffDDE3EC)),
              ),
              alignment: Alignment.center,
              child: Text(z, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xff174A93))),
            ),
          )).toList(),
        ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() => selectedZona = null);
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text("$dcNama · Zona $selectedZona · ${namaUser ?? 'User'}"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => selectedZona = null),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.grid_view),
            tooltip: 'Ganti Zona',
            onPressed: () => setState(() => selectedZona = null),
          ),
          if (role == 'admin')
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Ganti DC',
              onPressed: () => setState(() { selectedDcId = null; selectedZona = null; }),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () async {
            setState(() => isLoading = true);
            await loadActiveSession();
            setState(() => isLoading = false);
          }),
          IconButton(icon: const Icon(Icons.logout), onPressed: logout),
        ],
      ),
      body: activeSession == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Belum ada sesi opname aktif buat DC ini.\nBuka web opname & bikin sesi dulu, terus tekan refresh di sini.",
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
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
                      ? const Center(child: Text("Belum ada item di-scan"))
                      : ListView(
                          children: scannedItems.entries.map((e) {
                            final item = e.value['item'] as Map<String, dynamic>;
                            final entry = e.value['entry'] as Map<String, dynamic>;
                            final qtyFisik = entry['qty_fisik'] ?? 0;
                            return Card(
                              child: ListTile(
                                title: Text(item['nama'] ?? "Unknown"),
                                subtitle: Text(item['satuan'] ?? ""),
                                trailing: Text("$qtyFisik", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            );
                          }).toList(),
                        ),
                )
              ],
            ),
      ),
    );
  }
}
