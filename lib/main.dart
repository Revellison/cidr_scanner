import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/storage/hive_bootstrap.dart';
import 'features/scanner/presentation/scanner_dashboard_screen.dart';

Future<void> main() async {
  await HiveBootstrap.init();
  runApp(const ProviderScope(child: App()));
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CIDR Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.black,
        brightness: Brightness.dark,
        textTheme: GoogleFonts.rubikTextTheme(ThemeData.dark().textTheme),
        primaryTextTheme: GoogleFonts.rubikTextTheme(
          ThemeData.dark().primaryTextTheme,
        ),
        colorScheme: const ColorScheme.dark(
          surface: Colors.black,
          onSurface: Colors.white,
          primary: Colors.white,
          onPrimary: Colors.black,
        ),
      ),
      home: const ScannerDashboardScreen(),
    );
  }
}
