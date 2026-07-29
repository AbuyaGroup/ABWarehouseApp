import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:abwarehouse/auth_gate.dart';

// GANTI dengan Project URL & anon key Supabase lo
// (yang sama persis dipake di web opname-afc)
const supabaseUrl = 'https://qoonjeimsrzztlfyembp.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFvb25qZWltc3J6enRsZnllbWJwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQxNTg2MTgsImV4cCI6MjA5OTczNDYxOH0.vgqaUJbDOu0hN7gp3f9SozHsDymZR-0TKTijl8q_2ZI';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    // EmptyLocalStorage = sesi login GAK disimpen di device.
    // Efeknya: tiap app di-close & dibuka lagi, wajib login ulang.
    // (Kalau nanti mau balik ke behavior "inget login", tinggal
    // hapus parameter authOptions ini.)
    authOptions: const FlutterAuthClientOptions(
      localStorage: EmptyLocalStorage(),
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: AuthGate(),
      );
}

