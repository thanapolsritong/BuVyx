import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dashboard_screen.dart'; // ดึง AppSettings มาใช้เรื่องสี

// ==========================================
// 1. Model สำหรับเก็บข้อมูล Log
// ==========================================
enum LogLevel { info, warning, critical }

class SystemLog {
  final String id;
  final DateTime timestamp;
  final LogLevel level;
  final String source;
  final String message;

  SystemLog({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
  });
}

// ==========================================
// 2. หน้าจอ Logs Screen
// ==========================================
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  // สร้างข้อมูลจำลอง (Dummy Data)
  final List<SystemLog> _logs = [
    SystemLog(
      id: "L001",
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      level: LogLevel.critical,
      source: "Sensor SN-BU-001",
      message: "PGA exceeded safety threshold! (PGA: 15.2%g)",
    ),
    SystemLog(
      id: "L002",
      timestamp: DateTime.now().subtract(const Duration(minutes: 42)),
      level: LogLevel.warning,
      source: "System",
      message: "Sensor SN-BKK-001 is offline or lost connection.",
    ),
    SystemLog(
      id: "L003",
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      level: LogLevel.info,
      source: "Admin",
      message: "Admin added a new user (staff@bubeacon.com).",
    ),
    SystemLog(
      id: "L004",
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      level: LogLevel.info,
      source: "System",
      message: "System initialized and normal operation started.",
    ),
    SystemLog(
      id: "L005",
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      level: LogLevel.warning,
      source: "Sensor SN-BU-001",
      message: "High temperature detected (45.5°C).",
    ),
    SystemLog(
      id: "L006",
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      level: LogLevel.info,
      source: "Admin",
      message: "Global chart update rate changed to 3 Seconds.",
    ),
  ];

  String _selectedFilter = 'All'; // 'All', 'Info', 'Warning', 'Critical'

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

  // จัดการสีและไอคอนตามระดับ Log
  Color _getLogColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.critical:
        return Colors.redAccent;
    }
  }

  IconData _getLogIcon(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return LucideIcons.info;
      case LogLevel.warning:
        return LucideIcons.alertTriangle;
      case LogLevel.critical:
        return LucideIcons.alertOctagon;
    }
  }

  // ฟอร์แมตเวลาให้อ่านง่าย
  String _formatTime(DateTime time) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return "${time.year}-${pad(time.month)}-${pad(time.day)} ${pad(time.hour)}:${pad(time.minute)}";
  }

  @override
  Widget build(BuildContext context) {
    // กรองข้อมูลตามที่เลือก
    List<SystemLog> filteredLogs = _logs.where((log) {
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Info' && log.level == LogLevel.info) return true;
      if (_selectedFilter == 'Warning' && log.level == LogLevel.warning)
        return true;
      if (_selectedFilter == 'Critical' && log.level == LogLevel.critical)
        return true;
      return false;
    }).toList();

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
                      "Event History",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      "Track system events, warnings, and alerts",
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

            // --- ตารางแสดง Log ---
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: filteredLogs.isEmpty
                    ? Center(
                        child: Text(
                          "No logs found for this filter.",
                          style: TextStyle(color: textMuted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: filteredLogs.length,
                        separatorBuilder: (context, index) =>
                            Divider(color: borderColor, height: 1),
                        itemBuilder: (context, index) {
                          final log = filteredLogs[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: _getLogColor(
                                log.level,
                              ).withOpacity(0.1),
                              child: Icon(
                                _getLogIcon(log.level),
                                color: _getLogColor(log.level),
                                size: 20,
                              ),
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  log.source,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  _formatTime(log.timestamp),
                                  style: TextStyle(
                                    color: textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                log.message,
                                style: TextStyle(
                                  color: log.level == LogLevel.critical
                                      ? Colors.redAccent
                                      : textMuted,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
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
