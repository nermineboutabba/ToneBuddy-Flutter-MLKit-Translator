import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tone_buddy/splash_screen.dart';

void main() {
  runApp(const ToneBuddyApp());
}

class ToneBuddyApp extends StatelessWidget {
  const ToneBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF0D9488);
    const slateDark = Color(0xFF0F172A);
    const slateBg = Color(0xFFF8FAFC);

    return MaterialApp(
      title: 'ToneBuddy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: slateBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryTeal,
          primary: primaryTeal,
          secondary: slateDark,
          surface: Colors.white,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const SplashScreen(),
    );
  }
}
