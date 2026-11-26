import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:abwarehouse/app_theme.dart';
import 'package:abwarehouse/ui_kit.dart';

class LoginDcPage extends StatefulWidget {
  const LoginDcPage({super.key});

  @override
  State<LoginDcPage> createState() => _LoginDcPageState();
}

class _LoginDcPageState extends State<LoginDcPage> {
  final supabase = Supabase.instance.client;
  final usernameCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  bool obscurePassword = true;
  String? error;

  // Domain internal buat akun Supabase. User cuma perlu inget user name-nya
  // doang, domain ini nempel otomatis di belakang layar.
  static const _emailDomain = 'abuyagroup.com';

  /// Terima input "budi" ATAU "budi@abuyagroup.com" -- dua-duanya jalan.
  String _buildEmail(String input) {
    final trimmed = input.trim();
    if (trimmed.contains('@')) return trimmed;
    return '$trimmed@$_emailDomain';
  }

  Future<void> doLogin() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final auth = await supabase.auth.signInWithPassword(
        email: _buildEmail(usernameCtrl.text),
        password: passCtrl.text,
      );

      final uid = auth.user?.id;
      if (uid == null) {
        throw const AuthException('Login gagal. Coba lagi.');
      }

      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', uid)
          .maybeSingle();

      // Aplikasi HP hanya untuk scanner.
      if (profile == null || profile['role'] != 'scanner') {
        await supabase.auth.signOut();

        if (mounted) {
          setState(() {
            error =
                'Akun ini khusus untuk web. '
                'Silakan login memakai akun scanner.';
          });
        }
        return;
      }

      // AuthGate otomatis membuka HomePage setelah login berhasil.
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = 'Gagal login: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    usernameCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.md,
                  vertical: AppSpace.xl,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - AppSpace.xl * 2).clamp(
                      0.0,
                      double.infinity,
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(),
                        const Spacer(),
                        const SizedBox(height: AppSpace.lg),
                        _form(),
                        const SizedBox(height: AppSpace.lg),
                        const Spacer(),
                        Text(
                          'Kendala akses? Hubungi Bang Amin Ganteng',
                          textAlign: TextAlign.center,
                          style: AppText.bodySm(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.only(top: AppSpace.sm),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadow.sm,
          ),
          child: const Icon(
            Icons.qr_code_scanner,
            size: 24,
            color: AppColors.onPrimary,
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ScanKuy', style: AppText.titleMd()),
              Text('Operasional DC', style: AppText.bodySm()),
            ],
          ),
        ),
        const StatusPill(),
      ],
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.xs),
    child: Text(text, style: AppText.labelLg()),
  );

  Widget _form() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Halo Cuy!', style: AppText.headlineLg()),
      const SizedBox(height: AppSpace.xs),
      Text(
        'Kuy masuk, input dulu username dan password-nya yak!',
        style: AppText.bodyMd(color: AppColors.onSurfaceVariant),
      ),
      const SizedBox(height: AppSpace.lg),
      _label('Username'),
      TextField(
        controller: usernameCtrl,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.username],
        style: AppText.monoMd(),
        decoration: const InputDecoration(hintText: 'Contoh : scannerganteng1'),
      ),
      const SizedBox(height: AppSpace.md),
      _label('Password'),
      TextField(
        controller: passCtrl,
        obscureText: obscurePassword,
        autofillHints: const [AutofillHints.password],
        style: AppText.monoMd(),
        onSubmitted: (_) => loading ? null : doLogin(),
        decoration: InputDecoration(
          hintText: 'Masukkan password',
          suffixIcon: IconButton(
            tooltip: obscurePassword
                ? 'Tampilkan password'
                : 'Sembunyikan password',
            icon: Icon(
              obscurePassword ? Icons.visibility : Icons.visibility_off,
              color: AppColors.onSurfaceVariant,
              size: 20,
            ),
            onPressed: () => setState(() => obscurePassword = !obscurePassword),
          ),
        ),
      ),
      if (error != null) ...[
        const SizedBox(height: AppSpace.md),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.errorContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.error,
                size: 18,
                color: AppColors.onErrorContainer,
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  error!,
                  style: AppText.bodySm(color: AppColors.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: AppSpace.md + AppSpace.xs),
      AppButton(label: 'Masuk Shift', loading: loading, onPressed: doLogin),
    ],
  );
}
