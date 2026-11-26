import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:abwarehouse/scanner.dart';
import 'package:abwarehouse/app_theme.dart';
import 'package:abwarehouse/ui_kit.dart';
import 'package:abwarehouse/riwayat_page.dart';
import 'package:abwarehouse/akun_page.dart';

/// Beranda -- ngikutin design "New Design Scanner/Beranda".
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  int tab = 0; // 0 Beranda, 1 Riwayat, 2 Akun ("Pindai" = buka kamera)
  final _riwayatKey = GlobalKey<RiwayatPageState>();
  bool online = true;
  String namaUser = '';
  String? role;
  String dcNama = '';
  List<Map<String, dynamic>> sessions = [];

  /// session_id -> jumlah entri yang di-upload user ini.
  Map<String, int> entryCount = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final uid = supabase.auth.currentUser?.id;
      final profile = uid == null
          ? null
          : await supabase
                .from('profiles')
                .select()
                .eq('id', uid)
                .maybeSingle();
      namaUser =
          (profile?['nama'] ?? supabase.auth.currentUser?.email ?? 'User')
              .toString();
      role = profile?['role']?.toString();
      final dcId = profile?['dc_id'];

      final dcs = List<Map<String, dynamic>>.from(
        await supabase.from('dcs').select(),
      );
      final dcById = {
        for (final d in dcs) d['id']: (d['nama'] ?? '').toString(),
      };
      dcNama = role == 'admin' ? 'Admin' : (dcById[dcId] ?? '');

      var q = supabase.from('opname_sessions').select().eq('status', 'aktif');
      if (role != 'admin' && dcId != null) q = q.eq('dc_id', dcId);
      sessions = List<Map<String, dynamic>>.from(
        await q.order('created_at', ascending: false),
      );
      for (final s in sessions) {
        s['_dcNama'] = dcById[s['dc_id']] ?? '';
      }

      entryCount = {};
      if (uid != null && sessions.isNotEmpty) {
        final entries = await supabase
            .from('opname_entries')
            .select('session_id')
            .eq('updated_by', uid)
            .inFilter('session_id', sessions.map((s) => s['id']).toList());
        for (final e in entries) {
          final id = e['session_id'].toString();
          entryCount[id] = (entryCount[id] ?? 0) + 1;
        }
      }
      online = true;
    } catch (e) {
      debugPrint('Gagal load beranda: $e');
      online = false;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _openScanner([Map<String, dynamic>? sesi]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Scanner(initialSession: sesi)),
    );
    if (!mounted) return;
    _load();
    _riwayatKey.currentState?.load();
  }

  void _onNav(int i) {
    switch (i) {
      case 1:
        _openScanner(sessions.length == 1 ? sessions.first : null);
      case 2:
        setState(() => tab = 1);
      case 3:
        setState(() => tab = 2);
      default:
        setState(() => tab = 0);
    }
  }

  int get _totalEntri => entryCount.values.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: AppNavBar(
        onTap: _onNav,
        items: [
          (Icons.home_outlined, Icons.home, 'Beranda', tab == 0),
          (Icons.qr_code_scanner, Icons.qr_code_scanner, 'Pindai', false),
          (Icons.history, Icons.history, 'Riwayat', tab == 1),
          (Icons.person_outline, Icons.person, 'Akun', tab == 2),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: tab,
          children: [
            _beranda(),
            RiwayatPage(key: _riwayatKey, dcNama: dcNama),
            AkunPage(
              namaUser: namaUser,
              dcNama: dcNama,
              role: role,
              online: online,
            ),
          ],
        ),
      ),
    );
  }

  Widget _beranda() {
    return Column(
      children: [
        PageHeader(
          sub: dcNama,
          title: 'Halo, ${namaUser.isEmpty ? '...' : namaUser}!',
          online: online,
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _load,
            child: loading
                ? ListView(
                    children: const [
                      SizedBox(height: 160),
                      Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.md,
                      AppSpace.sm,
                      AppSpace.md,
                      AppSpace.lg,
                    ),
                    children: [
                      _heroCard(),
                      const SizedBox(height: AppSpace.lg),
                      _metrics(),
                      const SizedBox(height: AppSpace.lg),
                      _sessionList(),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  /// Kartu utama (bg primary) -- sesi aktif terbaru + tombol buka kamera.
  Widget _heroCard() {
    final sesi = sessions.isNotEmpty ? sessions.first : null;
    final n = sesi == null ? 0 : (entryCount[sesi['id'].toString()] ?? 0);
    final dc = sesi?['_dcNama']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dc.isEmpty ? 'Stock Opname' : 'Stock Opname · $dc',
                      style: AppText.labelSm(
                        color: AppColors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      (sesi?['nama'] ?? 'Belum ada sesi aktif').toString(),
                      style: AppText.headlineMd(color: AppColors.onPrimary),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      sesi == null
                          ? 'Minta admin bikin sesi opname dulu'
                          : '$n item udah kamu unggah',
                      style: AppText.bodySm(
                        color: AppColors.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  size: 24,
                  color: AppColors.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          AppButton(
            label: 'Buka Kamera Pemindai',
            icon: Icons.qr_code_scanner,
            variant: AppButtonVariant.surface,
            // 1 sesi -> langsung kamera; lebih -> biar Scanner yang nanya.
            onPressed: () =>
                _openScanner(sessions.length == 1 ? sessions.first : null),
          ),
        ],
      ),
    );
  }

  Widget _metrics() {
    Widget tile(String label, String value, String unit) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.bodySm()),
            const SizedBox(height: AppSpace.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: AppText.displayMobile()),
                const SizedBox(width: 6),
                Text(unit, style: AppText.bodySm()),
              ],
            ),
          ],
        ),
      ),
    );

    return Row(
      children: [
        tile('Sesi Aktif', '${sessions.length}', 'sesi'),
        const SizedBox(width: AppSpace.sm),
        tile('Total Terunggah', '$_totalEntri', 'item'),
      ],
    );
  }

  Widget _sessionList() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: Text('Sesi Opname Aktif', style: AppText.titleMd())),
          Text(
            '${sessions.length} sesi',
            style: AppText.labelSm(color: AppColors.primary),
          ),
        ],
      ),
      const SizedBox(height: AppSpace.sm),
      if (sessions.isEmpty)
        Container(
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Text(
            online
                ? 'Belum ada sesi opname aktif.\nTarik ke bawah buat refresh.'
                : 'Gagal memuat data. Tarik ke bawah buat coba lagi.',
            textAlign: TextAlign.center,
            style: AppText.bodyMd(color: AppColors.onSurfaceVariant),
          ),
        )
      else
        for (final s in sessions) _sessionCard(s),
    ],
  );

  Widget _sessionCard(Map<String, dynamic> s) {
    final n = entryCount[s['id'].toString()] ?? 0;
    final d = AppDate.parse(s['tanggal'] ?? s['created_at']);
    // `tanggal` cuma tanggal (jam-nya 00:00) -- jam ambil dari created_at.
    final dibuat = AppDate.parse(s['created_at']);
    final dc = s['_dcNama'].toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Material(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => _openScanner(s),
          child: Ink(
            padding: const EdgeInsets.all(AppSpace.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadow.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        d == null ? '-' : AppDate.tanggal(d),
                        style: AppText.monoSm(),
                      ),
                    ),
                    CountBadge('$n item', muted: n == 0),
                  ],
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  (s['nama'] ?? 'Sesi Opname').toString(),
                  style: AppText.titleMd(),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  [
                    if (dc.isNotEmpty) dc,
                    if (dibuat != null) 'dibuat pukul ${AppDate.jam(dibuat)}',
                  ].join(' · '),
                  style: AppText.bodySm(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
