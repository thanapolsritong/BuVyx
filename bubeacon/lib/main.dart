import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ เพิ่ม Firebase Auth
import 'firebase_options.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart'; // ✅ เพิ่ม Dashboard Screen

void main() async {
  // บอกให้ Flutter รอการตั้งค่าต่างๆ ให้เสร็จก่อน
  WidgetsFlutterBinding.ensureInitialized();

  // ปลุก Firebase ให้เริ่มทำงานด้วยค่าจากไฟล์ options ที่เพิ่งได้มา
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
      title: 'BuVyx Network',
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

// ==========================================
// ✅ ตัวจัดการ Auto-Login (Auth Wrapper) คอยสับราง
// ==========================================
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // ใช้ StreamBuilder ฟังสถานะการล็อกอินจาก Firebase ตลอดเวลา
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. ระหว่างรอโหลดเช็คสถานะ ให้โชว์หน้าจอโหลดหมุนๆ ไปก่อน
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF030712),
            body: Center(child: CircularProgressIndicator(color: Colors.blue)),
          );
        }

        // 2. ถ้าเช็คแล้วพบว่ามีข้อมูล User (เคยล็อกอินค้างไว้) -> ทะลุไป Dashboard เลย!
        if (snapshot.hasData) {
          return const DashboardScreen();
        }

        // 3. ถ้าไม่มีข้อมูล (ยังไม่เคยล็อกอิน หรือกด Logout ไปแล้ว) -> ค่อยโชว์หน้า Login
        return const LoginScreen();
      },
    );
  }
}

// ==========================================
// 1. หน้า Splash Screen
// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // หน่วงเวลา 3 วินาทีแล้วไปเช็คสถานะล็อกอิน (AuthWrapper)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const AuthWrapper(),
          ), // ✅ เปลี่ยนจาก LoginScreen เป็น AuthWrapper
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
                'BuVyx',
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
