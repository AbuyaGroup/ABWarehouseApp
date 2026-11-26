import 'package:material_ui/material_ui.dart';

import 'package:abwarehouse/app_theme.dart';

/// Pill "Online" / "Offline" (COMPONENT: badge-dot).
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, this.online = true, this.floating = false});

  final bool online;

  /// true = versi melayang di atas kamera (bg putih 95% + shadow).
  final bool floating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: floating ? 12 : 10,
        vertical: floating ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: floating
            ? AppColors.surfaceContainerLowest.withValues(alpha: .95)
            : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        boxShadow: floating ? AppShadow.sm : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: online ? AppColors.secondary : AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            online ? 'Online' : 'Offline',
            style: floating
                ? AppText.monoSm(color: AppColors.onSurface)
                : AppText.labelSm(color: AppColors.onSurface),
          ),
        ],
      ),
    );
  }
}

/// Tombol bulat 48px (COMPONENT: button-icon).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  /// Versi "nyala" (misal flash ON) -> bg primary.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: active
          ? AppColors.primary
          : AppColors.surfaceContainerLowest.withValues(alpha: .95),
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            size: 22,
            color: active ? AppColors.onPrimary : AppColors.onSurface,
          ),
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: AppShadow.sm,
      ),
      child: tooltip == null
          ? button
          : Tooltip(message: tooltip!, child: button),
    );
  }
}

enum AppButtonVariant { primary, secondary, tonal, surface }

/// Tombol 48px radius md (COMPONENT: button-primary / button-secondary /
/// button-with-icon).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (variant) {
      AppButtonVariant.primary => (AppColors.primary, AppColors.onPrimary),
      AppButtonVariant.secondary => (
        AppColors.primaryContainer,
        AppColors.onPrimaryContainer,
      ),
      AppButtonVariant.tonal => (
        AppColors.surfaceContainerHigh,
        AppColors.onSurface,
      ),
      AppButtonVariant.surface => (
        AppColors.surfaceContainerLowest,
        AppColors.primary,
      ),
    };
    final disabled = onPressed == null || loading;

    return Opacity(
      opacity: onPressed == null && !loading ? .45 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: disabled ? null : onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fg,
                      ),
                    )
                  else if (icon != null)
                    Icon(icon, size: 20, color: fg),
                  if (loading || icon != null) const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.labelLg(color: fg),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Badge angka (bg primary) -- COMPONENT: badge-numeric.
class CountBadge extends StatelessWidget {
  const CountBadge(this.text, {super.key, this.muted = false});

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: muted ? AppColors.surfaceContainerHigh : AppColors.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppText.labelSm(
          color: muted ? AppColors.onSurfaceVariant : AppColors.onPrimary,
        ),
      ),
    );
  }
}

/// Badge hijau + icon centang -- COMPONENT: badge-success.
class SuccessBadge extends StatelessWidget {
  const SuccessBadge(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle,
            size: 14,
            color: AppColors.onSecondaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppText.labelSm(color: AppColors.onSecondaryContainer),
          ),
        ],
      ),
    );
  }
}

/// Dialog konfirmasi standar (Batal / aksi). Return true kalau dikonfirmasi.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: destructive
              ? ElevatedButton.styleFrom(backgroundColor: AppColors.error)
              : null,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Navbar bawah (design Beranda: "Navigasi utama").
class AppNavBar extends StatelessWidget {
  const AppNavBar({super.key, required this.items, required this.onTap});

  /// (icon, iconAktif, label, aktif?)
  final List<(IconData, IconData, String, bool)> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(
          top: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: .6),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm,
            vertical: AppSpace.xs,
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(child: _item(i, items[i])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(int i, (IconData, IconData, String, bool) it) {
    final (icon, activeIcon, label, active) = it;
    final color = active ? AppColors.primary : AppColors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs / 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => onTap(i),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(active ? activeIcon : icon, size: 22, color: color),
              const SizedBox(height: 2),
              Text(label, style: AppText.labelSm(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header halaman (judul kecil + judul besar + pill status).
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.sub,
    required this.title,
    this.online = true,
  });

  final String sub;
  final String title;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.lg,
        AppSpace.md,
        AppSpace.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sub, style: AppText.bodySm()),
                Text(
                  title,
                  style: AppText.headlineMd(),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          StatusPill(online: online),
        ],
      ),
    );
  }
}
