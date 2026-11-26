import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:abwarehouse/app_theme.dart';
import 'package:abwarehouse/ui_kit.dart';

/// Akun -- info profil + logout.
class AkunPage extends StatelessWidget {
  const AkunPage({
    super.key,
    required this.namaUser,
    required this.dcNama,
    required this.role,
    required this.online,
  });

  final String namaUser;
  final String dcNama;
  final String? role;
  final bool online;

  Future<void> _logout(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Logout',
      message: 'Yakin mau keluar dari akun ini?',
      confirmLabel: 'Logout',
      destructive: true,
    );
    // AuthGate otomatis balik ke LoginDcPage begitu status login berubah.
    if (ok) await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '-';
    final username = email.split('@').first;
    final inisial = namaUser.trim().isEmpty
        ? '?'
        : namaUser.trim()[0].toUpperCase();

    Widget infoRow(String label, String value, {bool mono = false}) => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm + 4,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.bodySm())),
          Text(
            value,
            style: mono
                ? AppText.monoSm(color: AppColors.onSurface)
                : AppText.labelLg(),
          ),
        ],
      ),
    );

    Widget divider() => Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      color: AppColors.outlineVariant.withValues(alpha: .6),
    );

    return Column(
      children: [
        PageHeader(sub: dcNama, title: 'Akun', online: online),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.md,
              AppSpace.sm,
              AppSpace.md,
              AppSpace.lg,
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadow.sm,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        inisial,
                        style: AppText.headlineMd(color: AppColors.onPrimary),
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(namaUser, style: AppText.headlineMd()),
                          Text(username, style: AppText.monoSm()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  children: [
                    infoRow(
                      'Distribution Center',
                      dcNama.isEmpty ? '-' : dcNama,
                    ),
                    divider(),
                    infoRow('Role', (role ?? '-').toUpperCase()),
                    divider(),
                    infoRow('Email', email, mono: true),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              Material(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => _logout(context),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.logout,
                          size: 20,
                          color: AppColors.onErrorContainer,
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Text(
                          'Logout',
                          style: AppText.labelLg(
                            color: AppColors.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
