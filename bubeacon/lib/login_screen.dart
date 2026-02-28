import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dashboard_screen.dart';
import 'user_management_screen.dart';
import 'signup_screen.dart'; // <-- อย่าลืม import หน้า signup

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 0 = ล็อกอินปกติ, 1 = เข้าใช้งานครั้งแรก, 2 = ลืมรหัสผ่าน, 3 = ตั้งรหัสใหม่
  int _viewState = 0;
  bool _rememberMe = false;
  AppUser? _verifiedUser;

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

  void _handleLogin() {
    String email = _emailCtrl.text.trim();
    String password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError("Please enter both email and password");
      return;
    }

    try {
      AppUser user = GlobalAuth.usersDb.firstWhere((u) => u.email == email);

      if (!user.isActive) {
        _showError("Account suspended. Please contact Admin.");
        return;
      }

      if (user.tempPassword == password && !user.isTokenUsed) {
        setState(() {
          _verifiedUser = user;
          _viewState = 1;
        });
        return;
      }

      if (user.permanentPassword == password && user.isTokenUsed) {
        GlobalAuth.currentUser = user;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      } else {
        _showError("Invalid Email or Password");
      }
    } catch (e) {
      _showError("Invalid Email or Password");
    }
  }

  void _handleFirstTimeActivation() {
    String token = _tokenCtrl.text.trim();
    String newPass = _newPassCtrl.text.trim();

    if (token != _verifiedUser!.token) {
      _showError("Invalid Activation Token.");
      return;
    }
    if (newPass.length < 4) {
      _showError("Password must be at least 4 characters.");
      return;
    }
    _saveNewPasswordAndLogin(newPass);
  }

  void _handleVerifyForgotToken() {
    String email = _emailCtrl.text.trim();
    String token = _tokenCtrl.text.trim();

    try {
      AppUser user = GlobalAuth.usersDb.firstWhere((u) => u.email == email);
      if (!user.isActive) {
        _showError("Account suspended.");
        return;
      }
      if (user.token == token && !user.isTokenUsed) {
        setState(() {
          _verifiedUser = user;
          _viewState = 3;
        });
      } else {
        _showError("Invalid Reset Token. Please ask Admin to regenerate it.");
      }
    } catch (e) {
      _showError("User not found.");
    }
  }

  void _saveNewPasswordAndLogin(String newPass) {
    setState(() {
      _verifiedUser!.permanentPassword = newPass;
      _verifiedUser!.isTokenUsed = true;
      _verifiedUser!.tempPassword = "N/A";
      _verifiedUser!.token = "N/A";
    });

    GlobalAuth.currentUser = _verifiedUser;
    _showSuccess("Password set successfully!");
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
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
                        ? "Welcome To BuBeacon"
                        : _viewState == 1
                        ? "First Time Setup"
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
                        ? "Activate your account with Token"
                        : _viewState == 2
                        ? "Enter the reset token from Admin"
                        : "Secure your account",
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                  const SizedBox(height: 32),

                  if (_viewState == 0) ...[
                    _buildTextField(
                      controller: _emailCtrl,
                      hint: "Email Address",
                      icon: LucideIcons.mail,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _passwordCtrl,
                      hint: "Password (or Temp Password)",
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
                            _tokenCtrl.clear();
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
                    // <-- ส่วนนี้คือที่เพิ่มกลับเข้ามาครับ (Sign Up Link) -->
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

                  if (_viewState == 1) ...[
                    _buildTextField(
                      controller: _tokenCtrl,
                      hint: "Activation Token",
                      icon: LucideIcons.shieldAlert,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _newPassCtrl,
                      hint: "New Permanent Password",
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
                      onPressed: () => setState(() => _viewState = 0),
                      child: const Text(
                        "Back to Login",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],

                  if (_viewState == 2) ...[
                    _buildTextField(
                      controller: _emailCtrl,
                      hint: "Email Address",
                      icon: LucideIcons.mail,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _tokenCtrl,
                      hint: "Reset Token (from Admin)",
                      icon: LucideIcons.key,
                    ),
                    const SizedBox(height: 32),
                    _buildPrimaryButton(
                      "VERIFY TOKEN",
                      _handleVerifyForgotToken,
                      Colors.orange[600]!,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() => _viewState = 0),
                      child: const Text(
                        "Back to Login",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],

                  if (_viewState == 3) ...[
                    _buildTextField(
                      controller: _newPassCtrl,
                      hint: "New Permanent Password",
                      icon: LucideIcons.lock,
                      isPassword: true,
                    ),
                    const SizedBox(height: 32),
                    _buildPrimaryButton(
                      "SAVE PASSWORD",
                      () => _saveNewPasswordAndLogin(_newPassCtrl.text.trim()),
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
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF1F2937).withOpacity(0.5),
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
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 10,
          shadowColor: color.withOpacity(0.4),
        ),
        child: Text(
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
