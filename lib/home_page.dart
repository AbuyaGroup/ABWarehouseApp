import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:abwarehouse/scanner.dart';
import 'package:abwarehouse/app_theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface0,
      appBar: AppBar(
        title: Text("ABWarehouse", style: AppText.heading(size: 17)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Scanner",
                style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.muted),
              ),
              const SizedBox(height: 4),
              Text(
                "Pilih menu buat mulai stock opname",
                style: AppText.body(size: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              _scannerCard(context),
              const Spacer(),
              _logoutButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text("Logout", style: AppText.heading(size: 17)),
        content: Text("Yakin mau keluar dari akun ini?", style: AppText.body(size: 13.5, color: AppColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text("Batal", style: AppText.body(size: 13.5, weight: FontWeight.w600, color: AppColors.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Supabase.instance.client.auth.signOut();
      // Gak perlu navigasi manual -- AuthGate otomatis switch balik
      // ke LoginDcPage begitu status login berubah.
    }
  }

  Widget _logoutButton(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton.icon(
          onPressed: () => _logout(context),
          icon: const Icon(Icons.logout, size: 18, color: AppColors.danger),
          label: Text("Logout", style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.danger)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm + 1)),
          ),
        ),
      );

  // Kartu utama "Scanner" -- gradient + shadow + radius gede, ngikutin
  // pola .dc-card / .zona-card di web (card gradient soft, radius 18-20px,
  // shadow menyebar, ada aksen lingkaran transparan di pojok).
  Widget _scannerCard(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const Scanner()),
          ),
          child: Ink(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDeep],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: .28),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  "Scanner",
                  style: AppText.heading(size: 26, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  "Mulai scan barcode buat stock opname",
                  style: AppText.body(size: 12.5, color: Colors.white.withValues(alpha: .78)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text("Buka", style: AppText.body(size: 12.5, weight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward, size: 15, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}