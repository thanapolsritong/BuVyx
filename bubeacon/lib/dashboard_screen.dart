import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_maps/maps.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
// 2. Model สำหรับอุปกรณ์ (รองรับค่า DSP)
// ==========================================
class ConnectedDevice {
  String docId;
  String sn;
  String name;
  String zone;
  Color color;
  LatLng location;

  List<FlSpot> liveSpots = [];
  List<FlSpot> historySpots = [];

  double currentRms = 0.0;
  double maxPga = 0.0;
  List<FlSpot> fftSpots = [];
  List<List<double>> spectrogramData = [];

  double pga = 0.0;
  double temp = 28.5;
  double humidity = 55.0;
  double pressure = 1012.0;
  double altitude = 15.0;
  bool isActive = true;

  bool isPluggedIn;
  int batteryLevel;
  int signalStrength;

  ConnectedDevice({
    required this.docId,
    required this.sn,
    required this.name,
    required this.zone,
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

  static String lastVisitedLocation = "";
  static List<String> recentLocations = [];

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<ConnectedDevice> allDevices = [];
  StreamSubscription<QuerySnapshot>? _deviceSubscription;

  // ✨ ตัวกระตุ้นให้ Modal รีเฟรชอัตโนมัติแบบ Real-time
  final ValueNotifier<int> _deviceUpdateNotifier = ValueNotifier<int>(0);

  int _startTime = DateTime.now().millisecondsSinceEpoch;

  bool _isLiveMode = true;
  List<String> _hiddenDeviceSn = [];
  DateTime? _startDate;
  DateTime? _endDate;

  late MapZoomPanBehavior _zoomPanBehavior;

  String userName = "Loading...";
  String userEmail = "Loading...";
  String userOrg = "Loading...";
  String userRoleString = "User";
  UserRole currentUserRole = UserRole.normalUser;

  bool get canManageSystem =>
      currentUserRole == UserRole.superAdmin ||
      currentUserRole == UserRole.secondAdmin;

  final List<Color> deviceColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.pink,
  ];

  List<ConnectedDevice> get currentDevices => allDevices
      .where((d) => d.zone == DashboardScreen.lastVisitedLocation)
      .toList();

  Color get bgColor =>
      AppSettings.isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[50]!;
  Color get cardColor =>
      AppSettings.isDarkMode ? const Color(0xFF2C2C2C) : Colors.white;
  Color get borderColor =>
      AppSettings.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;
  Color get textColor => AppSettings.isDarkMode ? Colors.white : Colors.black;
  Color get textMuted =>
      AppSettings.isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
  Color get dropdownColor =>
      AppSettings.isDarkMode ? const Color(0xFF2C2C2C) : Colors.white;

  String get mapUrl => AppSettings.isDarkMode
      ? 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
      : 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';

  @override
  void initState() {
    super.initState();
    _fetchFirebaseUserProfile();
    _listenToDevicesFromFirestore();

    _zoomPanBehavior = MapZoomPanBehavior(
      focalLatLng: const MapLatLng(14.0208, 100.5250),
      zoomLevel: 15,
      enableDoubleTapZooming: true,
      enablePinching: true,
      enablePanning: true,
      enableMouseWheelZooming: true,
    );

    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(const Duration(days: 7));
  }

  @override
  void dispose() {
    _deviceSubscription?.cancel();
    _deviceUpdateNotifier.dispose(); // คืนค่าหน่วยความจำ
    super.dispose();
  }

  void _listenToDevicesFromFirestore() {
    _deviceSubscription = FirebaseFirestore.instance
        .collection('devices')
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;

          setState(() {
            for (var change in snapshot.docChanges) {
              final data = change.doc.data();
              final docId = change.doc.id;

              if (data == null) continue;

              if (change.type == DocumentChangeType.added) {
                if (!allDevices.any((d) => d.docId == docId)) {
                  allDevices.add(
                    ConnectedDevice(
                      docId: docId,
                      sn: data['sn'] ?? 'Unknown',
                      name: data['name'] ?? 'Unnamed',
                      zone: data['zone'] ?? 'Unknown',
                      color:
                          deviceColors[allDevices.length % deviceColors.length],
                      location: LatLng(
                        (data['lat'] ?? 14.0).toDouble(),
                        (data['lng'] ?? 100.5).toDouble(),
                      ),
                      isActive: data['isActive'] ?? true,
                      isPluggedIn: data['isPluggedIn'] ?? true,
                      batteryLevel: (data['batteryLevel'] ?? 100).toInt(),
                      signalStrength: (data['signalStrength'] ?? 4).toInt(),
                    ),
                  );
                }
              } else if (change.type == DocumentChangeType.modified) {
                final index = allDevices.indexWhere((d) => d.docId == docId);
                if (index != -1) {
                  allDevices[index].name =
                      data['name'] ?? allDevices[index].name;
                  allDevices[index].isActive =
                      data['isActive'] ?? allDevices[index].isActive;
                  allDevices[index].isPluggedIn =
                      data['isPluggedIn'] ?? allDevices[index].isPluggedIn;
                  allDevices[index].batteryLevel =
                      (data['batteryLevel'] ?? allDevices[index].batteryLevel)
                          .toInt();
                  allDevices[index].signalStrength =
                      (data['signalStrength'] ??
                              allDevices[index].signalStrength)
                          .toInt();

                  allDevices[index].pga = (data['pga'] ?? allDevices[index].pga)
                      .toDouble();
                  allDevices[index].temp =
                      (data['temp'] ?? allDevices[index].temp).toDouble();
                  allDevices[index].humidity =
                      (data['humidity'] ?? allDevices[index].humidity)
                          .toDouble();
                  allDevices[index].pressure =
                      (data['pressure'] ?? allDevices[index].pressure)
                          .toDouble();

                  allDevices[index].currentRms =
                      (data['rms'] ?? allDevices[index].currentRms).toDouble();
                  allDevices[index].maxPga =
                      (data['max_pga'] ?? allDevices[index].maxPga).toDouble();

                  if (data['fftSpots'] != null) {
                    List<dynamic> rawFft = data['fftSpots'];
                    allDevices[index].fftSpots = rawFft
                        .map(
                          (e) => FlSpot(
                            (e['x'] ?? 0).toDouble(),
                            (e['y'] ?? 0).toDouble(),
                          ),
                        )
                        .toList();
                  }

                  if (data['spectrogram'] != null) {
                    List<dynamic> rawSpec = data['spectrogram'];
                    allDevices[index].spectrogramData = rawSpec
                        .map(
                          (col) => List<double>.from(
                            col.map((v) => (v ?? 0.0).toDouble()),
                          ),
                        )
                        .toList();
                  }

                  if (_isLiveMode && data['pga'] != null) {
                    double timeKey =
                        (DateTime.now().millisecondsSinceEpoch - _startTime) /
                        1000;
                    allDevices[index].liveSpots.add(
                      FlSpot(timeKey, allDevices[index].pga),
                    );
                    int maxSpots = AppSettings.chartDataView == '5 Minutes'
                        ? 300
                        : (AppSettings.chartDataView == '60 Seconds' ? 60 : 30);
                    if (allDevices[index].liveSpots.length > maxSpots) {
                      allDevices[index].liveSpots.removeAt(0);
                    }
                  }
                }
              } else if (change.type == DocumentChangeType.removed) {
                allDevices.removeWhere((d) => d.docId == docId);
              }
            }

            if (currentDevices.isNotEmpty) {
              _zoomPanBehavior.focalLatLng = MapLatLng(
                currentDevices.first.location.latitude,
                currentDevices.first.location.longitude,
              );
            }
          });

          // ✨ กระตุ้นให้ Modal รีเฟรชอัตโนมัติเมื่อ Firebase มีการอัปเดต!
          _deviceUpdateNotifier.value++;
        });
  }

  Future<void> _fetchFirebaseUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() => userEmail = user.email ?? "Unknown Email");
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            userName = data['name'] ?? "Unknown Name";
            userOrg = data['organization'] ?? "BuVyx Network";

            String dbRole = data['role'] ?? 'User';
            if (dbRole == 'Admin' || dbRole == 'SuperAdmin') {
              currentUserRole = UserRole.superAdmin;
              userRoleString = "Super Admin";
            } else if (dbRole == 'SecondAdmin') {
              currentUserRole = UserRole.secondAdmin;
              userRoleString = "Second Admin";
            } else {
              currentUserRole = UserRole.normalUser;
              userRoleString = "User";
            }

            if (data.containsKey('recentLocations')) {
              DashboardScreen.recentLocations = List<String>.from(
                data['recentLocations'],
              );
            }
            if (data.containsKey('lastVisitedLocation')) {
              String savedLoc = data['lastVisitedLocation'];
              if (DashboardScreen.recentLocations.contains(savedLoc)) {
                DashboardScreen.lastVisitedLocation = savedLoc;
              }
            }
            if (DashboardScreen.lastVisitedLocation.isEmpty &&
                DashboardScreen.recentLocations.isNotEmpty) {
              DashboardScreen.lastVisitedLocation =
                  DashboardScreen.recentLocations.first;
            }

            if (data.containsKey('settings')) {
              final config = data['settings'];
              AppSettings.isDarkMode = config['isDarkMode'] ?? true;
              AppSettings.tempUnit = config['tempUnit'] ?? 'Celsius (°C)';
              AppSettings.is24HourFormat = config['is24HourFormat'] ?? true;
              AppSettings.criticalAlerts = config['criticalAlerts'] ?? true;
              AppSettings.offlineWarning = config['offlineWarning'] ?? true;
              AppSettings.muteSounds = config['muteSounds'] ?? false;
              AppSettings.chartUpdateRate =
                  config['chartUpdateRate'] ?? '1 Second';
              AppSettings.chartDataView =
                  config['chartDataView'] ?? '30 Seconds';
            }
          });
        }
      } catch (e) {
        print("Error fetching user profile: $e");
      }
    }
  }

  Future<void> _saveSettingsToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'settings': {
          'isDarkMode': AppSettings.isDarkMode,
          'tempUnit': AppSettings.tempUnit,
          'is24HourFormat': AppSettings.is24HourFormat,
          'criticalAlerts': AppSettings.criticalAlerts,
          'offlineWarning': AppSettings.offlineWarning,
          'muteSounds': AppSettings.muteSounds,
          'chartUpdateRate': AppSettings.chartUpdateRate,
          'chartDataView': AppSettings.chartDataView,
        },
        'lastVisitedLocation': DashboardScreen.lastVisitedLocation,
        'recentLocations': DashboardScreen.recentLocations,
      }, SetOptions(merge: true));
    }
  }

  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _fetchHistoryData() {
    if (_startDate == null || _endDate == null) return;
    setState(() {
      for (var device in currentDevices) {
        device.historySpots.clear();
      }
    });
  }

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

  Future<void> _addDeviceToFirestore(
    String location,
    String sn,
    String name,
    LatLng loc,
  ) async {
    if (location.isEmpty || location == "EMPTY") return;
    try {
      await FirebaseFirestore.instance.collection('devices').doc(sn).set({
        'sn': sn,
        'name': name,
        'zone': location,
        'lat': loc.latitude,
        'lng': loc.longitude,
        'isActive': true,
        'isPluggedIn': true,
        'batteryLevel': 100,
        'signalStrength': 4,
        'pga': 0.0,
        'temp': 28.0,
        'humidity': 50.0,
        'pressure': 1010.0,
        'rms': 0.0,
        'max_pga': 0.0,
        'fftSpots': [],
        'spectrogram': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Device Added Successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to add device: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildSpectrogram(ConnectedDevice device) {
    if (device.spectrogramData.isEmpty)
      return const Center(
        child: Text(
          "Waiting for signal data...",
          style: TextStyle(fontSize: 10, color: Colors.grey),
        ),
      );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: device.spectrogramData.map((col) {
        return Expanded(
          child: Column(
            verticalDirection: VerticalDirection.up,
            children: col.map((val) {
              Color heatColor =
                  Color.lerp(
                    Color.lerp(Colors.blue.shade900, Colors.green, val * 2),
                    Colors.redAccent,
                    max(0, (val - 0.5) * 2),
                  ) ??
                  Colors.transparent;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.all(0.5),
                  decoration: BoxDecoration(
                    color: heatColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Color _getBatteryColor(int level) {
    if (level > 60) return Colors.green;
    if (level > 20) return Colors.orange;
    return Colors.redAccent;
  }

  IconData _getBatteryIcon(int level) {
    if (level > 80) return LucideIcons.batteryFull;
    if (level > 40) return LucideIcons.batteryMedium;
    if (level > 10) return LucideIcons.batteryLow;
    return LucideIcons.battery;
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
    TextEditingController newPassCtrl = TextEditingController();
    bool isSaving = false;

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
                Text("Name", style: TextStyle(color: textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                TextField(
                  controller: TextEditingController(text: userName),
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
                  "Email Address",
                  style: TextStyle(color: textMuted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: TextEditingController(text: userEmail),
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
                  "Organization",
                  style: TextStyle(color: textMuted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: TextEditingController(text: userOrg),
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
                  "Account Role",
                  style: TextStyle(color: textMuted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: TextEditingController(text: userRoleString),
                  enabled: false,
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.blue.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  "Change Password",
                  style: TextStyle(color: textMuted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: newPassCtrl,
                  obscureText: true,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: "Enter new password (min 6 chars)",
                    hintStyle: TextStyle(color: textMuted),
                    filled: true,
                    fillColor: AppSettings.isDarkMode
                        ? Colors.black26
                        : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Close", style: TextStyle(color: textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (newPassCtrl.text.trim().length >= 6) {
                          setDialogState(() => isSaving = true);
                          try {
                            await FirebaseAuth.instance.currentUser!
                                .updatePassword(newPassCtrl.text.trim());
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Password updated successfully!",
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Failed to update password: $e"),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          } finally {
                            setDialogState(() => isSaving = false);
                          }
                        } else if (newPassCtrl.text.trim().isNotEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Password must be at least 6 characters.",
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Save Password",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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
          _saveSettingsToFirestore();
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
                    : const LatLng(14.0208, 100.5250);

                _addDeviceToFirestore(
                  DashboardScreen.lastVisitedLocation,
                  snController.text.trim(),
                  devName,
                  LatLng(
                    baseLoc.latitude + (Random().nextDouble() * 0.005),
                    baseLoc.longitude + (Random().nextDouble() * 0.005),
                  ),
                );

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

  void _showEditDeviceDialog(
    ConnectedDevice device,
    StateSetter setModalState,
  ) {
    final TextEditingController nameController = TextEditingController(
      text: device.name,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          "Edit ${device.sn}",
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
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('devices')
                    .doc(device.docId)
                    .update({'name': nameController.text.trim()});
                if (mounted) Navigator.pop(context);
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
                    if (canManageSystem &&
                        DashboardScreen.recentLocations.isNotEmpty)
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
                  // ✨ ครอบ ListView ไว้ด้วย ValueListenableBuilder เพื่อให้มันรีเฟรชหน้าต่างทันที!
                  child: ValueListenableBuilder<int>(
                    valueListenable: _deviceUpdateNotifier,
                    builder: (context, value, child) {
                      return currentDevices.isEmpty
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
                                          if (canManageSystem) ...[
                                            Switch(
                                              value: dev.isActive,
                                              activeColor: Colors.blue,
                                              onChanged: (val) async {
                                                // ✨ Optimistic Update: เปลี่ยน UI ทันที! ทำให้สวิตช์ไม่ค้าง
                                                setModalState(() {
                                                  dev.isActive = val;
                                                });
                                                setState(
                                                  () {},
                                                ); // อัปเดตหน้า Dashboard ด้วย

                                                await FirebaseFirestore.instance
                                                    .collection('devices')
                                                    .doc(dev.docId)
                                                    .update({'isActive': val});
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
                                                    dev,
                                                    setModalState,
                                                  ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                LucideIcons.trash2,
                                                color: Colors.redAccent,
                                                size: 18,
                                              ),
                                              onPressed: () async {
                                                await FirebaseFirestore.instance
                                                    .collection('devices')
                                                    .doc(dev.docId)
                                                    .delete();
                                              },
                                            ),
                                          ] else ...[
                                            Text(
                                              dev.isActive
                                                  ? "Active"
                                                  : "Offline",
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
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                      fontWeight:
                                                          FontWeight.bold,
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
                  userRoleString,
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
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ThailandMapScreen(),
                        ),
                      );
                      // 📌 เซฟข้อมูลทันทีเมื่อกลับมาจากหน้า Map
                      _saveSettingsToFirestore();
                      setState(() {});
                    },
                  ),
                  _buildMenuItem(
                    LucideIcons.cpu,
                    canManageSystem ? "Device Management" : "View Devices",
                    onTap: _showDeviceManagementModal,
                  ),
                  if (canManageSystem) ...[
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
                        "MANAGEMENT",
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
                    onTap: _handleLogout,
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
                            // 📌 เซฟทันทีที่ผู้ใช้เปลี่ยนตำแหน่งจาก Dropdown
                            _saveSettingsToFirestore();
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
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ThailandMapScreen(),
                            ),
                          );
                          // 📌 เซฟข้อมูลเมื่อกลับมาจาก Map แบบหน้าว่างๆ
                          _saveSettingsToFirestore();
                          setState(() {});
                        },
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

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "PGA Analysis (Time Domain)",
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

                  // กราฟ PGA
                  Container(
                    height: 300,
                    padding: const EdgeInsets.fromLTRB(10, 24, 24, 10),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: currentDevices.where((d) => d.isActive).isEmpty
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

                  // ==========================================
                  // ✨ Advanced Signal Processing (DSP) ✨
                  // ==========================================
                  Text(
                    "Advanced Signal Analysis (DSP)",
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (currentDevices.isNotEmpty &&
                      currentDevices.first.isActive)
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Container(
                                height: 250,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      LucideIcons.activitySquare,
                                      color: Colors.cyanAccent,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      "Energy (RMS)",
                                      style: TextStyle(
                                        color: textMuted,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      "${currentDevices.first.currentRms.toStringAsFixed(3)} g",
                                      style: TextStyle(
                                        color: Colors.cyanAccent,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Divider(height: 30),
                                    Text(
                                      "Peak Value (Max)",
                                      style: TextStyle(
                                        color: textMuted,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      "${currentDevices.first.maxPga.toStringAsFixed(2)} %g",
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: Container(
                                height: 250,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Frequency Spectrum (FFT)",
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      "Amplitude vs Frequency (Hz)",
                                      style: TextStyle(
                                        color: textMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child:
                                          currentDevices.first.fftSpots.isEmpty
                                          ? Center(
                                              child: Text(
                                                "Waiting for FFT Data...",
                                                style: TextStyle(
                                                  color: textMuted,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            )
                                          : LineChart(
                                              LineChartData(
                                                minX: 0,
                                                maxX: 50,
                                                minY: 0,
                                                maxY: 12,
                                                gridData: const FlGridData(
                                                  show: false,
                                                ),
                                                titlesData: FlTitlesData(
                                                  topTitles: const AxisTitles(),
                                                  rightTitles:
                                                      const AxisTitles(),
                                                  bottomTitles: AxisTitles(
                                                    sideTitles: SideTitles(
                                                      showTitles: true,
                                                      reservedSize: 20,
                                                      getTitlesWidget:
                                                          (v, meta) => Text(
                                                            "${v.toInt()}Hz",
                                                            style: TextStyle(
                                                              color: textMuted,
                                                              fontSize: 10,
                                                            ),
                                                          ),
                                                    ),
                                                  ),
                                                  leftTitles:
                                                      const AxisTitles(),
                                                ),
                                                borderData: FlBorderData(
                                                  show: false,
                                                ),
                                                lineBarsData: [
                                                  LineChartBarData(
                                                    spots: currentDevices
                                                        .first
                                                        .fftSpots,
                                                    isCurved: true,
                                                    color: Colors.cyanAccent,
                                                    barWidth: 2,
                                                    dotData: const FlDotData(
                                                      show: false,
                                                    ),
                                                    belowBarData: BarAreaData(
                                                      show: true,
                                                      color: Colors.cyanAccent
                                                          .withOpacity(0.2),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 180,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Spectrogram (Time-Frequency)",
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        "Low Intensity ",
                                        style: TextStyle(
                                          color: textMuted,
                                          fontSize: 10,
                                        ),
                                      ),
                                      Container(
                                        width: 40,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.blue,
                                              Colors.green,
                                              Colors.red,
                                            ],
                                          ),
                                        ),
                                      ),
                                      Text(
                                        " High Intensity",
                                        style: TextStyle(
                                          color: textMuted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Container(
                                  color: AppSettings.isDarkMode
                                      ? Colors.black45
                                      : Colors.grey[200],
                                  child: _buildSpectrogram(
                                    currentDevices.first,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Past",
                                    style: TextStyle(
                                      color: textMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    "Time ->",
                                    style: TextStyle(
                                      color: textMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    "Now",
                                    style: TextStyle(
                                      color: textMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 32),

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
                          canManageSystem
                              ? LucideIcons.settings
                              : LucideIcons.eye,
                          size: 16,
                          color: Colors.blue,
                        ),
                        label: Text(
                          canManageSystem ? "Manage All" : "View Devices",
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

  Color get cardColor =>
      AppSettings.isDarkMode ? const Color(0xFF2C2C2C) : Colors.white;
  Color get bgColor =>
      AppSettings.isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[100]!;
  Color get textColor => AppSettings.isDarkMode ? Colors.white : Colors.black;
  Color get textMuted =>
      AppSettings.isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
  Color get borderColor =>
      AppSettings.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;

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
          onChanged: (val) {
            setState(() => AppSettings.is24HourFormat = val);
            widget.onSettingsChanged();
          },
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
          onChanged: (val) {
            setState(() => AppSettings.criticalAlerts = val);
            widget.onSettingsChanged();
          },
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
          onChanged: (val) {
            setState(() => AppSettings.offlineWarning = val);
            widget.onSettingsChanged();
          },
        ),
        const Divider(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text("Mute Alert Sounds", style: TextStyle(color: textColor)),
          value: AppSettings.muteSounds,
          activeColor: Colors.blue,
          onChanged: (val) {
            setState(() => AppSettings.muteSounds = val);
            widget.onSettingsChanged();
          },
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
          title: Text("BuVyx Version", style: TextStyle(color: textColor)),
          trailing: Text("v1.0.0-beta", style: TextStyle(color: textMuted)),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.mail, color: Colors.orange),
          title: Text("Contact Support", style: TextStyle(color: textColor)),
          subtitle: Text(
            "support@buvyx.com",
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
