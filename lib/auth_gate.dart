import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:abwarehouse/login_dc.dart';
import 'package:abwarehouse/home_page.dart';

/// Gerbang utama app. Dengerin status login Supabase secara real-time --
/// begitu login/logout, otomatis switch antara LoginDcPage & HomePage
/// tanpa perlu navigasi manual.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;
        if (session != null) {
          return const HomePage();
        }
        return const LoginDcPage();
      },
    );
  }
}
