import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:abwarehouse/scanner.dart';
import 'package:abwarehouse/registry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F6FA),
      appBar: AppBar(title: const Text("ABwarehouse"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: StaggeredGrid.count(
          crossAxisCount: 2,
          mainAxisSpacing: 18,
          crossAxisSpacing: 18,
          children: [
            StaggeredGridTile.count(
              crossAxisCellCount: 2,
              mainAxisCellCount: 1.2,
              child: _scannerCard(context),
            ),
            StaggeredGridTile.count(
              crossAxisCellCount: 1,
              mainAxisCellCount: 1,
              child: _smallCard(
                "Stock\nOpname",
                Icons.inventory_2_outlined,
                const Color(0xff174A93),
                const Color(0xff081D3B),
                () {},
              ),
            ),
            StaggeredGridTile.count(
              crossAxisCellCount: 1,
              mainAxisCellCount: 1,
              child: _smallCard(
                "Registry",
                Icons.assignment_outlined,
                const Color(0xff174A93),
                const Color(0xff081D3B),
                () {Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegistryPage()),
                );
              },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scannerCard(BuildContext context) => InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const Scanner()),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [
              Color(0xff174A93),
              Color(0xff081D3B),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
              size: 42,
            ),

            const Spacer(),

            const Text(
              "Scanner",
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );

  Widget _smallCard(String title, IconData icon, Color c1, Color c2,
          VoidCallback onTap) =>
      InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(colors: [c1, c2]),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 36),
              const Spacer(),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold))
            ],
          ),
        ),
      );
}
