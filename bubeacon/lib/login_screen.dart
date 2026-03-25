import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 0 = ล็อกอิน, 1 = First Time, 2 = ลืมรหัสผ่าน, 3 = ตั้งรหัสใหม่ (User)
  int _viewState = 0;
  bool _rememberMe = false;

  bool _requireTokenInput = false;
  bool _isLoading = false; // เพิ่มสถานะตอนกำลังประมวลผล

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  // --- 1. ล็อกอินหลัก (ระบบ Auto-Detect รหัสผ่านชั่วคราว) ---
  Future<void> _handleLogin() async {
    String email = _emailCtrl.text.trim();
    String password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError("Please enter both email and password");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. ตรวจสอบใน Firestore ก่อนว่าใช้ รหัสผ่านชั่วคราว หรือไม่?
      var userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (userQuery.docs.isNotEmpty) {
        var userData = userQuery.docs.first.data();
        String tempPass = userData['tempPassword'] ?? '';
        bool isTokenUsed = userData['isTokenUsed'] ?? true;

        if (tempPass == password && !isTokenUsed) {
          // ถ้ารหัสผ่านตรงกับ Temp Password ให้เปลี่ยนไปหน้า First-Time ทันที
          _showSuccess(
            "Temporary password recognized. Please activate your account.",
          );
          setState(() {
            _viewState = 1;
            _passwordCtrl.clear();
          });
          return;
        }
      }

      // 2. ถ้าไม่ใช่รหัสชั่วคราว ล็อกอินปกติด้วย Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        // เช็คว่าบัญชีถูกระงับ (Suspend) จากแอดมินหรือไม่
        var doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();
        if (doc.exists && doc.data()?['isActive'] == false) {
          await FirebaseAuth.instance.signOut();
          _showError("Account suspended. Please contact Admin.");
          return;
        }

        _showSuccess("Login Successful!");
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (_) {
      _showError("Invalid Email or Password");
    } catch (e) {
      _showError("An error occurred. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. ตรวจสอบอีเมลอัตโนมัติ (ลืมรหัสผ่าน) ---
  Future<void> _checkEmailAndProceed() async {
    String email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showError("Please enter your Email.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      var userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (userQuery.docs.isEmpty) {
        _showError("Email not found in our system.");
        return;
      }

      var userData = userQuery.docs.first.data();
      String role = userData['role'] ?? 'User';

      if (role == 'Admin' || role == 'SecondAdmin') {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        _showSuccess("Admin detected! Reset link sent to your email.");
        setState(() => _viewState = 0);
      } else {
        setState(() => _requireTokenInput = true);
      }
    } catch (e) {
      _showError("Error checking user data. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 3. ลืมรหัสผ่านฝั่ง User (เช็ค Token) ---
  void _handleVerifyForgotToken() {
    String token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      _showError("Please enter Reset Token.");
      return;
    }
    if (token.length >= 4) {
      _showSuccess("Token verified! Please create a new password.");
      setState(() => _viewState = 3);
    } else {
      _showError("Invalid Reset Token. Please ask Admin.");
    }
  }

  // --- 4. ตั้งรหัสผ่านใหม่สำหรับ User (Forgot Password) ---
  void _saveNewPasswordAndLogin() {
    String newPass = _newPassCtrl.text.trim();
    if (newPass.length < 6) {
      _showError("Password must be at least 6 characters.");
      return;
    }
    _showSuccess("Password updated successfully!");
    setState(() => _viewState = 0);
  }

  // --- 5. เข้าใช้งานครั้งแรกด้วย Token และตั้งรหัสผ่านจริง ---
  Future<void> _handleFirstTimeActivation() async {
    String email = _emailCtrl.text.trim();
    String token = _tokenCtrl.text.trim();
    String newPass = _newPassCtrl.text.trim();

    if (token.isEmpty || newPass.isEmpty) {
      _showError("Please enter Token and New Password.");
      return;
    }
    if (newPass.length < 6) {
      _showError("Password must be at least 6 characters.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. ค้นหาเอกสารชั่วคราวใน Firestore
      var query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (query.docs.isEmpty) {
        _showError("User data not found.");
        return;
      }

      var doc = query.docs.first;
      if (doc['token'] != token) {
        _showError("Invalid Activation Token.");
        return;
      }

      // 2. สร้างบัญชีเข้าสู่ระบบจริงให้ Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: newPass);

      if (userCredential.user != null) {
        // 3. ย้ายข้อมูลสิทธิ์จากเอกสารเก่า มาใส่เอกสารใหม่ที่เป็น UID จริง
        var data = doc.data();
        data['isTokenUsed'] = true;
        data['tempPassword'] = '';
        data['token'] = '';

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(data);

        // ลบเอกสารชั่วคราวที่แอดมินสร้างไว้ทิ้งไป
        await FirebaseFirestore.instance
            .collection('users')
            .doc(doc.id)
            .delete();

        _showSuccess("Account Activated Successfully!");
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _showError("This email is already activated. Log in normally.");
      } else {
        _showError("Auth Error: ${e.message}");
      }
    } catch (e) {
      _showError("System Error: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF111827), Color(0xFF1E3A8A), Color(0xFF111827)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(32.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.radioTower,
                    color: Colors.blue,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _viewState == 0
                        ? "Welcome To BuVyx"
                        : _viewState == 1
                        ? "Account Activation"
                        : _viewState == 2
                        ? "Reset Password"
                        : "Create New Password",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _viewState == 0
                        ? "Sign in to continue"
                        : _viewState == 1
                        ? "Set your permanent password to continue"
                        : _viewState == 2
                        ? "Enter your email to verify your account"
                        : "Secure your account",
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                  const SizedBox(height: 32),

                  // =================== STATE 0: LOGIN ===================
                  if (_viewState == 0) ...[
                    _buildTextField(
                      controller: _emailCtrl,
                      hint: "Email Address",
                      icon: LucideIcons.mail,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _passwordCtrl,
                      hint: "Password",
                      icon: LucideIcons.lock,
                      isPassword: true,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (val) =>
                                  setState(() => _rememberMe = val!),
                              activeColor: Colors.blue,
                            ),
                            const Text(
                              "Remember me",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _viewState = 2;
                            _requireTokenInput = false;
                            _tokenCtrl.clear();
                            _emailCtrl.clear();
                          }),
                          child: const Text(
                            "Forgot Password?",
                            style: TextStyle(color: Colors.blue, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildPrimaryButton(
                      "LOGIN",
                      _handleLogin,
                      Colors.blue[600]!,
                    ),

                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignUpScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            "Sign Up",
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // =================== STATE 1: FIRST TIME (Auto Detected) ===================
                  if (_viewState == 1) ...[
                    _buildTextField(
                      controller: _emailCtrl,
                      hint: "Email Address",
                      icon: LucideIcons.mail,
                      enabled: false, // บล็อคช่องอีเมลไว้ ไม่ให้แก้
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _tokenCtrl,
                      hint: "Activation Token (From Admin)",
                      icon: LucideIcons.shieldAlert,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _newPassCtrl,
                      hint: "Create Permanent Password",
                      icon: LucideIcons.lock,
                      isPassword: true,
                    ),
                    const SizedBox(height: 32),
                    _buildPrimaryButton(
                      "ACTIVATE & LOGIN",
                      _handleFirstTimeActivation,
                      Colors.green[600]!,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() {
                        _viewState = 0;
                        _passwordCtrl.clear();
                      }),
                      child: const Text(
                        "Back to Login",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],

                  // =================== STATE 2: FORGOT PASSWORD ===================
                  if (_viewState == 2) ...[
                    _buildTextField(
                      controller: _emailCtrl,
                      hint: "Enter your Email",
                      icon: LucideIcons.mail,
                    ),
                    const SizedBox(height: 16),

                    if (_requireTokenInput) ...[
                      _buildTextField(
                        controller: _tokenCtrl,
                        hint: "Reset Token (From Admin)",
                        icon: LucideIcons.key,
                      ),
                      const SizedBox(height: 32),
                      _buildPrimaryButton(
                        "VERIFY TOKEN",
                        _handleVerifyForgotToken,
                        Colors.blue[600]!,
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      _buildPrimaryButton(
                        "NEXT",
                        _checkEmailAndProceed,
                        Colors.orange[600]!,
                      ),
                    ],

                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() => _viewState = 0),
                      child: const Text(
                        "Back to Login",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],

                  // =================== STATE 3: SET NEW PASSWORD ===================
                  if (_viewState == 3) ...[
                    _buildTextField(
                      controller: _newPassCtrl,
                      hint: "New Permanent Password",
                      icon: LucideIcons.lock,
                      isPassword: true,
                    ),
                    const SizedBox(height: 32),
                    _buildPrimaryButton(
                      "SAVE NEW PASSWORD",
                      _saveNewPasswordAndLogin,
                      Colors.green[600]!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool enabled = true, // เพิ่ม property enabled
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      enabled: enabled,
      style: TextStyle(color: enabled ? Colors.white : Colors.grey),
      decoration: InputDecoration(
        filled: true,
        fillColor: enabled
            ? const Color(0xFF1F2937).withOpacity(0.5)
            : Colors.black26,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.blue, width: 1),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onPressed, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 10,
          shadowColor: color.withOpacity(0.4),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}
