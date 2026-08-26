import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:abwarehouse/app_theme.dart';

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

  // Domain internal buat akun Supabase. User cuma perlu inget username-nya
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
      await supabase.auth.signInWithPassword(
        email: _buildEmail(usernameCtrl.text),
        password: passCtrl.text,
      );
      // Gak perlu navigasi manual -- AuthGate otomatis switch ke HomePage
      // begitu status login berubah (didengerin via onAuthStateChange).
    } on AuthException catch (e) {
      setState(() => error = e.message);
    } catch (e) {
      setState(() => error = "Gagal login: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gak pake AppBar -- di web, loginScreen juga full-bleed tanpa topbar,
    // langsung gradient background + card di tengah.
    return Scaffold(
<<<<<<< HEAD
      appBar: AppBar(title: const Text("Login Stock Opname")),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48, // 48 = padding atas+bawah
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset(
                        'assets/images/logo_ABI.png',
                        height: 220,
                      ),
                      const SizedBox(height: 24),
                      if (error != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFCEBEB),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(error!, style: const TextStyle(color: Color(0xFF791F1F))),
                        ),
                      TextField(
                        controller: usernameCtrl,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: "Username", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passCtrl,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: "Password",
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: const Color(0xff174A93),
                            ),
                            onPressed: () => setState(() => obscurePassword = !obscurePassword),
                          ),
                        ),
                        onSubmitted: (_) => loading ? null : doLogin(),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: loading ? null : doLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff174A93),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: loading
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text("Masuk"),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
=======
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.loginGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: _loginCard(),
                    ),
                  ),
                ),
              );
            },
          ),
>>>>>>> 8497e2c200f6c00a6239c22e9303091cb24f69ef
        ),
      ),
    );
  }
<<<<<<< HEAD
}
=======

  Widget _loginCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 34, 30, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF040C2C).withOpacity(.34),
            blurRadius: 60,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo perusahaan tetep dipertahanin, cuma dikecilin -- brand
          // "ABwarehouse" + subjudul "Scanner" yang jadi fokus utama,
          // ngikutin pola .login-brand + p.sub di web (icon + judul + sub).
          Center(
            child: Image.asset(
              'assets/images/logo_ABI.png',
              height: 72,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "ABwarehouse",
            textAlign: TextAlign.center,
            style: AppText.heading(size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            "Scanner",
            textAlign: TextAlign.center,
            style: AppText.body(size: 13.5, weight: FontWeight.w500, color: AppColors.muted),
          ),
          const SizedBox(height: 28),
          if (error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                error!,
                style: AppText.body(size: 13, color: AppColors.danger),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text("Email", style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.muted)),
          const SizedBox(height: 6),
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: "nama@abuyagroup.com"),
          ),
          const SizedBox(height: 16),
          Text("Password", style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.muted)),
          const SizedBox(height: 6),
          TextField(
            controller: passCtrl,
            obscureText: obscurePassword,
            onSubmitted: (_) => loading ? null : doLogin(),
            decoration: InputDecoration(
              hintText: "••••••••",
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.muted,
                  size: 20,
                ),
                onPressed: () => setState(() => obscurePassword = !obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppRadius.sm + 1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(.28),
                    blurRadius: 18,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.sm + 1),
                  onTap: loading ? null : doLogin,
                  child: Center(
                    child: loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            "Masuk",
                            style: AppText.body(size: 14.5, weight: FontWeight.w700, color: Colors.white),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
>>>>>>> 8497e2c200f6c00a6239c22e9303091cb24f69ef
