import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:abwarehouse/app_theme.dart';
import 'package:abwarehouse/ui_kit.dart';

class Scanner extends StatefulWidget {
  const Scanner({super.key, this.initialSession});

  /// Kalau diisi (dari Beranda), langsung masuk kamera buat sesi ini
  /// tanpa lewat layar pilih sesi.
  final Map<String, dynamic>? initialSession;

  @override
  State<Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<Scanner> {
  final supabase = Supabase.instance.client;
  final AudioPlayer player = AudioPlayer();
  final MobileScannerController controller = MobileScannerController();

  static const _hintDefault = 'Arahkan ke QR atau Barcode label';

  bool canScan = true;
  bool isLoading = true;
  bool isUploading = false;
  bool online = true;
  String? namaUser;
  String? role;

  List<Map<String, dynamic>> dcList = [];
  String? selectedDcId;

  List<Map<String, dynamic>> sessionList = [];
  Map<String, dynamic>? selectedSession;

  /// key = "barcode|sectorId"
  final Map<String, Map<String, dynamic>> scannedItems = {};

  /// Item hasil scan yang lagi ditampilin di bottom sheet, belum disimpan.
  /// {barcode, product, sectorOptions, sectorId, qty, scannedAt}
  Map<String, dynamic>? pending;
  bool lookingUp = false;
  String hint = _hintDefault;

  bool soundOn = true;
  bool zoomed = false;
  bool summaryOpen = false;
  String? lastSavedKey;
  DateTime? lastSavedAt;

  @override
  void initState() {
    super.initState();
    player.setReleaseMode(ReleaseMode.stop);
    WidgetsBinding.instance.addPostFrameCallback((_) => init());
  }

  @override
  void dispose() {
    player.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> _playBeep() async {
    if (!soundOn) return;
    try {
      await player.stop();
      await player.play(AssetSource('jokowi-kaget.mp3'), volume: 1.0);
    } catch (e) {
      debugPrint("Gagal muter suara: $e");
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // ------------------------------------------------------------------ data

  Future<void> init() async {
    setState(() => isLoading = true);
    try {
      await loadProfile();
      await loadDcs();
      if (selectedDcId != null) await loadSessions();
      online = true;
    } catch (e) {
      debugPrint("Gagal init scanner: $e");
      online = false;
      _snack("Gagal memuat data: $e");
    }
    if (widget.initialSession != null) {
      selectedSession = widget.initialSession;
      // Admin gak punya dc_id di profil -- ambil dari sesinya.
      selectedDcId ??= widget.initialSession!['dc_id']?.toString();
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> loadProfile() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final data = await supabase
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
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
      online = true;
    } catch (e) {
      debugPrint("Gagal load sesi: $e");
      sessionList = [];
      online = false;
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
      pending = null;
      hint = _hintDefault;
      lastSavedKey = null;
      lastSavedAt = null;
    });
  }

  List<MapEntry<String, Map<String, dynamic>>> _findExistingByBarcode(
    String barcode,
  ) {
    return scannedItems.entries
        .where((e) => e.value['barcode'] == barcode)
        .toList();
  }

  /// Cari produk + sector-nya, terus taro di bottom sheet (pending).
  Future<void> scanBarcode(String code, {bool fromCamera = true}) async {
    if (selectedSession == null || pending != null || lookingUp) return;

    if (fromCamera) _playBeep();

    final existingEntries = _findExistingByBarcode(code);

    Map<String, dynamic> product;
    List<Map<String, dynamic>> sectorOptions;

    if (existingEntries.isNotEmpty) {
      product = existingEntries.first.value['product'] as Map<String, dynamic>;
      sectorOptions =
          existingEntries.first.value['sectorOptions']
              as List<Map<String, dynamic>>;
    } else {
      setState(() {
        lookingUp = true;
        hint = 'Mencari produk $code...';
      });
      try {
        final data = await supabase
            .from('master_produk')
            .select('barcode, nama, satuan')
            .eq('barcode', code)
            .maybeSingle();

        if (data == null) {
          _snack("Barcode $code gak ketemu di Master Produk");
          return;
        }
        product = data;

        final psData = await supabase
            .from('produk_sectors')
            .select('sector_id, sectors(nama, zone_id, zones(nama))')
            .eq('barcode', code);

        sectorOptions = List<Map<String, dynamic>>.from(psData).map((ps) {
          final sector = ps['sectors'] as Map<String, dynamic>?;
          final zone = sector?['zones'] as Map<String, dynamic>?;
          String? clean(dynamic v) {
            final t = v?.toString().trim() ?? '';
            return t.isEmpty ? null : t;
          }

          final zonaNama = clean(zone?['nama']);
          // Format: "Zona I - I001" (I001 = nama sector).
          final parts = [
            if (zonaNama != null) 'Zona $zonaNama',
            ?clean(sector?['nama']),
          ];
          return <String, dynamic>{
            'sectorId': ps['sector_id'].toString(),
            'label': parts.isEmpty
                ? (ps['sector_id']?.toString() ?? '-')
                : parts.join(' - '),
          };
        }).toList();
        online = true;

        if (sectorOptions.isEmpty) {
          _snack(
            "Produk ini belum di-assign ke sector manapun. Hubungi admin.",
          );
          return;
        }
      } catch (e) {
        debugPrint("Gagal cari produk/sector: $e");
        online = false;
        _snack("Gagal cek barcode: $e");
        return;
      } finally {
        if (mounted) {
          setState(() {
            lookingUp = false;
            if (pending == null) hint = _hintDefault;
          });
        }
      }
    }

    if (!mounted) return;

    final usedSectorIds = existingEntries
        .map((e) => e.value['sectorId'] as String)
        .toSet();

    final sectorTerpilih = sectorOptions.firstWhere(
      (s) => !usedSectorIds.contains(s['sectorId']),
      orElse: () => sectorOptions.first,
    );
    final preselectedSectorId = sectorTerpilih['sectorId'] as String;
    final qtyAwal = scannedItems['$code|$preselectedSectorId']?['qty'] as num?;

    setState(() {
      pending = {
        'barcode': code,
        'product': product,
        'sectorOptions': sectorOptions,
        'sectorId': preselectedSectorId,
        'qty': qtyAwal ?? 1,
        'scannedAt': DateTime.now(),
      };
      hint = 'Cek jumlahnya, terus tekan Simpan';
    });
  }

  String _sectorLabel(List<Map<String, dynamic>> options, String sectorId) =>
      options.firstWhere((s) => s['sectorId'] == sectorId)['label'] as String;

  void savePending() {
    final p = pending;
    if (p == null) return;
    final code = p['barcode'] as String;
    final sectorId = p['sectorId'] as String;
    final qty = p['qty'] as num;
    final key = '$code|$sectorId';
    final options = p['sectorOptions'] as List<Map<String, dynamic>>;

    setState(() {
      if (qty <= 0) {
        scannedItems.remove(key);
      } else {
        scannedItems[key] = {
          'barcode': code,
          'product': p['product'],
          'sectorOptions': options,
          'sectorId': sectorId,
          'sectorLabel': _sectorLabel(options, sectorId),
          'qty': qty,
        };
        lastSavedKey = key;
        lastSavedAt = DateTime.now();
      }
      pending = null;
      hint = 'Tersimpan! Siap pindai item berikutnya';
    });
  }

  void discardPending() => setState(() {
    pending = null;
    hint = _hintDefault;
  });

  Future<void> editItem(String key) async {
    final current = scannedItems[key];
    if (current == null) return;

    final product = current['product'] as Map<String, dynamic>;
    final sectorOptions =
        current['sectorOptions'] as List<Map<String, dynamic>>;
    final barcode = current['barcode'] as String;

    final hasil = await showScanDialog(
      namaItem: product['nama'] ?? 'Unknown',
      satuan: product['satuan'] ?? '',
      sectorOptions: sectorOptions,
      preselectedSectorId: current['sectorId'] as String,
      qtyAwal: current['qty'] as num,
    );

    if (hasil == null || !mounted) return;

    final sectorId = hasil['sectorId'] as String;
    final qty = hasil['qty'] as num;
    final newKey = '$barcode|$sectorId';
    final sectorLabel = _sectorLabel(sectorOptions, sectorId);

    if (newKey != key && scannedItems.containsKey(newKey)) {
      final overwrite = await showConfirmDialog(
        context,
        title: "Sector Ini Udah Ada Entry-nya",
        message:
            "Lokasi $sectorLabel buat produk ini udah ada entry lain "
            "(qty ${scannedItems[newKey]!['qty']}). Timpa dengan qty $qty?",
        confirmLabel: "Timpa",
      );
      if (!overwrite) return;
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
      if (lastSavedKey == key) lastSavedKey = newKey;
    });
  }

  Future<void> hapusItem(String key) async {
    final current = scannedItems[key];
    if (current == null) return;
    final product = current['product'] as Map<String, dynamic>;
    final sectorLabel = current['sectorLabel'] as String;

    final confirmed = await showConfirmDialog(
      context,
      title: "Hapus Item",
      message:
          "Hapus \"${product['nama'] ?? current['barcode']}\" ($sectorLabel) dari list scan ini?",
      confirmLabel: "Hapus",
      destructive: true,
    );

    if (confirmed) {
      setState(() {
        scannedItems.remove(key);
        if (lastSavedKey == key) lastSavedKey = null;
      });
    }
  }

  /// Dialog edit item (dipake dari layar Ringkasan).
  Future<Map<String, dynamic>?> showScanDialog({
    required String namaItem,
    required String satuan,
    required List<Map<String, dynamic>> sectorOptions,
    required String preselectedSectorId,
    num? qtyAwal,
  }) {
    final qtyCtrl = TextEditingController(
      text: qtyAwal != null ? _fmtQty(qtyAwal) : '',
    );
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
              Text("Sector", style: AppText.labelLg()),
              const SizedBox(height: AppSpace.xs),
              _SectorChips(
                options: sectorOptions,
                selectedId: selectedSectorId,
                onSelected: (val) =>
                    setDialogState(() => selectedSectorId = val),
              ),
              const SizedBox(height: AppSpace.md),
              Text("Jumlah fisik", style: AppText.labelLg()),
              const SizedBox(height: AppSpace.xs),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autofocus: true,
                style: AppText.monoMd(),
                decoration: InputDecoration(suffixText: satuan),
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

  /// Upload semua item. Return jumlah produk yang ke-upload (0 kalau gagal).
  Future<int> uploadEntries() async {
    if (selectedSession == null || scannedItems.isEmpty || isUploading) {
      return 0;
    }

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      _snack("Sesi login gak valid, coba login ulang");
      return 0;
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
          'updated_by': uid,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
      }).toList();

      await supabase
          .from('opname_entries')
          .upsert(payload, onConflict: 'session_id,barcode,sector_id');

      final jumlah = scannedItems.length;
      if (mounted) {
        setState(() {
          scannedItems.clear();
          lastSavedKey = null;
          online = true;
        });
      }
      return jumlah;
    } catch (e) {
      debugPrint("Gagal upload: $e");
      online = false;
      _snack("Gagal upload: $e");
      return 0;
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  Future<void> _openSummary() async {
    setState(() => summaryOpen = true);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SummaryPage(
          scanner: this,
          dcNama: _dcNama,
          namaSesi: (selectedSession?['nama'] ?? 'Sesi Opname').toString(),
        ),
      ),
    );
    if (mounted) setState(() => summaryOpen = false);
  }

  /// Keluar dari mode kamera. Kalau dibuka langsung dari Beranda, balik ke
  /// Beranda; kalau lewat list sesi, balik ke list sesi.
  void _exitScanning() {
    if (widget.initialSession != null) {
      Navigator.pop(context);
    } else {
      setState(() {
        selectedSession = null;
        pending = null;
      });
    }
  }

  Future<void> _confirmExitScanning() async {
    if (scannedItems.isEmpty) {
      _exitScanning();
      return;
    }
    final ok = await showConfirmDialog(
      context,
      title: "Belum di-upload",
      message:
          "Masih ada ${scannedItems.length} produk hasil scan yang belum "
          "di-upload. Yakin mau keluar? Data ini bakal ilang.",
      confirmLabel: "Keluar",
      destructive: true,
    );
    if (ok) _exitScanning();
  }

  Future<void> _manualInput() async {
    final ctrl = TextEditingController();
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.darkSurface.withValues(alpha: .6),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: AppSpace.md,
          right: AppSpace.md,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpace.md,
        ),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(AppSpace.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Input Kode Manual',
                        style: AppText.headlineMd(),
                      ),
                    ),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainerLow,
                      ),
                      tooltip: 'Tutup',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                Text('Nomor Barcode', style: AppText.labelLg()),
                const SizedBox(height: AppSpace.xs),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  style: AppText.monoMd(),
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Contoh: 8992761000012',
                  ),
                  onSubmitted: (v) => Navigator.pop(sheetContext, v.trim()),
                ),
                const SizedBox(height: AppSpace.md),
                AppButton(
                  label: 'Cari & Terapkan',
                  onPressed: () =>
                      Navigator.pop(sheetContext, ctrl.text.trim()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (code != null && code.isNotEmpty) {
      await scanBarcode(code, fromCamera: false);
    }
  }

  Future<void> _editPendingQty() async {
    final p = pending;
    if (p == null) return;
    final ctrl = TextEditingController(text: _fmtQty(p['qty'] as num));
    final val = await showDialog<num>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Jumlah fisik'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppText.monoMd(),
          decoration: InputDecoration(
            suffixText: ((p['product'] as Map)['satuan'] ?? '').toString(),
          ),
          onSubmitted: (v) =>
              Navigator.pop(dialogContext, num.tryParse(v.trim())),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, num.tryParse(ctrl.text.trim())),
            child: const Text('Oke'),
          ),
        ],
      ),
    );
    if (val != null && mounted && pending != null) {
      setState(() => pending!['qty'] = val < 0 ? 0 : val);
    }
  }

  String get _dcNama =>
      (dcList.firstWhere(
                (d) => d['id'] == selectedDcId,
                orElse: () => {'nama': selectedDcId},
              )['nama'] ??
              '-')
          .toString();

  // -------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (role == 'admin' && selectedDcId == null) {
      return _listScaffold(
        sub: 'Admin',
        title: 'Pilih DC untuk Scan',
        children: dcList
            .map(
              (dc) => _ListCard(
                icon: Icons.warehouse_outlined,
                title: (dc['nama'] ?? '').toString(),
                subtitle: (dc['sub'] ?? '').toString(),
                onTap: () => pilihDc(dc['id']),
              ),
            )
            .toList(),
      );
    }

    if (selectedSession == null) {
      return PopScope(
        canPop: role != 'admin',
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (role == 'admin') setState(() => selectedDcId = null);
        },
        child: _listScaffold(
          sub: _dcNama,
          title: 'Pilih Sesi Opname',
          onBack: role == 'admin'
              ? () => setState(() {
                  selectedDcId = null;
                  sessionList.clear();
                })
              : () => Navigator.pop(context),
          onRefresh: () async {
            setState(() => isLoading = true);
            await loadSessions();
            if (mounted) setState(() => isLoading = false);
          },
          children: sessionList.isEmpty
              ? [
                  Container(
                    padding: const EdgeInsets.all(AppSpace.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Text(
                      "Belum ada sesi opname aktif.\nSuruh admin bikin sesi dulu, terus refresh di sini.",
                      textAlign: TextAlign.center,
                      style: AppText.bodyMd(color: AppColors.onSurfaceVariant),
                    ),
                  ),
                ]
              : sessionList.map((sesi) {
                  final d = AppDate.parse(
                    sesi['tanggal'] ?? sesi['created_at'],
                  );
                  return _ListCard(
                    icon: Icons.inventory_2_outlined,
                    title: (sesi['nama'] ?? 'Sesi Opname').toString(),
                    subtitle: d == null ? '-' : AppDate.tanggal(d),
                    onTap: () => pilihSesi(sesi),
                  );
                }).toList(),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (pending != null) {
          discardPending();
        } else {
          _confirmExitScanning();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.darkSurface,
        body: Column(
          children: [
            Expanded(child: _cameraLayer()),
            _bottomSheet(),
          ],
        ),
      ),
    );
  }

  // ---------- list screens (admin DC + pilih sesi)

  Widget _listScaffold({
    required String sub,
    required String title,
    required List<Widget> children,
    VoidCallback? onBack,
    Future<void> Function()? onRefresh,
  }) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.md,
                AppSpace.lg,
                AppSpace.md,
                AppSpace.sm,
              ),
              child: Row(
                children: [
                  if (onBack != null) ...[
                    CircleIconButton(
                      icon: Icons.arrow_back,
                      tooltip: 'Kembali',
                      onPressed: onBack,
                    ),
                    const SizedBox(width: AppSpace.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sub, style: AppText.bodySm()),
                        Text(title, style: AppText.titleMd()),
                      ],
                    ),
                  ),
                  StatusPill(online: online),
                  if (onRefresh != null) ...[
                    const SizedBox(width: AppSpace.xs),
                    CircleIconButton(
                      icon: Icons.refresh,
                      tooltip: 'Muat ulang',
                      onPressed: onRefresh,
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.md,
                  AppSpace.sm,
                  AppSpace.md,
                  AppSpace.lg,
                ),
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- kamera

  Widget _cameraLayer() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: controller,
          onDetect: (capture) async {
            if (!canScan || summaryOpen || pending != null || lookingUp) return;
            if (capture.barcodes.isEmpty) return;
            final code = capture.barcodes.first.rawValue;
            if (code == null) return;

            canScan = false;
            try {
              await scanBarcode(code);
            } catch (e, st) {
              debugPrint("Error pas scanBarcode: $e\n$st");
              _snack("Gagal proses scan: $e");
            } finally {
              await Future.delayed(const Duration(milliseconds: 700));
              canScan = true;
            }
          },
        ),
        IgnorePointer(
          child: ColoredBox(
            color: AppColors.darkSurface.withValues(alpha: .35),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              _cameraTopBar(),
              Expanded(child: _reticle()),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.md,
                  0,
                  AppSpace.md,
                  AppSpace.md,
                ),
                child: Row(children: [_zoomButton()]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cameraTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.lg,
        AppSpace.md,
        AppSpace.sm,
      ),
      child: Row(
        children: [
          CircleIconButton(
            icon: Icons.arrow_back,
            tooltip: 'Kembali',
            onPressed: _confirmExitScanning,
          ),
          const SizedBox(width: AppSpace.sm),
          StatusPill(online: online, floating: true),
          const Spacer(),
          CircleIconButton(
            icon: soundOn ? Icons.volume_up : Icons.volume_off,
            tooltip: soundOn ? 'Matikan suara' : 'Nyalakan suara',
            onPressed: () => setState(() => soundOn = !soundOn),
          ),
          const SizedBox(width: AppSpace.sm),
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: controller,
            builder: (context, state, _) {
              final torch = state.torchState;
              final on = torch == TorchState.on;
              return CircleIconButton(
                icon: on ? Icons.flashlight_on : Icons.flashlight_off,
                tooltip: on ? 'Matikan lampu' : 'Nyalakan lampu',
                active: on,
                onPressed: torch == TorchState.unavailable
                    ? null
                    : () => controller.toggleTorch(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _reticle() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240, maxHeight: 240),
            child: AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                painter: _ReticlePainter(color: AppColors.primaryContainer),
                child: Center(
                  child: lookingUp
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : Container(
                          width: 40,
                          height: 2,
                          decoration: BoxDecoration(
                            color: AppColors.onPrimary.withValues(alpha: .7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceContainerLow.withValues(alpha: .9),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            hint,
            style: AppText.labelSm(color: AppColors.darkOnSurface),
          ),
        ),
      ],
    );
  }

  Widget _zoomButton() {
    return Material(
      color: AppColors.surfaceContainerLowest.withValues(alpha: .95),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () async {
          setState(() => zoomed = !zoomed);
          try {
            await controller.setZoomScale(zoomed ? 0.5 : 0.0);
          } catch (e) {
            debugPrint('Gagal zoom: $e');
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                zoomed ? Icons.zoom_out : Icons.zoom_in,
                size: 18,
                color: AppColors.onSurface,
              ),
              const SizedBox(width: 4),
              Text(
                zoomed ? 'Zoom' : 'Normal',
                style: AppText.monoSm(color: AppColors.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- bottom sheet

  Widget _bottomSheet() {
    final sesi = selectedSession!;
    final tgl = AppDate.parse(sesi['tanggal'] ?? sesi['created_at']);
    final p = pending;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        boxShadow: AppShadow.lg,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.md,
            AppSpace.sm,
            AppSpace.md,
            AppSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (sesi['nama'] ?? 'Sesi Opname').toString(),
                          style: AppText.monoSm(),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          tgl == null ? _dcNama : AppDate.tanggal(tgl),
                          style: AppText.titleMd(),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _openSummary,
                    child: CountBadge(
                      '${scannedItems.length} item',
                      muted: scannedItems.isEmpty,
                    ),
                  ),
                  if (p != null) ...[
                    const SizedBox(width: AppSpace.sm),
                    const SuccessBadge('Cocok'),
                  ],
                ],
              ),
              const SizedBox(height: AppSpace.md),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: const Cubic(0.2, 0, 0, 1),
                alignment: Alignment.topCenter,
                child: p == null ? _emptyItemCard() : _pendingCard(p),
              ),
              const SizedBox(height: AppSpace.md),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: p == null
                        ? AppButton(
                            label: 'Ketik Kode',
                            icon: Icons.keyboard,
                            variant: AppButtonVariant.tonal,
                            onPressed: lookingUp ? null : _manualInput,
                          )
                        : AppButton(
                            label: 'Batal',
                            icon: Icons.close,
                            variant: AppButtonVariant.tonal,
                            onPressed: discardPending,
                          ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    flex: 3,
                    child: p == null
                        ? AppButton(
                            label: 'Ringkasan & Unggah',
                            icon: Icons.list_alt,
                            onPressed: scannedItems.isEmpty
                                ? null
                                : _openSummary,
                          )
                        : AppButton(
                            label: 'Simpan & Lanjut',
                            icon: Icons.check,
                            onPressed: savePending,
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyItemCard() {
    final last = lastSavedKey != null ? scannedItems[lastSavedKey] : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: last == null
          ? Row(
              children: [
                const Icon(
                  Icons.qr_code_scanner,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    'Belum ada item. Arahkan kamera ke barcode atau ketik kodenya manual.',
                    style: AppText.bodySm(),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Terakhir disimpan', style: AppText.bodySm()),
                      Text(
                        ((last['product'] as Map)['nama'] ?? last['barcode'])
                            .toString(),
                        style: AppText.titleMd(),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${last['sectorLabel']}',
                        style: AppText.monoSm(),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_fmtQty(last['qty'] as num)} ${(last['product'] as Map)['satuan'] ?? ''}',
                  style: AppText.monoMd(color: AppColors.secondary),
                ),
              ],
            ),
    );
  }

  Widget _pendingCard(Map<String, dynamic> p) {
    final product = p['product'] as Map<String, dynamic>;
    final options = p['sectorOptions'] as List<Map<String, dynamic>>;
    final sectorId = p['sectorId'] as String;
    final qty = p['qty'] as num;
    final satuan = (product['satuan'] ?? '').toString();
    final sudahAda = scannedItems.containsKey('${p['barcode']}|$sectorId');

    Widget stepButton(IconData icon, String tooltip, VoidCallback? onTap) =>
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadow.sm,
          ),
          child: Material(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: onTap,
              child: Tooltip(
                message: tooltip,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    icon,
                    size: 20,
                    color: onTap == null
                        ? AppColors.outline
                        : AppColors.onSurface,
                  ),
                ),
              ),
            ),
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
                      (product['nama'] ?? 'Unknown').toString(),
                      style: AppText.titleMd(),
                    ),
                    Text(
                      options.length > 1
                          ? p['barcode'].toString()
                          : '${p['barcode']} · ${_sectorLabel(options, sectorId)}',
                      style: AppText.monoSm(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Text(
                'Terpindai ${AppDate.jam(p['scannedAt'] as DateTime)}',
                style: AppText.labelSm(color: AppColors.secondary),
              ),
            ],
          ),
          if (options.length > 1) ...[
            const SizedBox(height: AppSpace.sm),
            _SectorChips(
              options: options,
              selectedId: sectorId,
              onSelected: (val) => setState(() => p['sectorId'] = val),
            ),
          ],
          if (sudahAda) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              'Udah tercatat di sector ini -- jumlahnya bakal ditimpa.',
              style: AppText.bodySm(color: AppColors.primary),
            ),
          ],
          const SizedBox(height: AppSpace.xs),
          Row(
            children: [
              Expanded(child: Text('Jumlah fisik', style: AppText.bodySm())),
              stepButton(
                Icons.remove,
                'Kurangi jumlah',
                qty > 1 ? () => setState(() => p['qty'] = qty - 1) : null,
              ),
              const SizedBox(width: AppSpace.sm),
              GestureDetector(
                onTap: _editPendingQty,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 56),
                  child: Column(
                    children: [
                      Text(_fmtQty(qty), style: AppText.displayMobile()),
                      Text(
                        satuan.isEmpty ? 'unit' : satuan,
                        style: AppText.bodySm(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              stepButton(
                Icons.add,
                'Tambah jumlah',
                () => setState(() => p['qty'] = qty + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// Ringkasan (hasil pindai sesi ini + unggah)
// ======================================================================

class _SummaryPage extends StatefulWidget {
  const _SummaryPage({
    required this.scanner,
    required this.dcNama,
    required this.namaSesi,
  });

  final _ScannerState scanner;
  final String dcNama;
  final String namaSesi;

  @override
  State<_SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<_SummaryPage> {
  DateTime? uploadedAt;
  int uploadedCount = 0;

  _ScannerState get s => widget.scanner;

  Future<void> _run(Future<void> Function() action) async {
    await action();
    if (mounted) setState(() {});
  }

  Future<void> _upload() async {
    final pending = s.uploadEntries();
    setState(() {}); // biar spinner "Mengunggah..." langsung keliatan
    final n = await pending;
    if (!mounted) return;
    setState(() {
      if (n > 0) {
        uploadedCount = n;
        uploadedAt = DateTime.now();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = s.scannedItems.entries.toList().reversed.toList();
    final last = s.lastSavedKey != null ? s.scannedItems[s.lastSavedKey] : null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.md,
                AppSpace.lg,
                AppSpace.md,
                AppSpace.sm,
              ),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Kembali ke kamera pemindai',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.dcNama} · ${s.namaUser ?? ''}',
                          style: AppText.bodySm(),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text('Ringkasan Pindai', style: AppText.titleMd()),
                      ],
                    ),
                  ),
                  StatusPill(online: s.online),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.md,
                  AppSpace.sm,
                  AppSpace.md,
                  AppSpace.md,
                ),
                children: [
                  _banner(),
                  if (last != null) ...[
                    const SizedBox(height: AppSpace.md),
                    _lastItemCard(last),
                  ],
                  const SizedBox(height: AppSpace.md),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tercatat di Sesi Ini',
                          style: AppText.titleMd(),
                        ),
                      ),
                      Text('${items.length} item', style: AppText.labelSm()),
                    ],
                  ),
                  const SizedBox(height: AppSpace.sm),
                  if (items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(AppSpace.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Text(
                        uploadedAt != null
                            ? 'Semua item udah diunggah. Lanjut pindai lagi kuy!'
                            : 'Belum ada item yang dipindai.',
                        textAlign: TextAlign.center,
                        style: AppText.bodySm(),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpace.xs,
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < items.length; i++) ...[
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
                            _itemRow(items[i].key, items[i].value),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.md,
                AppSpace.sm,
                AppSpace.md,
                AppSpace.lg,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(
                    color: AppColors.outlineVariant.withValues(alpha: .5),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(
                    label: 'Pindai Item Berikutnya',
                    icon: Icons.qr_code_scanner,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  AppButton(
                    label: s.isUploading
                        ? 'Mengunggah...'
                        : 'Unggah${items.isEmpty ? '' : ' (${items.length})'}',
                    icon: Icons.cloud_upload_outlined,
                    variant: AppButtonVariant.secondary,
                    loading: s.isUploading,
                    onPressed: items.isEmpty ? null : _upload,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _banner() {
    final uploaded = uploadedAt != null && s.scannedItems.isEmpty;
    final (bg, fg, iconBg, icon, title, sub) = uploaded
        ? (
            AppColors.secondaryContainer,
            AppColors.onSecondaryContainer,
            AppColors.secondary,
            Icons.check_circle,
            'Data Berhasil Diunggah',
            '$uploadedCount produk · ${AppDate.tanggal(uploadedAt!)} · pukul ${AppDate.jam(uploadedAt!)}',
          )
        : (
            AppColors.surfaceContainerHigh,
            AppColors.onSurface,
            AppColors.primary,
            Icons.cloud_upload,
            s.scannedItems.isEmpty ? 'Belum Ada Data' : 'Siap Diunggah',
            s.scannedItems.isEmpty
                ? widget.namaSesi
                : '${s.scannedItems.length} produk di ${widget.namaSesi}'
                      '${s.lastSavedAt != null ? ' · terakhir ${AppDate.jam(s.lastSavedAt!)}' : ''}',
          );

    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 22, color: AppColors.onPrimary),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.titleMd(color: fg)),
                const SizedBox(height: 2),
                Text(sub, style: AppText.bodySm(color: fg)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lastItemCard(Map<String, dynamic> item) {
    final product = item['product'] as Map;
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
                      '${item['barcode']} · ${item['sectorLabel']}',
                      style: AppText.monoSm(),
                    ),
                    Text(
                      (product['nama'] ?? 'Unknown').toString(),
                      style: AppText.headlineMd(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              const SuccessBadge('Cocok'),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Container(
            height: 1,
            color: AppColors.outlineVariant.withValues(alpha: .5),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Jumlah Terpindai', style: AppText.bodySm()),
                    Text(
                      '${_fmtQty(item['qty'] as num)} ${product['satuan'] ?? ''}',
                      style: AppText.displayMobile(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total di Sesi Ini', style: AppText.bodySm()),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        CountBadge('${s.scannedItems.length}'),
                        const SizedBox(width: AppSpace.xs),
                        Text('Item', style: AppText.bodySm()),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemRow(String key, Map<String, dynamic> item) {
    final product = item['product'] as Map;
    final isLast = key == s.lastSavedKey;
    return InkWell(
      onTap: () => _run(() => s.editItem(key)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          AppSpace.sm,
          AppSpace.xs,
          AppSpace.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (product['nama'] ?? 'Unknown').toString(),
                    style: AppText.titleMd(),
                  ),
                  Text(
                    '${item['sectorLabel']} · ${item['barcode']}',
                    style: AppText.bodySm(),
                  ),
                ],
              ),
            ),
            Text(
              '${_fmtQty(item['qty'] as num)} ${product['satuan'] ?? ''}',
              style: AppText.monoSm(
                color: isLast
                    ? AppColors.secondary
                    : AppColors.onSurfaceVariant,
              ),
            ),
            IconButton(
              tooltip: 'Hapus',
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: AppColors.error,
              ),
              onPressed: () => _run(() => s.hapusItem(key)),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// Widget kecil
// ======================================================================

/// Pilihan sector (kalau produk ada di lebih dari 1 sector).
class _SectorChips extends StatelessWidget {
  const _SectorChips({
    required this.options,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Map<String, dynamic>> options;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpace.xs,
      runSpacing: AppSpace.xs,
      children: options.map((s) {
        final id = s['sectorId'] as String;
        final selected = id == selectedId;
        return Material(
          color: selected
              ? AppColors.primary
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onSelected(id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: selected
                        ? AppColors.onPrimary
                        : AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    s['label'] as String,
                    style: AppText.labelSm(
                      color: selected
                          ? AppColors.onPrimary
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Material(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadow.sm,
            ),
            padding: const EdgeInsets.all(AppSpace.md),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Icon(icon, color: AppColors.onPrimary),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.titleMd()),
                      if (subtitle.isNotEmpty)
                        Text(subtitle, style: AppText.bodySm()),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 4 sudut bracket kamera.
class _ReticlePainter extends CustomPainter {
  _ReticlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const len = 36.0;
    const r = 16.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    const o = 2.0; // setengah stroke biar gak kepotong

    canvas.drawPath(
      Path()
        ..moveTo(o, len)
        ..lineTo(o, r)
        ..arcToPoint(const Offset(r, o), radius: const Radius.circular(r - o))
        ..lineTo(len, o),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w - len, o)
        ..lineTo(w - r, o)
        ..arcToPoint(Offset(w - o, r), radius: const Radius.circular(r - o))
        ..lineTo(w - o, len),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w - o, h - len)
        ..lineTo(w - o, h - r)
        ..arcToPoint(Offset(w - r, h - o), radius: const Radius.circular(r - o))
        ..lineTo(w - len, h - o),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(len, h - o)
        ..lineTo(r, h - o)
        ..arcToPoint(Offset(o, h - r), radius: const Radius.circular(r - o))
        ..lineTo(o, h - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ReticlePainter old) => old.color != color;
}

String _fmtQty(num n) =>
    n == n.roundToDouble() ? n.toInt().toString() : n.toString();
