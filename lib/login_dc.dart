import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:abwarehouse/stock_opname.dart';

class LoginDcPage extends StatefulWidget {
  const LoginDcPage({super.key});

  @override
  State<LoginDcPage> createState() => _LoginDcPageState();
}

class _LoginDcPageState extends State<LoginDcPage> {
  final supabase = Supabase.instance.client;
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> doLogin() async {
    setState(() { loading = true; error = null; });
    try {
      await supabase.auth.signInWithPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StockOpname()),
      );
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 56, color: Color(0xff174A93)),
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
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()),
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
    );
  }
}
