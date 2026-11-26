import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:abwarehouse/app_theme.dart';
import 'package:abwarehouse/ui_kit.dart';

/// Riwayat -- daftar item yang udah diunggah user ini (terbaru di atas).
class RiwayatPage extends StatefulWidget {
  const RiwayatPage({super.key, required this.dcNama});

  final String dcNama;

  @override
  State<RiwayatPage> createState() => RiwayatPageState();
}

class RiwayatPageState extends State<RiwayatPage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  bool online = true;
  List<Map<String, dynamic>> entries = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  /// Ambil nama dari tabel lain; kalau gagal (RLS dll) cukup kosong aja.
  Future<Map<String, String>> _names(
    String table,
    String key,
    Iterable<dynamic> ids,
  ) async {
    if (ids.isEmpty) return {};
    try {
      final rows = await supabase
          .from(table)
          .select('$key, nama')
          .inFilter(key, ids.toSet().toList());
      return {
        for (final r in rows) r[key].toString(): (r['nama'] ?? '').toString(),
      };
    } catch (e) {
      debugPrint('Gagal ambil nama $table: $e');
      return {};
    }
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;
      final rows = List<Map<String, dynamic>>.from(
        await supabase
            .from('opname_entries')
            .select('session_id, barcode, sector_id, qty_fisik, updated_at')
            .eq('updated_by', uid)
            .order('updated_at', ascending: false)
            .limit(100),
      );

      final produk = await _names(
        'master_produk',
        'barcode',
        rows.map((r) => r['barcode']),
      );
      final sectors = await _names(
        'sectors',
        'id',
        rows.map((r) => r['sector_id']),
      );
      final sesi = await _names(
        'opname_sessions',
        'id',
        rows.map((r) => r['session_id']),
      );

      for (final r in rows) {
        r['_produk'] = produk[r['barcode'].toString()];
        r['_sector'] = sectors[r['sector_id'].toString()];
        r['_sesi'] = sesi[r['session_id'].toString()];
      }
      entries = rows;
      online = true;
    } catch (e) {
      debugPrint('Gagal load riwayat: $e');
      online = false;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PageHeader(sub: widget.dcNama, title: 'Riwayat', online: online),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.md,
                AppSpace.sm,
                AppSpace.md,
                AppSpace.lg,
              ),
              children: [
                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 160),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Item yang Kamu Unggah',
                          style: AppText.titleMd(),
                        ),
                      ),
                      Text('${entries.length} item', style: AppText.labelSm()),
                    ],
                  ),
                  const SizedBox(height: AppSpace.sm),
                  if (entries.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(AppSpace.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Text(
                        online
                            ? 'Belum ada item yang kamu unggah.'
                            : 'Gagal memuat riwayat. Tarik ke bawah buat coba lagi.',
                        textAlign: TextAlign.center,
                        style: AppText.bodyMd(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpace.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < entries.length; i++) ...[
                            if (i > 0)
                              Container(
                                height: 1,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: AppSpace.md,
                                ),
                                color: AppColors.outlineVariant.withValues(
                                  alpha: .6,
                                ),
                              ),
                            _row(entries[i]),
                          ],
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(Map<String, dynamic> e) {
    final d = AppDate.parse(e['updated_at']);
    final qty = e['qty_fisik'];
    final meta = [
      if ((e['_sector'] ?? '').toString().isNotEmpty) 'Sector ${e['_sector']}',
      if ((e['_sesi'] ?? '').toString().isNotEmpty) e['_sesi'],
      if (d != null) '${AppDate.tanggal(d)} ${AppDate.jam(d)}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (e['_produk'] ?? e['barcode']).toString(),
                  style: AppText.titleMd(),
                ),
                Text(meta, style: AppText.bodySm()),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Text(
            qty is num && qty == qty.roundToDouble()
                ? qty.toInt().toString()
                : '$qty',
            style: AppText.monoSm(color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}
