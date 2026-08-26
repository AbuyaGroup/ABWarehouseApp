import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    setState(() { loading = true; error = null; });
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
    return Scaffold(
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
        ),
      ),
    );
  }
}
