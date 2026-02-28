import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'login_screen.dart';

void main() {
  runApp(const BuBeaconApp());
}

class BuBeaconApp extends StatefulWidget {
  const BuBeaconApp({super.key});

  @override
  State<BuBeaconApp> createState() => _BuBeaconAppState();
}

class _BuBeaconAppState extends State<BuBeaconApp> {
  Locale _locale = const Locale('th');

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BuBeacon',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      // ตั้งค่าสี Dark Theme ตาม Figma/React ของคุณ
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF030712), // gray-950
        primaryColor: const Color(0xFF2563EB), // blue-600
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.kanitTextTheme(ThemeData.dark().textTheme),
      ),
      home: const SplashScreen(), // เริ่มต้นด้วยหน้า Splash เหมือนใน React
    );
  }
}

// 1. หน้า Splash Screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // หน่วงเวลา 3 วินาทีแล้วไปหน้า Login เหมือนใน React Code
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF111827), Color(0xFF1E3A8A), Color(0xFF111827)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Placeholder (Beacon Icon)
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.5),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.activity,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'BuBeacon',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                child: Text(
                  'Vibration Detection Device for Preliminary Earthquake Intensity Assessment',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Placeholder สำหรับหน้าที่เรากำลังจะสร้างต่อไป
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('Coming Soon: $title')),
    );
  }
}
