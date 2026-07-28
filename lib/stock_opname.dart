import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Halaman history: nampilin sesi-sesi Stock Opname yang pernah/lagi
/// jalan per DC, dan detail item yang udah discan di tiap sesi.
class StockOpname extends StatefulWidget {
  const StockOpname({super.key});

  @override
  State<StockOpname> createState() => _StockOpnameState();
}

class _StockOpnameState extends State<StockOpname> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  String? role;
  List<Map<String, dynamic>> dcList = [];
  String? selectedDcId;
  List<Map<String, dynamic>> sessionList = [];

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
    role = data?['role'] ?? 'scanner';
    if (role != 'admin') {
      selectedDcId = data?['dc_id'];
    }
  }

  Future<void> loadDcs() async {
    final data = await supabase.from('dcs').select().order('urutan');
    dcList = List<Map<String, dynamic>>.from(data);
  }

  /// Semua sesi (apapun statusnya -- aktif, selesai, dll) buat history.
  Future<void> loadSessions() async {
    if (selectedDcId == null) return;
    try {
      final data = await supabase
          .from('opname_sessions')
          .select()
          .eq('dc_id', selectedDcId!)
          .order('created_at', ascending: false);
      sessionList = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint("Gagal load history sesi: $e");
      sessionList = [];
    }
  }

  Future<void> pilihDc(String dcId) async {
    setState(() {
      selectedDcId = dcId;
      isLoading = true;
    });
    await loadSessions();
    if (mounted) setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Admin belum pilih DC -> tampilin pilihan DC dulu
    if (role == 'admin' && selectedDcId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Pilih DC")),
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

    return PopScope(
      canPop: role != 'admin',
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (role == 'admin') setState(() => selectedDcId = null);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("$dcNama · History Opname"),
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
                    "Belum ada riwayat sesi opname buat DC ini.",
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
                  final status = (sesi['status'] ?? '-').toString();
                  final tglRaw = (sesi['tanggal'] ?? sesi['created_at'])?.toString() ?? '';
                  final tgl = tglRaw.length >= 10 ? tglRaw.substring(0, 10) : tglRaw;
                  final isAktif = status == 'aktif';

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      leading: CircleAvatar(
                        backgroundColor:
                            isAktif ? const Color(0xff2E7D32) : const Color(0xff174A93),
                        child: const Icon(Icons.fact_check_outlined, color: Colors.white),
                      ),
                      title: Text(namaSesi,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text("Tanggal: $tgl · Status: $status"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SessionDetailPage(
                            sessionId: sesi['id'] as String,
                            sessionName: namaSesi,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Detail item-item yang udah discan dalam satu sesi opname.
class SessionDetailPage extends StatefulWidget {
  final String sessionId;
  final String sessionName;

  const SessionDetailPage({
    super.key,
    required this.sessionId,
    required this.sessionName,
  });

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => loadEntries());
  }

  Future<void> loadEntries() async {
    setState(() => isLoading = true);
    try {
      final entries = await supabase
          .from('opname_entries')
          .select()
          .eq('session_id', widget.sessionId)
          .order('updated_at', ascending: false);

      final entryList = List<Map<String, dynamic>>.from(entries);
      final produkIds = entryList
          .map((e) => e['produk_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      final produkMap = <String, Map<String, dynamic>>{};
      if (produkIds.isNotEmpty) {
        // NB: kalau versi supabase_flutter lo lebih lama, method filter "IN"
        // namanya .in_('id', produkIds) bukan .inFilter(...).
        final produkData = await supabase
            .from('produk')
            .select('id, nama, satuan, barcode, zona, sector')
            .inFilter('id', produkIds);
        for (final p in List<Map<String, dynamic>>.from(produkData)) {
          produkMap[p['id'] as String] = p;
        }
      }

      items = entryList.map((e) {
        final produk = produkMap[e['produk_id']] ?? <String, dynamic>{};
        return {...e, 'produk': produk};
      }).toList();
    } catch (e) {
      debugPrint("Gagal load detail sesi: $e");
      items = [];
    }
    if (mounted) setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sessionName),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: loadEntries),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(child: Text("Belum ada item discan di sesi ini"))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final e = items[index];
                    final produk = e['produk'] as Map<String, dynamic>;
                    final qty = e['qty_fisik'] ?? 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(produk['nama'] ?? 'Unknown'),
                        subtitle: Text(
                          "Barcode: ${produk['barcode'] ?? '-'} · "
                          "Zona ${produk['zona'] ?? '-'} / Sector ${produk['sector'] ?? '-'}\n"
                          "Update oleh: ${e['updated_by'] ?? '-'}",
                        ),
                        isThreeLine: true,
                        trailing: Text(
                          "$qty ${produk['satuan'] ?? ''}",
                          style:
                              const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
