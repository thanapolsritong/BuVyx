import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math';
import 'dashboard_screen.dart'; // ดึงค่า Theme และ AppSettings มาจากที่นี่

// ==========================================
// 1. กำหนด Role และ Model ของ User
// ==========================================
enum UserRole { superAdmin, secondAdmin, normalUser }

class AppUser {
  String id;
  String email;
  UserRole role;
  String tempPassword;
  String token;
  String? permanentPassword;
  bool isTokenUsed;
  bool isActive;
  String organization;

  AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.tempPassword,
    required this.token,
    this.permanentPassword,
    this.isTokenUsed = false,
    this.isActive = true,
    this.organization = "BuBeacon Network",
  });

  String get roleName {
    switch (role) {
      case UserRole.superAdmin:
        return "Super Admin";
      case UserRole.secondAdmin:
        return "Second Admin";
      case UserRole.normalUser:
        return "User";
    }
  }

  Color get roleColor {
    switch (role) {
      case UserRole.superAdmin:
        return Colors.purple;
      case UserRole.secondAdmin:
        return Colors.orange;
      case UserRole.normalUser:
        return Colors.blue;
    }
  }
}

class GlobalAuth {
  static List<AppUser> usersDb = [
    AppUser(
      id: "1",
      email: "admin",
      role: UserRole.superAdmin,
      tempPassword: "",
      token: "",
      permanentPassword: "1234",
      isTokenUsed: true,
    ),
  ];
  static AppUser? currentUser;
}

// ==========================================
// 2. หน้า User Management Screen
// ==========================================
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  // ดึงค่าสิทธิ์มาจากคนที่ล็อกอินอยู่
  UserRole get currentUserRole =>
      GlobalAuth.currentUser?.role ?? UserRole.normalUser;
  String get currentUserId => GlobalAuth.currentUser?.id ?? "";

  // สี Theme เปลี่ยนไปใช้ AppSettings ให้ตรงกับหน้าหลัก
  Color get bgColor =>
      AppSettings.isDarkMode ? const Color(0xFF030712) : Colors.grey[50]!;
  Color get cardColor =>
      AppSettings.isDarkMode ? const Color(0xFF111827) : Colors.white;
  Color get borderColor =>
      AppSettings.isDarkMode ? Colors.white10 : Colors.grey[300]!;
  Color get textColor => AppSettings.isDarkMode ? Colors.white : Colors.black;
  Color get textMuted =>
      AppSettings.isDarkMode ? Colors.white54 : Colors.grey[600]!;

  bool _canManageUser(AppUser targetUser) {
    if (targetUser.id == currentUserId) return false;
    if (currentUserRole == UserRole.superAdmin) return true;
    if (currentUserRole == UserRole.secondAdmin) {
      return targetUser.role == UserRole.normalUser;
    }
    return false;
  }

  String _generateRandomString(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#%^&*';
    Random rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
      ),
    );
  }

  void _showCredentialsDialog(
    String email,
    String tempPass,
    String token, {
    bool isReset = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          isReset ? "Token Reset Successful!" : "User Created Successfully!",
          style: TextStyle(
            color: Colors.green[600],
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Please copy these credentials and send them to the user securely.",
              style: TextStyle(color: textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _buildCopyBox("Email", email),
            const SizedBox(height: 8),
            _buildCopyBox("Temporary Password", tempPass),
            const SizedBox(height: 8),
            _buildCopyBox("Activation Token (For First Login/Reset)", token),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () => Navigator.pop(context),
            child: const Text("Done", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppSettings.isDarkMode ? Colors.black26 : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.copy, size: 16, color: Colors.grey),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Copied to clipboard!"),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog() {
    final TextEditingController emailController = TextEditingController();
    UserRole selectedRole = UserRole.normalUser;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: cardColor,
            surfaceTintColor: Colors.transparent,
            title: Text(
              "Add New User",
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: "User Email",
                    labelStyle: TextStyle(color: textMuted),
                    filled: true,
                    fillColor: AppSettings.isDarkMode
                        ? Colors.black26
                        : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<UserRole>(
                  value: selectedRole,
                  dropdownColor: cardColor,
                  style: TextStyle(color: textColor),
                  items: [
                    if (currentUserRole == UserRole.superAdmin)
                      const DropdownMenuItem(
                        value: UserRole.secondAdmin,
                        child: Text("Second Admin"),
                      ),
                    const DropdownMenuItem(
                      value: UserRole.normalUser,
                      child: Text("Normal User"),
                    ),
                  ],
                  onChanged: (UserRole? value) {
                    if (value != null)
                      setDialogState(() => selectedRole = value);
                  },
                  decoration: InputDecoration(
                    labelText: "Assign Role",
                    labelStyle: TextStyle(color: textMuted),
                    filled: true,
                    fillColor: AppSettings.isDarkMode
                        ? Colors.black26
                        : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel", style: TextStyle(color: textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: () {
                  if (emailController.text.trim().isNotEmpty) {
                    String tempPass = _generateRandomString(8);
                    String token = _generateRandomString(16);

                    setState(() {
                      GlobalAuth.usersDb.add(
                        AppUser(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          email: emailController.text.trim(),
                          role: selectedRole,
                          tempPassword: tempPass,
                          token: token,
                        ),
                      );
                    });
                    Navigator.pop(context);
                    _showCredentialsDialog(
                      emailController.text.trim(),
                      tempPass,
                      token,
                    );
                  }
                },
                child: const Text(
                  "Generate Credentials",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          "User Management",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Access Control",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      "Manage roles, tokens, and account status",
                      style: TextStyle(color: textMuted, fontSize: 14),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showAddUserDialog,
                  icon: const Icon(
                    LucideIcons.userPlus,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text(
                    "Add User",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: GlobalAuth.usersDb.length,
                separatorBuilder: (context, index) =>
                    Divider(color: borderColor, height: 1),
                itemBuilder: (context, index) {
                  final user = GlobalAuth.usersDb[index];
                  final canManage = _canManageUser(user);

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: user.roleColor.withOpacity(0.2),
                          child: Icon(LucideIcons.user, color: user.roleColor),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    user.email,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: user.roleColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: user.roleColor.withOpacity(0.5),
                                      ),
                                    ),
                                    child: Text(
                                      user.roleName,
                                      style: TextStyle(
                                        color: user.roleColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (!user.isActive) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        "Suspended",
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    user.isTokenUsed
                                        ? LucideIcons.checkCircle2
                                        : LucideIcons.key,
                                    size: 12,
                                    color: user.isTokenUsed
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    user.isTokenUsed
                                        ? "Token Verified / Active"
                                        : "Waiting for First Login",
                                    style: TextStyle(
                                      color: textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        if (canManage) ...[
                          IconButton(
                            tooltip: "Regenerate Password & Token",
                            icon: const Icon(
                              LucideIcons.refreshCw,
                              color: Colors.blue,
                              size: 20,
                            ),
                            onPressed: () {
                              String newPass = _generateRandomString(8);
                              String newToken = _generateRandomString(16);
                              setState(() {
                                user.tempPassword = newPass;
                                user.token = newToken;
                                user.isTokenUsed = false;
                              });
                              _showCredentialsDialog(
                                user.email,
                                newPass,
                                newToken,
                                isReset: true,
                              );
                            },
                          ),
                          Tooltip(
                            message: user.isActive
                                ? "Suspend User"
                                : "Activate User",
                            child: Switch(
                              value: user.isActive,
                              activeColor: Colors.green,
                              onChanged: (val) =>
                                  setState(() => user.isActive = val),
                            ),
                          ),
                          IconButton(
                            tooltip: "Delete User",
                            icon: const Icon(
                              LucideIcons.trash2,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => GlobalAuth.usersDb.removeAt(index),
                            ),
                          ),
                        ] else ...[
                          Tooltip(
                            message: "No permission to edit this role",
                            child: Icon(
                              LucideIcons.lock,
                              color: borderColor,
                              size: 20,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
