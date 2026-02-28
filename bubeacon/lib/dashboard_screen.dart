import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_maps/maps.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // ✅ สำหรับจัดการรูปแบบเวลา
import 'dart:async';
import 'dart:math';
import 'thailand_map_screen.dart';
import 'user_management_screen.dart';
import 'login_screen.dart';
import 'logs_screen.dart';

// ==========================================
// 1. คลาสจัดการการตั้งค่าระบบ (App Settings)
// ==========================================
class AppSettings {
  static bool isDarkMode = true;
  static String language = 'English';
  static String tempUnit = 'Celsius (°C)';
  static bool is24HourFormat = true;

  static bool criticalAlerts = true;
  static bool offlineWarning = true;
  static bool muteSounds = false;

  static String chartUpdateRate = '1 Second';
  static String chartDataView = '30 Seconds';
}

// ==========================================
// 2. Model สำหรับอุปกรณ์ (เพิ่มสถานะพลังงานและสัญญาณ)
// ==========================================
class ConnectedDevice {
  String sn;
  String name;
  Color color;
  LatLng location;

  // ✅ 1. แยก List กราฟเป็น Live และ History
  List<FlSpot> liveSpots = [];
  List<FlSpot> historySpots = [];

  double pga = 0.0;
  double temp = 28.5;
  double humidity = 55.0;
  double pressure = 1012.0;
  double altitude = 15.0;
  bool isActive = true;

  // ✅ เพิ่มตัวแปรใหม่สำหรับ Device Management
  bool isPluggedIn; // ใช้ไฟบ้าน (true) หรือใช้แบตเตอรี่สำรอง (false)
  int batteryLevel; // เปอร์เซ็นต์แบต (0 - 100)
  int signalStrength; // ความแรงสัญญาณมือถือ (0 = ไม่มีสัญญาณ, 1-4 = ขีดสัญญาณ)

  ConnectedDevice({
    required this.sn,
    required this.name,
    required this.color,
    required this.location,
    this.altitude = 15.0,
    this.isActive = true,
    this.isPluggedIn = true,
    this.batteryLevel = 100,
    this.signalStrength = 4,
  });
}

// ==========================================
// 3. หน้า Dashboard หลัก
// ==========================================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  static Map<String, List<ConnectedDevice>> locationDatabase = {
    "Pathum Thani - Eng Bldg": [],
    "Bangkok - Science Lab": [],
    "Chiang Mai - Main Hall": [],
  };

  static String lastVisitedLocation = "Pathum Thani - Eng Bldg";
  static List<String> recentLocations = [
    "Pathum Thani - Eng Bldg",
    "Bangkok - Science Lab",
    "Chiang Mai - Main Hall",
  ];

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ✅ ตัวแปรควบคุมกราฟแบบ Real-time
  int _startTime = DateTime.now().millisecondsSinceEpoch;
  Timer? timer;

  // ✅ 2. เพิ่มตัวแปรสำหรับโหมด History และ DatePicker
  bool _isLiveMode = true;
  List<String> _hiddenDeviceSn = [];
  DateTime? _startDate;
  DateTime? _endDate;

  late MapZoomPanBehavior _zoomPanBehavior;

  bool get isAdmin =>
      GlobalAuth.currentUser?.role == UserRole.superAdmin ||
      GlobalAuth.currentUser?.role == UserRole.secondAdmin;

  final List<Color> deviceColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.pink,
  ];

  List<ConnectedDevice> get currentDevices =>
      DashboardScreen.locationDatabase[DashboardScreen.lastVisitedLocation] ??
      [];

  Color get bgColor => AppSettings.isDarkMode
      ? const Color(0xFF1E1E1E)
      : Colors.grey[50]!; // สีพื้นหลัง
  Color get cardColor => AppSettings.isDarkMode
      ? const Color(0xFF2C2C2C)
      : Colors.white; // สีของ Card
  Color get borderColor => AppSettings.isDarkMode
      ? Colors.grey[700]!
      : Colors.grey[300]!; // สีของเส้นขอบ
  Color get textColor =>
      AppSettings.isDarkMode ? Colors.white : Colors.black; // สีของข้อความ
  Color get textMuted => AppSettings.isDarkMode
      ? Colors.grey[400]!
      : Colors.grey[600]!; // สีข้อความจาง
  Color get dropdownColor => AppSettings.isDarkMode
      ? const Color(0xFF2C2C2C)
      : Colors.white; // สีของ Dropdown

  String get mapUrl => AppSettings.isDarkMode
      ? 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
      : 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';

  @override
  void initState() {
    super.initState();
    // ✅ เพิ่มอุปกรณ์จำลองที่มีทั้งแบบไฟบ้านและแบบแบตเตอรี่
    if (DashboardScreen.locationDatabase["Pathum Thani - Eng Bldg"]!.isEmpty) {
      _addDeviceToSystem(
        "Pathum Thani - Eng Bldg",
        "SN-BU-001",
        "Node-01 (Main)",
        const LatLng(14.0208, 100.5250),
        isPluggedIn: true,
        batteryLevel: 100,
        signalStrength: 4,
      );
      _addDeviceToSystem(
        "Pathum Thani - Eng Bldg",
        "SN-BU-002",
        "Node-02 (Gate)",
        const LatLng(14.0250, 100.5290),
        isPluggedIn: false,
        batteryLevel: 42,
        signalStrength: 2,
      );
    }
    if (DashboardScreen.locationDatabase["Bangkok - Science Lab"]!.isEmpty) {
      _addDeviceToSystem(
        "Bangkok - Science Lab",
        "SN-BKK-001",
        "Node-01",
        const LatLng(13.7563, 100.5018),
      );
    }

    MapLatLng initialCenter = const MapLatLng(13.7563, 100.5018);
    if (currentDevices.isNotEmpty) {
      initialCenter = MapLatLng(
        currentDevices.first.location.latitude,
        currentDevices.first.location.longitude,
      );
    }

    _zoomPanBehavior = MapZoomPanBehavior(
      focalLatLng: initialCenter,
      zoomLevel: 15,
      enableDoubleTapZooming: true,
      enablePinching: true,
      enablePanning: true,
      enableMouseWheelZooming: true,
    );

    // ✅ 3. ตั้งค่า Default History เป็นย้อนหลัง 7 วัน
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(const Duration(days: 7));
    _startSimulation();
  }

  void _startSimulation() {
    timer?.cancel();
    int seconds = 1;
    if (AppSettings.chartUpdateRate == '3 Seconds') seconds = 3;
    if (AppSettings.chartUpdateRate == '5 Seconds') seconds = 5;

    int maxSpots = 30;
    if (AppSettings.chartDataView == '60 Seconds') maxSpots = 60;
    if (AppSettings.chartDataView == '5 Minutes') maxSpots = 300;

    timer = Timer.periodic(Duration(seconds: seconds), (t) {
      // ✅ 4. อัปเดตกราฟเฉพาะตอนอยู่โหมด Live
      if (mounted && _isLiveMode) {
        setState(() {
          double currentTime =
              (DateTime.now().millisecondsSinceEpoch - _startTime) / 1000;

          for (var device in currentDevices) {
            if (!device.isActive) continue;

            // จำลองค่าเซ็นเซอร์
            bool isSpike = Random().nextDouble() < 0.05;
            device.pga = isSpike
                ? Random().nextDouble() * 15
                : Random().nextDouble() * 2;
            device.temp += (Random().nextDouble() - 0.5) * 0.1;
            device.humidity += (Random().nextDouble() - 0.5) * 0.2;
            device.pressure += (Random().nextDouble() - 0.5) * 0.5;

            // ✅ จำลองแบตเตอรี่ลดลงช้าๆ หากไม่ได้เสียบปลั๊ก
            if (!device.isPluggedIn && Random().nextDouble() < 0.05) {
              device.batteryLevel = max(0, device.batteryLevel - 1);
            }
            // ✅ จำลองสัญญาณแกว่ง (1-4)
            if (Random().nextDouble() < 0.1) {
              device.signalStrength = max(
                1,
                min(4, device.signalStrength + (Random().nextBool() ? 1 : -1)),
              );
            }

            // ✅ 5. เปลี่ยนจาก spots เป็น liveSpots
            device.liveSpots.add(FlSpot(currentTime, device.pga));
            if (device.liveSpots.length > maxSpots)
              device.liveSpots.removeAt(0);
          }
        });
      }
    });
  }

  // ✅ 6. ฟังก์ชันจำลองการดึงข้อมูลย้อนหลัง
  void _fetchHistoryData() {
    if (_startDate == null || _endDate == null) return;
    setState(() {
      for (var device in currentDevices) {
        device.historySpots.clear();
        int totalSeconds = _endDate!.difference(_startDate!).inSeconds;
        int step = max(1, totalSeconds ~/ 30); // แบ่งให้ได้ 30 จุด
        for (int i = 0; i <= 30; i++) {
          DateTime pointTime = _startDate!.add(Duration(seconds: i * step));
          double xValue = pointTime.millisecondsSinceEpoch / 1000;
          double yValue =
              (Random().nextDouble() * 5) +
              (Random().nextDouble() < 0.1 ? 10 : 0);
          device.historySpots.add(FlSpot(xValue, yValue));
        }
      }
    });
  }

  // ✅ 7. ฟังก์ชันเปิดหน้าต่างเลือกวันที่และเวลา
  Future<void> _selectDateTime(BuildContext context, bool isStart) async {
    DateTime initialDate = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? DateTime.now());
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: Colors.blue,
            surface: cardColor,
            onSurface: textColor,
          ),
        ),
        child: child!,
      ),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.blue,
              surface: cardColor,
              onSurface: textColor,
            ),
          ),
          child: child!,
        ),
      );
      if (pickedTime != null) {
        setState(() {
          DateTime finalDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          if (isStart) {
            _startDate = finalDateTime;
            if (_endDate != null && _startDate!.isAfter(_endDate!)) {
              _endDate = _startDate!.add(const Duration(hours: 1));
            }
          } else {
            _endDate = finalDateTime;
            if (_startDate != null && _endDate!.isBefore(_startDate!)) {
              _startDate = _endDate!.subtract(const Duration(hours: 1));
            }
          }
        });
        _fetchHistoryData();
      }
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _addDeviceToSystem(
    String location,
    String sn,
    String name,
    LatLng loc, {
    bool isPluggedIn = true,
    int batteryLevel = 100,
    int signalStrength = 4,
  }) {
    if (location.isEmpty || location == "EMPTY") return;
    List<ConnectedDevice> list =
        DashboardScreen.locationDatabase[location] ?? [];
    setState(() {
      list.add(
        ConnectedDevice(
          sn: sn,
          name: name,
          color: deviceColors[list.length % deviceColors.length],
          location: loc,
          altitude: 10.0 + Random().nextDouble() * 50,
          isPluggedIn: isPluggedIn,
          batteryLevel: batteryLevel,
          signalStrength: signalStrength,
        ),
      );
      DashboardScreen.locationDatabase[location] = list;
    });
  }

  void _deleteDevice(int index) {
    setState(() {
      currentDevices.removeAt(index);
    });
  }

  // ✅ Helper Functions สำหรับกำหนดสีและไอคอนตามสถานะอุปกรณ์
  Color _getBatteryColor(int level) {
    if (level > 60) return Colors.green;
    if (level > 20) return Colors.orange;
    return Colors.redAccent;
  }

  IconData _getBatteryIcon(int level) {
    if (level > 80) return LucideIcons.batteryFull;
    if (level > 40) return LucideIcons.batteryMedium;
    if (level > 10) return LucideIcons.batteryLow;
    return LucideIcons.battery; // ถ่านหมด
  }

  Color _getSignalColor(int strength) {
    if (strength >= 3) return Colors.green;
    if (strength == 2) return Colors.orange;
    if (strength == 1) return Colors.redAccent;
    return Colors.grey;
  }

  IconData _getSignalIcon(int strength) {
    if (strength == 0) return LucideIcons.signalZero;
    if (strength == 1) return LucideIcons.signalLow;
    if (strength == 2) return LucideIcons.signalMedium;
    return LucideIcons.signalHigh;
  }

  String _getSignalText(int strength) {
    if (strength >= 3) return "Cellular: Good";
    if (strength == 2) return "Cellular: Fair";
    if (strength == 1) return "Cellular: Weak";
    return "Offline";
  }

  // ✅ 8. ตั้งค่า Tooltip ให้อ่านเวลาจริงทั้ง Live และ History
  LineTouchData get _lineTouchData => LineTouchData(
    touchTooltipData: LineTouchTooltipData(
      tooltipRoundedRadius: 8,
      tooltipPadding: const EdgeInsets.all(12),
      getTooltipItems: (List<LineBarSpot> touchedSpots) {
        return touchedSpots.map((LineBarSpot touchedSpot) {
          final device = currentDevices.firstWhere(
            (d) => d.color == touchedSpot.bar.color,
          );

          DateTime spotTime;
          if (_isLiveMode) {
            spotTime = DateTime.fromMillisecondsSinceEpoch(
              _startTime + (touchedSpot.x * 1000).toInt(),
            );
          } else {
            spotTime = DateTime.fromMillisecondsSinceEpoch(
              (touchedSpot.x * 1000).toInt(),
            );
          }
          String timeStr = DateFormat(
            _isLiveMode ? 'HH:mm:ss' : 'dd MMM HH:mm',
          ).format(spotTime);

          return LineTooltipItem(
            '${device.name}\n',
            TextStyle(
              color: device.color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            children: [
              TextSpan(
                text: '${touchedSpot.y.toStringAsFixed(2)} %g\n',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              TextSpan(
                text: timeStr,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          );
        }).toList();
      },
    ),
  );

  void _showProfileDialog() {
    if (GlobalAuth.currentUser == null) return;
    AppUser user = GlobalAuth.currentUser!;
    TextEditingController passCtrl = TextEditingController(
      text: user.permanentPassword,
    );
    bool isEdited = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: cardColor,
            surfaceTintColor: Colors.transparent,
            title: Row(
              children: [
                const Icon(LucideIcons.user, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  "My Profile",
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Email Address (Read-only)",
                  style: TextStyle(color: textMuted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: TextEditingController(text: user.email),
                  enabled: false,
                  style: TextStyle(color: textMuted),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppSettings.isDarkMode
                        ? Colors.black12
                        : Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Organization (Read-only)",
                  style: TextStyle(color: textMuted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: TextEditingController(text: user.organization),
                  enabled: false,
                  style: TextStyle(color: textMuted),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppSettings.isDarkMode
                        ? Colors.black12
                        : Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(
                      LucideIcons.building,
                      color: textMuted,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Account Role (Read-only)",
                  style: TextStyle(color: textMuted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: TextEditingController(text: user.roleName),
                  enabled: false,
                  style: TextStyle(
                    color: user.roleColor,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: user.roleColor.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Password",
                  style: TextStyle(color: textMuted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: passCtrl,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppSettings.isDarkMode
                        ? Colors.black26
                        : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                  onChanged: (val) {
                    bool edited = val.trim() != user.permanentPassword;
                    if (isEdited != edited)
                      setDialogState(() => isEdited = edited);
                  },
                ),
              ],
            ),
            actions: isEdited
                ? [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel", style: TextStyle(color: textMuted)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      onPressed: () {
                        if (passCtrl.text.trim().length >= 4) {
                          setState(
                            () => user.permanentPassword = passCtrl.text.trim(),
                          );
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Password updated successfully!"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      child: const Text(
                        "Save Changes",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ]
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Close",
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
          );
        },
      ),
    );
  }

  void _openFullSettings() {
    showDialog(
      context: context,
      builder: (context) => FullSettingsDialog(
        onSettingsChanged: () {
          setState(() {});
          _startSimulation();
        },
      ),
    );
  }

  void _showAddDeviceDialog(StateSetter setModalState) {
    if (DashboardScreen.recentLocations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No location available to add device!"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final TextEditingController snController = TextEditingController();
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          "Add New Device",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: snController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: "Serial Number (e.g. A-01)",
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
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: "Device Name (Optional)",
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
              if (snController.text.trim().isNotEmpty) {
                String devName = nameController.text.trim().isEmpty
                    ? "Node-${snController.text}"
                    : nameController.text.trim();
                LatLng baseLoc = currentDevices.isNotEmpty
                    ? currentDevices.first.location
                    : const LatLng(14.0, 100.5);
                _addDeviceToSystem(
                  DashboardScreen.lastVisitedLocation,
                  snController.text.trim(),
                  devName,
                  LatLng(baseLoc.latitude + 0.005, baseLoc.longitude + 0.005),
                );
                setModalState(() {});
                Navigator.pop(context);
              }
            },
            child: const Text(
              "Add Device",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDeviceDialog(int index, StateSetter setModalState) {
    final TextEditingController nameController = TextEditingController(
      text: currentDevices[index].name,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          "Edit ${currentDevices[index].sn}",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameController,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: "New Device Name",
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                setState(
                  () => currentDevices[index].name = nameController.text.trim(),
                );
                setModalState(() {});
                Navigator.pop(context);
              }
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeviceManagementModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Device Management",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isAdmin && DashboardScreen.recentLocations.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: () => _showAddDeviceDialog(setModalState),
                        icon: const Icon(
                          LucideIcons.plus,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "Add",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: currentDevices.isEmpty
                      ? Center(
                          child: Text(
                            "No devices found.",
                            style: TextStyle(color: textMuted),
                          ),
                        )
                      : ListView.builder(
                          itemCount: currentDevices.length,
                          itemBuilder: (context, index) {
                            final dev = currentDevices[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: dev.isActive
                                    ? cardColor
                                    : (AppSettings.isDarkMode
                                          ? Colors.black45
                                          : Colors.grey[100]),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: dev.isActive
                                      ? borderColor
                                      : Colors.transparent,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: dev.isActive
                                              ? dev.color
                                              : Colors.grey,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          "${dev.name} (${dev.sn})",
                                          style: TextStyle(
                                            color: dev.isActive
                                                ? textColor
                                                : Colors.grey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      if (isAdmin) ...[
                                        Switch(
                                          value: dev.isActive,
                                          activeColor: Colors.blue,
                                          onChanged: (val) {
                                            setState(() => dev.isActive = val);
                                            setModalState(() {});
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            LucideIcons.edit3,
                                            color: Colors.blue,
                                            size: 18,
                                          ),
                                          onPressed: () =>
                                              _showEditDeviceDialog(
                                                index,
                                                setModalState,
                                              ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            LucideIcons.trash2,
                                            color: Colors.redAccent,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            _deleteDevice(index);
                                            setModalState(() {});
                                            setState(() {});
                                          },
                                        ),
                                      ] else ...[
                                        Text(
                                          dev.isActive ? "Active" : "Offline",
                                          style: TextStyle(
                                            color: dev.isActive
                                                ? Colors.green
                                                : Colors.grey,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Divider(color: borderColor, height: 24),
                                  Opacity(
                                    opacity: dev.isActive ? 1.0 : 0.4,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildMiniStat(
                                          "Temp",
                                          "${dev.temp.toStringAsFixed(1)}°C",
                                          fontSize: 14,
                                        ),
                                        _buildMiniStat(
                                          "Hum",
                                          "${dev.humidity.toStringAsFixed(1)}%",
                                          fontSize: 14,
                                        ),
                                        _buildMiniStat(
                                          "Pres",
                                          "${dev.pressure.toStringAsFixed(0)} hPa",
                                          fontSize: 14,
                                        ),
                                        _buildMiniStat(
                                          "PGA",
                                          "${dev.pga.toStringAsFixed(2)}%g",
                                          fontSize: 14,
                                          color: Colors.orange,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // ✅ แสดงสถานะพลังงานและสัญญาณ ใน List อุปกรณ์
                                  if (dev.isActive) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppSettings.isDarkMode
                                            ? Colors.black26
                                            : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                dev.isPluggedIn
                                                    ? LucideIcons.plug
                                                    : LucideIcons.zap,
                                                color: dev.isPluggedIn
                                                    ? Colors.green
                                                    : Colors.orange,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                dev.isPluggedIn
                                                    ? "AC Power"
                                                    : "Battery Mode",
                                                style: TextStyle(
                                                  color: dev.isPluggedIn
                                                      ? Colors.green
                                                      : Colors.orange,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Icon(
                                                dev.isPluggedIn
                                                    ? LucideIcons
                                                          .batteryCharging
                                                    : _getBatteryIcon(
                                                        dev.batteryLevel,
                                                      ),
                                                color: dev.isPluggedIn
                                                    ? Colors.green
                                                    : _getBatteryColor(
                                                        dev.batteryLevel,
                                                      ),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                "${dev.batteryLevel}%",
                                                style: TextStyle(
                                                  color: dev.isPluggedIn
                                                      ? Colors.green
                                                      : _getBatteryColor(
                                                          dev.batteryLevel,
                                                        ),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Icon(
                                                _getSignalIcon(
                                                  dev.signalStrength,
                                                ),
                                                color: _getSignalColor(
                                                  dev.signalStrength,
                                                ),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                _getSignalText(
                                                  dev.signalStrength,
                                                ),
                                                style: TextStyle(
                                                  color: _getSignalColor(
                                                    dev.signalStrength,
                                                  ),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double avgTemp = currentDevices.isEmpty
        ? 0
        : currentDevices.map((d) => d.temp).reduce((a, b) => a + b) /
              currentDevices.length;
    double avgHum = currentDevices.isEmpty
        ? 0
        : currentDevices.map((d) => d.humidity).reduce((a, b) => a + b) /
              currentDevices.length;
    double avgPres = currentDevices.isEmpty
        ? 0
        : currentDevices.map((d) => d.pressure).reduce((a, b) => a + b) /
              currentDevices.length;
    double avgPga = currentDevices.isEmpty
        ? 0
        : currentDevices.map((d) => d.pga).reduce((a, b) => a + b) /
              currentDevices.length;

    double displayTemp = AppSettings.tempUnit == 'Fahrenheit (°F)'
        ? (avgTemp * 9 / 5) + 32
        : avgTemp;
    String tempSymbol = AppSettings.tempUnit == 'Fahrenheit (°F)' ? '°F' : '°C';

    String userEmail = GlobalAuth.currentUser?.email ?? "Unknown User";
    String userRoleName = GlobalAuth.currentUser?.roleName ?? "Guest";

    return Scaffold(
      backgroundColor: bgColor,
      drawer: Drawer(
        backgroundColor: cardColor,
        child: Column(
          children: [
            InkWell(
              onTap: () {
                Navigator.pop(context);
                _showProfileDialog();
              },
              child: UserAccountsDrawerHeader(
                decoration: BoxDecoration(
                  color: AppSettings.isDarkMode
                      ? const Color(0xFF1E3A8A)
                      : Colors.blue,
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: cardColor,
                  child: const Icon(
                    LucideIcons.user,
                    color: Colors.blue,
                    size: 40,
                  ),
                ),
                accountName: Text(
                  userRoleName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                accountEmail: Row(
                  children: [
                    Text(
                      userEmail,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      LucideIcons.edit2,
                      size: 12,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildMenuItem(
                    LucideIcons.layoutDashboard,
                    "Dashboard",
                    isSelected: true,
                    onTap: () => Navigator.pop(context),
                  ),
                  _buildMenuItem(
                    LucideIcons.map,
                    "Location Map",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ThailandMapScreen(),
                      ),
                    ),
                  ),
                  _buildMenuItem(
                    LucideIcons.cpu,
                    isAdmin ? "Device Management" : "View Devices",
                    onTap: _showDeviceManagementModal,
                  ),
                  if (isAdmin) ...[
                    _buildMenuItem(
                      LucideIcons.list,
                      "Logs",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LogsScreen(),
                        ),
                      ),
                    ),
                    Divider(color: borderColor, indent: 20, endIndent: 20),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 20,
                        top: 10,
                        bottom: 5,
                      ),
                      child: Text(
                        "ADMIN ONLY",
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 11,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    _buildMenuItem(
                      LucideIcons.users,
                      "User Management",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserManagementScreen(),
                        ),
                      ),
                    ),
                  ],
                  Divider(color: borderColor, indent: 20, endIndent: 20),
                  _buildMenuItem(
                    LucideIcons.settings,
                    "System Settings",
                    onTap: () {
                      Navigator.pop(context);
                      _openFullSettings();
                    },
                  ),
                  _buildMenuItem(
                    LucideIcons.logOut,
                    "Logout",
                    color: Colors.redAccent,
                    onTap: () {
                      GlobalAuth.currentUser = null;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                "v1.0.0-beta",
                style: TextStyle(color: textMuted, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: "open menu",
            icon: Icon(LucideIcons.menu, color: textColor),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: dropdownColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: DashboardScreen.recentLocations.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      child: Text(
                        "EMPTY",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: DashboardScreen.lastVisitedLocation,
                        dropdownColor: dropdownColor,
                        icon: const Icon(
                          LucideIcons.chevronDown,
                          color: Colors.blue,
                          size: 16,
                        ),
                        items: DashboardScreen.recentLocations.map((
                          String value,
                        ) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: SizedBox(
                              width: 160,
                              child: Text(
                                value,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              DashboardScreen.lastVisitedLocation = newValue;
                              if (currentDevices.isNotEmpty) {
                                _zoomPanBehavior.focalLatLng = MapLatLng(
                                  currentDevices.first.location.latitude,
                                  currentDevices.first.location.longitude,
                                );
                              }
                            });
                          }
                        },
                      ),
                    ),
            ),
          ],
        ),
        actions: const [SizedBox(width: 48)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: DashboardScreen.recentLocations.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: Column(
                    children: [
                      Icon(
                        LucideIcons.mapPinOff,
                        size: 60,
                        color: textMuted.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "EMPTY",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textMuted,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Go to the Map to select a new location.",
                        style: TextStyle(color: textMuted),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ThailandMapScreen(),
                          ),
                        ),
                        icon: const Icon(
                          LucideIcons.map,
                          color: Colors.white,
                          size: 16,
                        ),
                        label: const Text(
                          "Open Map",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildEnvCard(
                          "Temperature",
                          "${displayTemp.toStringAsFixed(1)} $tempSymbol",
                          LucideIcons.thermometer,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildEnvCard(
                          "Humidity",
                          "${avgHum.toStringAsFixed(1)} %",
                          LucideIcons.droplets,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildEnvCard(
                          "Pressure",
                          "${avgPres.toStringAsFixed(0)} hPa",
                          LucideIcons.cloudRain,
                          Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildEnvCard(
                          "Vibration",
                          "${avgPga.toStringAsFixed(2)} %g",
                          LucideIcons.activity,
                          Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ✅ 9. UI กราฟใหม่ทั้งหมด
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "PGA Analysis",
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppSettings.isDarkMode
                              ? Colors.white10
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () => setState(() => _isLiveMode = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _isLiveMode
                                      ? Colors.blue
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "Live 🔴",
                                  style: TextStyle(
                                    color: _isLiveMode
                                        ? Colors.white
                                        : textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() => _isLiveMode = false);
                                if (currentDevices.isNotEmpty &&
                                    currentDevices.first.historySpots.isEmpty) {
                                  _fetchHistoryData();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: !_isLiveMode
                                      ? Colors.blue
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "History 📅",
                                  style: TextStyle(
                                    color: !_isLiveMode
                                        ? Colors.white
                                        : textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // แถบเลือกวันเวลา (แสดงเฉพาะโหมด History)
                  if (!_isLiveMode)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.calendar,
                            color: Colors.blue,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Period:",
                            style: TextStyle(color: textMuted, fontSize: 12),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () => _selectDateTime(context, true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppSettings.isDarkMode
                                    ? Colors.white10
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _startDate != null
                                    ? DateFormat(
                                        'dd MMM, HH:mm',
                                      ).format(_startDate!)
                                    : 'Start',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              "-",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          InkWell(
                            onTap: () => _selectDateTime(context, false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppSettings.isDarkMode
                                    ? Colors.white10
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _endDate != null
                                    ? DateFormat(
                                        'dd MMM, HH:mm',
                                      ).format(_endDate!)
                                    : 'End',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Interactive Legend (กดเปิดปิดกราฟได้)
                  if (currentDevices.isNotEmpty)
                    Wrap(
                      spacing: 12,
                      children: currentDevices.where((d) => d.isActive).map((
                        d,
                      ) {
                        bool isHidden = _hiddenDeviceSn.contains(d.sn);
                        return InkWell(
                          onTap: () {
                            setState(() {
                              isHidden
                                  ? _hiddenDeviceSn.remove(d.sn)
                                  : _hiddenDeviceSn.add(d.sn);
                            });
                          },
                          child: Opacity(
                            opacity: isHidden ? 0.4 : 1.0,
                            child: _legendItem(d.name, d.color),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),

                  // กราฟ
                  Container(
                    height: 300,
                    padding: const EdgeInsets.fromLTRB(10, 24, 24, 10),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: currentDevices.isEmpty
                        ? Center(
                            child: Text(
                              "No Active Devices",
                              style: TextStyle(color: textMuted),
                            ),
                          )
                        : LineChart(
                            LineChartData(
                              minY: 0,
                              maxY: 20,
                              lineTouchData: _lineTouchData,
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (v) =>
                                    FlLine(color: borderColor, strokeWidth: 1),
                              ),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(),
                                rightTitles: const AxisTitles(),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 22,
                                    getTitlesWidget: (value, meta) {
                                      DateTime time = _isLiveMode
                                          ? DateTime.fromMillisecondsSinceEpoch(
                                              _startTime +
                                                  (value * 1000).toInt(),
                                            )
                                          : DateTime.fromMillisecondsSinceEpoch(
                                              (value * 1000).toInt(),
                                            );
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8.0,
                                        ),
                                        child: Text(
                                          DateFormat(
                                            _isLiveMode
                                                ? 'HH:mm:ss'
                                                : 'dd/MM HH:mm',
                                          ).format(time),
                                          style: TextStyle(
                                            color: textMuted,
                                            fontSize: 8,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: (v, meta) => Text(
                                      v.toInt().toString(),
                                      style: TextStyle(
                                        color: textMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              extraLinesData: ExtraLinesData(
                                horizontalLines: [
                                  HorizontalLine(
                                    y: 10,
                                    color: Colors.redAccent.withOpacity(0.8),
                                    strokeWidth: 1,
                                    dashArray: [5, 5],
                                    label: HorizontalLineLabel(
                                      show: true,
                                      alignment: Alignment.topRight,
                                      padding: const EdgeInsets.only(
                                        right: 5,
                                        bottom: 5,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      labelResolver: (line) =>
                                          'Warning (10 %g)',
                                    ),
                                  ),
                                ],
                              ),
                              // ✅ ใช้ liveSpots หรือ historySpots ตามโหมด
                              lineBarsData: currentDevices
                                  .where(
                                    (d) =>
                                        d.isActive &&
                                        !_hiddenDeviceSn.contains(d.sn),
                                  )
                                  .map(
                                    (d) => LineChartBarData(
                                      spots: _isLiveMode
                                          ? d.liveSpots
                                          : d.historySpots,
                                      isCurved: true,
                                      color: d.color,
                                      barWidth: 3,
                                      dotData: const FlDotData(show: false),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: d.color.withOpacity(0.1),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                  ),
                  const SizedBox(height: 32),

                  // ✅ แสดง Card สถานะในหน้าหลัก
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Primary Device Status",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showDeviceManagementModal,
                        icon: Icon(
                          isAdmin ? LucideIcons.settings : LucideIcons.eye,
                          size: 16,
                          color: Colors.blue,
                        ),
                        label: Text(
                          isAdmin ? "Manage All" : "View Devices",
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (currentDevices.isNotEmpty &&
                      currentDevices.first.isActive)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: currentDevices.first.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${currentDevices.first.name} (${currentDevices.first.sn})",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Active Devices in Zone: ${currentDevices.where((d) => d.isActive).length}",
                                      style: TextStyle(
                                        color: textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppSettings.isDarkMode
                                  ? Colors.black26
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      currentDevices.first.isPluggedIn
                                          ? LucideIcons.plug
                                          : LucideIcons.zap,
                                      color: currentDevices.first.isPluggedIn
                                          ? Colors.green
                                          : Colors.orange,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      currentDevices.first.isPluggedIn
                                          ? "AC Power"
                                          : "Battery Mode",
                                      style: TextStyle(
                                        color: currentDevices.first.isPluggedIn
                                            ? Colors.green
                                            : Colors.orange,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      currentDevices.first.isPluggedIn
                                          ? LucideIcons.batteryCharging
                                          : _getBatteryIcon(
                                              currentDevices.first.batteryLevel,
                                            ),
                                      color: currentDevices.first.isPluggedIn
                                          ? Colors.green
                                          : _getBatteryColor(
                                              currentDevices.first.batteryLevel,
                                            ),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "${currentDevices.first.batteryLevel}%",
                                      style: TextStyle(
                                        color: currentDevices.first.isPluggedIn
                                            ? Colors.green
                                            : _getBatteryColor(
                                                currentDevices
                                                    .first
                                                    .batteryLevel,
                                              ),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      _getSignalIcon(
                                        currentDevices.first.signalStrength,
                                      ),
                                      color: _getSignalColor(
                                        currentDevices.first.signalStrength,
                                      ),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _getSignalText(
                                        currentDevices.first.signalStrength,
                                      ),
                                      style: TextStyle(
                                        color: _getSignalColor(
                                          currentDevices.first.signalStrength,
                                        ),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Text(
                        "Location",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 350,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: currentDevices.isEmpty
                          ? Center(
                              child: Text(
                                "No GPS Data",
                                style: TextStyle(color: textMuted),
                              ),
                            )
                          : SfMaps(
                              layers: [
                                MapTileLayer(
                                  urlTemplate: mapUrl,
                                  zoomPanBehavior: _zoomPanBehavior,
                                  initialMarkersCount: currentDevices
                                      .where((d) => d.isActive)
                                      .length,
                                  markerBuilder:
                                      (BuildContext context, int index) {
                                        final activeDevices = currentDevices
                                            .where((d) => d.isActive)
                                            .toList();
                                        final d = activeDevices[index];
                                        return MapMarker(
                                          latitude: d.location.latitude,
                                          longitude: d.location.longitude,
                                          child: Icon(
                                            LucideIcons.mapPin,
                                            color: d.color,
                                            size: 30,
                                          ),
                                        );
                                      },
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }

  Widget _buildEnvCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: textMuted, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title, {
    VoidCallback? onTap,
    bool isSelected = false,
    Color? color,
  }) {
    Color effectiveColor = color ?? textColor;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.blue : effectiveColor.withOpacity(0.7),
        size: 20,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.blue : effectiveColor,
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: onTap,
      hoverColor: AppSettings.isDarkMode ? Colors.white10 : Colors.grey[100],
    );
  }

  Widget _buildMiniStat(
    String label,
    String value, {
    Color? color,
    double fontSize = 12,
  }) {
    Color effectiveColor = color ?? textColor;
    return Column(
      children: [
        Text(label, style: TextStyle(color: textMuted, fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: effectiveColor,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: textMuted, fontSize: 12)),
      ],
    );
  }
}

// ==========================================
// 4. วิดเจ็ตหน้าต่าง Settings แบบเต็มรูปแบบ
// ==========================================
class FullSettingsDialog extends StatefulWidget {
  final VoidCallback onSettingsChanged;
  const FullSettingsDialog({super.key, required this.onSettingsChanged});

  @override
  State<FullSettingsDialog> createState() => _FullSettingsDialogState();
}

class _FullSettingsDialogState extends State<FullSettingsDialog> {
  int _selectedTabIndex = 0;

  Color get cardColor => AppSettings.isDarkMode
      ? const Color(0xFF2C2C2C)
      : Colors.white; // สีของ Card
  Color get bgColor => AppSettings.isDarkMode
      ? const Color(0xFF1E1E1E)
      : Colors.grey[100]!; // สีพื้นหลัง
  Color get textColor =>
      AppSettings.isDarkMode ? Colors.white : Colors.black; // สีของข้อความ
  Color get textMuted => AppSettings.isDarkMode
      ? Colors.grey[400]!
      : Colors.grey[600]!; // สีข้อความจาง
  Color get borderColor => AppSettings.isDarkMode
      ? Colors.grey[700]!
      : Colors.grey[300]!; // สีของเส้นขอบ

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(40),
      child: Container(
        width: 800,
        height: 550,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 220,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
                border: Border(right: BorderSide(color: borderColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.settings, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          "Settings",
                          style: TextStyle(
                            color: textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildSidebarItem(
                    0,
                    "Display & Regional",
                    LucideIcons.monitor,
                  ),
                  _buildSidebarItem(1, "Notifications", LucideIcons.bell),
                  _buildSidebarItem(2, "Chart & Data", LucideIcons.barChart2),
                  _buildSidebarItem(3, "System & Support", LucideIcons.info),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: Icon(LucideIcons.x, color: textMuted),
                      padding: const EdgeInsets.all(16),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 8,
                      ),
                      child: IndexedStack(
                        index: _selectedTabIndex,
                        children: [
                          _buildDisplaySettings(),
                          _buildNotificationSettings(),
                          _buildChartSettings(),
                          _buildSystemSettings(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(int index, String title, IconData icon) {
    bool isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          border: Border(
            right: BorderSide(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.blue : textMuted),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.blue : textColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplaySettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Display & Regional",
          style: TextStyle(
            color: textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text("Dark Mode", style: TextStyle(color: textColor)),
          subtitle: Text(
            "Switch between dark and light theme",
            style: TextStyle(color: textMuted, fontSize: 12),
          ),
          value: AppSettings.isDarkMode,
          activeColor: Colors.blue,
          onChanged: (val) {
            setState(() => AppSettings.isDarkMode = val);
            widget.onSettingsChanged();
          },
        ),
        const Divider(),
        _buildDropdownRow(
          "Temperature Unit",
          ["Celsius (°C)", "Fahrenheit (°F)"],
          AppSettings.tempUnit,
          (val) {
            setState(() => AppSettings.tempUnit = val!);
            widget.onSettingsChanged();
          },
        ),
        const Divider(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            "24-Hour Time Format",
            style: TextStyle(color: textColor),
          ),
          value: AppSettings.is24HourFormat,
          activeColor: Colors.blue,
          onChanged: (val) => setState(() => AppSettings.is24HourFormat = val),
        ),
      ],
    );
  }

  Widget _buildNotificationSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Alerts & Notifications",
          style: TextStyle(
            color: textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            "Critical PGA Alerts",
            style: TextStyle(color: textColor),
          ),
          subtitle: Text(
            "Show popup when vibration exceeds safe limit",
            style: TextStyle(color: textMuted, fontSize: 12),
          ),
          value: AppSettings.criticalAlerts,
          activeColor: Colors.redAccent,
          onChanged: (val) => setState(() => AppSettings.criticalAlerts = val),
        ),
        const Divider(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            "Device Offline Warning",
            style: TextStyle(color: textColor),
          ),
          subtitle: Text(
            "Notify when a sensor node goes offline",
            style: TextStyle(color: textMuted, fontSize: 12),
          ),
          value: AppSettings.offlineWarning,
          activeColor: Colors.orange,
          onChanged: (val) => setState(() => AppSettings.offlineWarning = val),
        ),
        const Divider(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text("Mute Alert Sounds", style: TextStyle(color: textColor)),
          value: AppSettings.muteSounds,
          activeColor: Colors.blue,
          onChanged: (val) => setState(() => AppSettings.muteSounds = val),
        ),
      ],
    );
  }

  Widget _buildChartSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Chart & Data Preferences",
          style: TextStyle(
            color: textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        _buildDropdownRow(
          "Chart Update Rate",
          ["1 Second", "3 Seconds", "5 Seconds"],
          AppSettings.chartUpdateRate,
          (val) {
            setState(() => AppSettings.chartUpdateRate = val!);
            widget.onSettingsChanged();
          },
        ),
        const Divider(),
        _buildDropdownRow(
          "Default Data View (Timeline)",
          ["30 Seconds", "60 Seconds", "5 Minutes"],
          AppSettings.chartDataView,
          (val) {
            setState(() => AppSettings.chartDataView = val!);
            widget.onSettingsChanged();
          },
        ),
      ],
    );
  }

  Widget _buildSystemSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "System & Support",
          style: TextStyle(
            color: textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.info, color: Colors.blue),
          title: Text("BuBeacon Version", style: TextStyle(color: textColor)),
          trailing: Text("v1.0.0-beta", style: TextStyle(color: textMuted)),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.mail, color: Colors.orange),
          title: Text("Contact Support", style: TextStyle(color: textColor)),
          subtitle: Text(
            "support@bubeacon.com",
            style: TextStyle(color: textMuted),
          ),
          trailing: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: bgColor,
              elevation: 0,
              side: BorderSide(color: borderColor),
            ),
            child: Text("Send Email", style: TextStyle(color: textColor)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownRow(
    String label,
    List<String> options,
    String currentValue,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: textColor, fontSize: 16)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentValue,
                dropdownColor: bgColor,
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
                items: options
                    .map(
                      (String val) => DropdownMenuItem<String>(
                        value: val,
                        child: Text(val),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
