import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_screen.dart'; // ดึง AppSettings มาใช้เรื่องสี

// ==========================================
// 1. หน้าจอ Logs Screen (เชื่อมต่อ Firebase + มี Console Mode)
// ==========================================
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _selectedFilter = 'All'; // 'All', 'Info', 'Warning', 'Critical'

  // ✅ ตัวแปรสลับโหมดการแสดงผล (UI ธรรมดา หรือ Console ของ Engineer)
  bool _isConsoleMode = false;

  // ดึงสีจาก Theme กลาง
  Color get bgColor =>
      AppSettings.isDarkMode ? const Color(0xFF030712) : Colors.grey[50]!;
  Color get cardColor =>
      AppSettings.isDarkMode ? const Color(0xFF111827) : Colors.white;
  Color get borderColor =>
      AppSettings.isDarkMode ? Colors.white10 : Colors.grey[300]!;
  Color get textColor => AppSettings.isDarkMode ? Colors.white : Colors.black;
  Color get textMuted =>
      AppSettings.isDarkMode ? Colors.white54 : Colors.grey[600]!;

  // จัดการสีและไอคอนตามระดับ Log ที่มาจาก Firebase
  Color _getLogColor(String level) {
    switch (level) {
      case 'Info':
        return Colors.blue;
      case 'Warning':
        return Colors.orange;
      case 'Critical':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  // สีสำหรับโหมด Console (ให้ฟีลลิ่งแบบ Hacker/Terminal)
  Color _getConsoleTextColor(String level) {
    switch (level) {
      case 'Info':
        return Colors.greenAccent;
      case 'Warning':
        return Colors.yellowAccent;
      case 'Critical':
        return Colors.redAccent;
      default:
        return Colors.white70;
    }
  }

  IconData _getLogIcon(String level) {
    switch (level) {
      case 'Info':
        return LucideIcons.info;
      case 'Warning':
        return LucideIcons.alertTriangle;
      case 'Critical':
        return LucideIcons.alertOctagon;
      default:
        return LucideIcons.helpCircle;
    }
  }

  // ฟอร์แมตเวลาให้อ่านง่าย
  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return "Pending...";
    final time = timestamp.toDate();
    String pad(int n) => n.toString().padLeft(2, '0');
    return "${time.year}-${pad(time.month)}-${pad(time.day)} ${pad(time.hour)}:${pad(time.minute)}:${pad(time.second)}";
  }

  // ==========================================
  // ✅ ฟังก์ชันอัปเดตสถานะการรับทราบ (Acknowledge)
  // ==========================================
  Future<void> _markAsResolved(String docId) async {
    await FirebaseFirestore.instance.collection('logs').doc(docId).update({
      'isResolved': true,
    });
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
          "System Logs",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          // ✅ ปุ่มสลับโหมด Console / UI
          IconButton(
            tooltip: _isConsoleMode
                ? "Switch to UI View"
                : "Switch to Console View",
            icon: Icon(
              _isConsoleMode ? LucideIcons.layoutList : LucideIcons.terminal,
              color: Colors.cyanAccent,
            ),
            onPressed: () {
              setState(() {
                _isConsoleMode = !_isConsoleMode;
              });
            },
          ),
          IconButton(
            tooltip: "Export Logs",
            icon: Icon(LucideIcons.downloadCloud, color: textColor),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Downloading logs as CSV..."),
                  backgroundColor: Colors.blue,
                ),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- หัวข้อและ Filter ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isConsoleMode ? "Logs Console" : "Event History",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      _isConsoleMode
                          ? "Raw system output and debugging logs"
                          : "Track system events, warnings, and alerts",
                      style: TextStyle(color: textMuted, fontSize: 14),
                    ),
                  ],
                ),
                // แถบปุ่มกรอง (Filter Chips)
                Row(
                  children: [
                    _buildFilterChip('All', Colors.grey),
                    const SizedBox(width: 8),
                    _buildFilterChip('Info', Colors.blue),
                    const SizedBox(width: 8),
                    _buildFilterChip('Warning', Colors.orange),
                    const SizedBox(width: 8),
                    _buildFilterChip('Critical', Colors.redAccent),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- ตารางแสดง Log (ดึงจาก Firebase แบบ Real-time) ---
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _isConsoleMode ? Colors.black : cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isConsoleMode ? Colors.white24 : borderColor,
                  ),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('logs')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          "No logs found in the system.",
                          style: TextStyle(color: textMuted),
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    // กรองข้อมูลตามที่เลือกบน UI
                    final filteredDocs = docs.where((doc) {
                      if (_selectedFilter == 'All') return true;
                      final data = doc.data() as Map<String, dynamic>;
                      return data['type'] == _selectedFilter;
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return Center(
                        child: Text(
                          "No logs match the '$_selectedFilter' filter.",
                          style: TextStyle(color: textMuted),
                        ),
                      );
                    }

                    // ✅ ตรวจสอบโหมดการแสดงผล
                    if (_isConsoleMode) {
                      return _buildConsoleView(filteredDocs);
                    } else {
                      return _buildUiView(filteredDocs);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ✅ แสดงผลแบบ Console (สำหรับ Engineer)
  // ==========================================
  Widget _buildConsoleView(List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;

        final type = data['type'] ?? 'Info';
        final isResolved = data['isResolved'] ?? false;
        final source = data['source'] ?? 'System';
        final zone = data['zone'] ?? 'Unknown Zone';
        final message = data['message'] ?? 'No message';
        final timestamp = data['timestamp'] as Timestamp?;

        final timeStr = _formatTime(timestamp);

        final rawLogString =
            "[$timeStr] [${type.toUpperCase()}] [$source @ $zone] $message | RESOLVED: ${isResolved.toString().toUpperCase()}";

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: SelectableText(
            rawLogString,
            style: TextStyle(
              color: _getConsoleTextColor(type),
              fontFamily: 'Courier',
              fontSize: 13,
              fontWeight: type == 'Critical'
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // ✅ แสดงผลแบบ UI ปกติ (สวยงาม)
  // ==========================================
  Widget _buildUiView(List<QueryDocumentSnapshot> docs) {
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: docs.length,
      separatorBuilder: (context, index) =>
          Divider(color: borderColor, height: 1),
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;

        final type = data['type'] ?? 'Info';
        final isResolved = data['isResolved'] ?? false;
        final source = data['source'] ?? 'System';
        final message = data['message'] ?? 'No message';
        final timestamp = data['timestamp'] as Timestamp?;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            backgroundColor: _getLogColor(type).withOpacity(0.1),
            child: Icon(_getLogIcon(type), color: _getLogColor(type), size: 20),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                source,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                _formatTime(timestamp),
                style: TextStyle(color: textMuted, fontSize: 12),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              message,
              style: TextStyle(
                color: type == 'Critical' ? Colors.redAccent : textMuted,
                fontSize: 14,
              ),
            ),
          ),
          trailing: type != 'Info'
              ? (isResolved
                    ? const Icon(
                        LucideIcons.checkCircle2,
                        color: Colors.green,
                        size: 20,
                      )
                    : ElevatedButton(
                        onPressed: () => _markAsResolved(doc.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 0,
                          ),
                          minimumSize: const Size(60, 30),
                        ),
                        child: const Text(
                          "Acknowledge",
                          style: TextStyle(color: Colors.blue, fontSize: 11),
                        ),
                      ))
              : null,
        );
      },
    );
  }

  // วิดเจ็ตช่วยสร้างปุ่ม Filter
  Widget _buildFilterChip(String label, Color activeColor) {
    bool isSelected = _selectedFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.1) : Colors.transparent,
          border: Border.all(color: isSelected ? activeColor : borderColor),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : textMuted,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
