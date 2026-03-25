import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_maps/maps.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_screen.dart';

// ==========================================
// คลาสสำหรับเก็บข้อมูล Marker บนแผนที่
// ==========================================
class MapDeviceMarker {
  final String id;
  final String name;
  final String sn;
  final String zone;
  final double lat;
  final double lng;
  final bool isActive;

  MapDeviceMarker({
    required this.id,
    required this.name,
    required this.sn,
    required this.zone,
    required this.lat,
    required this.lng,
    required this.isActive,
  });
}

class ThailandMapScreen extends StatefulWidget {
  const ThailandMapScreen({super.key});

  @override
  State<ThailandMapScreen> createState() => _ThailandMapScreenState();
}

class _ThailandMapScreenState extends State<ThailandMapScreen>
    with SingleTickerProviderStateMixin {
  static String? lastVisitedProvince = "Bangkok Metropolis";

  late MapShapeSource _mapSource;
  late MapZoomPanBehavior _zoomPanBehavior;
  late MapShapeLayerController _layerController;
  int _selectedIndex = -1;

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  late AnimationController _panelController;
  late Animation<Offset> _panelSlideAnimation;
  String? _selectedProvinceForPanel;

  // --- ตัวแปรสำหรับข้อมูลอุปกรณ์จริงจาก Firestore ---
  List<MapDeviceMarker> _realDevices = [];
  StreamSubscription<QuerySnapshot>? _deviceSubscription;

  final List<Map<String, dynamic>> _provinces = [
    {"name": "Amnat Charoen", "area": 3161.0, "lat": 15.8657, "lng": 104.6258},
    {"name": "Ang Thong", "area": 968.0, "lat": 14.5896, "lng": 100.4550},
    {
      "name": "Phra Nakhon Si Ayutthaya",
      "displayName": "Ayutthaya",
      "area": 2556.0,
      "lat": 14.3532,
      "lng": 100.5684,
    },
    {
      "name": "Bangkok Metropolis",
      "displayName": "Bangkok",
      "area": 1569.0,
      "lat": 13.7563,
      "lng": 100.5018,
    },
    {"name": "Bueng Kan", "area": 4305.0, "lat": 18.3605, "lng": 103.6520},
    {
      "name": "Buri Ram",
      "displayName": "Buriram",
      "area": 10322.0,
      "lat": 14.9930,
      "lng": 103.1029,
    },
    {"name": "Chachoengsao", "area": 5351.0, "lat": 13.6904, "lng": 101.0718},
    {"name": "Chai Nat", "area": 2469.0, "lat": 15.1852, "lng": 100.1251},
    {"name": "Chaiyaphum", "area": 12778.0, "lat": 15.8068, "lng": 102.0315},
    {"name": "Chanthaburi", "area": 6338.0, "lat": 12.6114, "lng": 102.1039},
    {
      "name": "Chiang Mai",
      "displayName": "Chiang Mai",
      "area": 20107.0,
      "lat": 18.7883,
      "lng": 98.9853,
    },
    {"name": "Chiang Rai", "area": 11678.0, "lat": 19.9105, "lng": 99.8406},
    {
      "name": "Chon Buri",
      "displayName": "Chonburi",
      "area": 4363.0,
      "lat": 13.3611,
      "lng": 100.9847,
    },
    {"name": "Chumphon", "area": 6009.0, "lat": 10.4930, "lng": 99.1800},
    {"name": "Kalasin", "area": 6946.0, "lat": 16.4328, "lng": 103.5065},
    {"name": "Kamphaeng Phet", "area": 8607.0, "lat": 16.4828, "lng": 99.5227},
    {"name": "Kanchanaburi", "area": 19483.0, "lat": 14.0041, "lng": 99.5328},
    {"name": "Khon Kaen", "area": 10885.0, "lat": 16.4322, "lng": 102.8236},
    {"name": "Krabi", "area": 4708.0, "lat": 8.0863, "lng": 98.9063},
    {"name": "Lampang", "area": 12534.0, "lat": 18.2888, "lng": 99.4930},
    {"name": "Lamphun", "area": 4506.0, "lat": 18.5745, "lng": 99.0087},
    {"name": "Loei", "area": 11424.0, "lat": 17.4860, "lng": 101.7223},
    {
      "name": "Lop Buri",
      "displayName": "Lopburi",
      "area": 6199.0,
      "lat": 14.7995,
      "lng": 100.6534,
    },
    {"name": "Mae Hong Son", "area": 12681.0, "lat": 19.3000, "lng": 97.9667},
    {"name": "Maha Sarakham", "area": 5291.0, "lat": 16.1852, "lng": 103.3007},
    {"name": "Mukdahan", "area": 4339.0, "lat": 16.5443, "lng": 104.7170},
    {"name": "Nakhon Nayok", "area": 2122.0, "lat": 14.2069, "lng": 101.2131},
    {"name": "Nakhon Pathom", "area": 2168.0, "lat": 13.8140, "lng": 100.0373},
    {"name": "Nakhon Phanom", "area": 5512.0, "lat": 17.3920, "lng": 104.8105},
    {
      "name": "Nakhon Ratchasima",
      "area": 20493.0,
      "lat": 14.9799,
      "lng": 102.0978,
    },
    {"name": "Nakhon Sawan", "area": 9597.0, "lat": 15.7037, "lng": 100.1177},
    {
      "name": "Nakhon Si Thammarat",
      "area": 9942.0,
      "lat": 8.4333,
      "lng": 99.9667,
    },
    {"name": "Nan", "area": 11472.0, "lat": 18.7825, "lng": 100.7802},
    {"name": "Narathiwat", "area": 4475.0, "lat": 6.4255, "lng": 101.8253},
    {
      "name": "Nong Bua Lamphu",
      "area": 3859.0,
      "lat": 17.2045,
      "lng": 102.4406,
    },
    {"name": "Nong Khai", "area": 3026.0, "lat": 17.8783, "lng": 102.7420},
    {"name": "Nonthaburi", "area": 622.0, "lat": 13.8591, "lng": 100.5217},
    {"name": "Pathum Thani", "area": 1525.0, "lat": 14.0208, "lng": 100.5250},
    {"name": "Pattani", "area": 1940.0, "lat": 6.8673, "lng": 101.2501},
    {
      "name": "Phangnga",
      "displayName": "Phang Nga",
      "area": 4170.0,
      "lat": 8.4501,
      "lng": 98.5283,
    },
    {"name": "Phatthalung", "area": 3424.0, "lat": 7.6167, "lng": 100.0833},
    {"name": "Phayao", "area": 6335.0, "lat": 19.1667, "lng": 99.9000},
    {"name": "Phetchabun", "area": 12668.0, "lat": 16.4185, "lng": 101.1550},
    {"name": "Phetchaburi", "area": 6225.0, "lat": 13.1119, "lng": 99.9461},
    {"name": "Phichit", "area": 4531.0, "lat": 16.4418, "lng": 100.3488},
    {"name": "Phitsanulok", "area": 10815.0, "lat": 16.8211, "lng": 100.2659},
    {"name": "Phrae", "area": 6538.0, "lat": 18.1446, "lng": 100.1403},
    {"name": "Phuket", "area": 543.0, "lat": 7.9519, "lng": 98.3381},
    {
      "name": "Prachin Buri",
      "displayName": "Prachinburi",
      "area": 4762.0,
      "lat": 14.0510,
      "lng": 101.3726,
    },
    {
      "name": "Prachuap Khiri Khan",
      "area": 6367.0,
      "lat": 11.8124,
      "lng": 99.7977,
    },
    {"name": "Ranong", "area": 3298.0, "lat": 9.9658, "lng": 98.6348},
    {"name": "Ratchaburi", "area": 5196.0, "lat": 13.5369, "lng": 99.8128},
    {"name": "Rayong", "area": 3552.0, "lat": 12.6814, "lng": 101.2816},
    {"name": "Roi Et", "area": 8299.0, "lat": 16.0523, "lng": 103.6520},
    {"name": "Sa Kaeo", "area": 7195.0, "lat": 13.8240, "lng": 102.0646},
    {"name": "Sakon Nakhon", "area": 9605.0, "lat": 17.1613, "lng": 104.1486},
    {"name": "Samut Prakan", "area": 1004.0, "lat": 13.5993, "lng": 100.5968},
    {"name": "Samut Sakhon", "area": 872.0, "lat": 13.5475, "lng": 100.2736},
    {"name": "Samut Songkhram", "area": 416.0, "lat": 13.4098, "lng": 100.0023},
    {
      "name": "Sara Buri",
      "displayName": "Saraburi",
      "area": 3576.0,
      "lat": 14.5289,
      "lng": 100.9101,
    },
    {"name": "Satun", "area": 2478.0, "lat": 6.6223, "lng": 100.0667},
    {
      "name": "Sing Buri",
      "displayName": "Singburi",
      "area": 822.0,
      "lat": 14.8936,
      "lng": 100.3967,
    },
    {
      "name": "Si Sa Ket",
      "displayName": "Sisaket",
      "area": 8839.0,
      "lat": 15.1186,
      "lng": 104.3220,
    },
    {"name": "Songkhla", "area": 7393.0, "lat": 7.1898, "lng": 100.5954},
    {"name": "Sukhothai", "area": 6596.0, "lat": 17.0053, "lng": 99.8263},
    {
      "name": "Suphan Buri",
      "displayName": "Suphanburi",
      "area": 5358.0,
      "lat": 14.4742,
      "lng": 100.1222,
    },
    {"name": "Surat Thani", "area": 12891.0, "lat": 9.1333, "lng": 99.3167},
    {"name": "Surin", "area": 8124.0, "lat": 14.8818, "lng": 103.4936},
    {"name": "Tak", "area": 16406.0, "lat": 16.8833, "lng": 99.1167},
    {"name": "Trang", "area": 4917.0, "lat": 7.5563, "lng": 99.6114},
    {"name": "Trat", "area": 2819.0, "lat": 12.2428, "lng": 102.5175},
    {
      "name": "Ubon Ratchathani",
      "area": 15744.0,
      "lat": 15.2287,
      "lng": 104.8571,
    },
    {"name": "Udon Thani", "area": 11730.0, "lat": 17.4138, "lng": 102.7872},
    {"name": "Uthai Thani", "area": 6730.0, "lat": 15.3789, "lng": 100.0246},
    {"name": "Uttaradit", "area": 7838.0, "lat": 17.6253, "lng": 100.0993},
    {"name": "Yala", "area": 4521.0, "lat": 6.5411, "lng": 101.2804},
    {"name": "Yasothon", "area": 4161.0, "lat": 15.7926, "lng": 104.1453},
  ];

  @override
  void initState() {
    super.initState();
    _layerController = MapShapeLayerController();

    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _panelSlideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(parent: _panelController, curve: Curves.easeOutCubic),
        );

    _mapSource = MapShapeSource.asset(
      'assets/geo/Thailand_Map.json',
      shapeDataField: 'NAME_1',
      dataCount: _provinces.length,
      primaryValueMapper: (int index) => _provinces[index]['name'],
      dataLabelMapper: (int index) {
        return _provinces[index]['displayName'] ?? _provinces[index]['name'];
      },
    );

    _zoomPanBehavior = MapZoomPanBehavior(
      enableDoubleTapZooming: true,
      enablePinching: true,
      enablePanning: true,
      enableMouseWheelZooming: true,
      minZoomLevel: 0.8,
      maxZoomLevel: 15,
    );

    // เริ่มดึงข้อมูลจาก Database
    _listenToRealDevices();
  }

  @override
  void dispose() {
    _panelController.dispose();
    _searchController.dispose();
    _deviceSubscription?.cancel();
    super.dispose();
  }

  // ==========================================
  // ✅ ระบบดึงหมุดพิกัดจริงแบบไม่ทำให้ Map พัง
  // ==========================================
  void _listenToRealDevices() {
    _deviceSubscription = FirebaseFirestore.instance
        .collection('devices')
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;

          final newDevices = snapshot.docs.map((doc) {
            final data = doc.data();
            return MapDeviceMarker(
              id: doc.id,
              name: data['name'] ?? 'Unknown',
              sn: data['sn'] ?? '',
              zone: data['zone'] ?? 'Unknown',
              lat: (data['lat'] ?? 0.0).toDouble(),
              lng: (data['lng'] ?? 0.0).toDouble(),
              isActive: data['isActive'] ?? false,
            );
          }).toList();

          setState(() {
            _realDevices = newDevices;
          });

          // ใช้ Controller สั่งเพิ่ม/เคลียร์หมุดแทนการเปลี่ยน Key แผนที่
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              try {
                _layerController.clearMarkers();
                for (int i = 0; i < _realDevices.length; i++) {
                  _layerController.insertMarker(i);
                }
              } catch (e) {
                print("Marker update ignored: $e");
              }
            }
          });
        });
  }

  void _jumpToDeviceDashboard(MapDeviceMarker device) {
    DashboardScreen.lastVisitedLocation = device.zone;
    if (!DashboardScreen.recentLocations.contains(device.zone)) {
      DashboardScreen.recentLocations.insert(0, device.zone);
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }

  Color get textColor => Colors.white;
  Color get panelColor => Colors.black.withOpacity(0.7);

  String _getDisplayName(String officialName) {
    final province = _provinces.firstWhere(
      (p) => p['name'] == officialName,
      orElse: () => {"name": officialName},
    );
    return province['displayName'] ?? province['name'];
  }

  void _onSearchChanged(String query) {
    if (!mounted) return;
    setState(() {
      if (query.isEmpty) {
        _isSearching = false;
        _searchResults = [];
      } else {
        _isSearching = true;
        _searchResults = _provinces.where((p) {
          final name = p['name'].toString().toLowerCase();
          final displayName = (p['displayName'] ?? '').toString().toLowerCase();
          return name.contains(query.toLowerCase()) ||
              displayName.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _openProvinceDetails(String provinceName) {
    FocusScope.of(context).unfocus();
    int index = _provinces.indexWhere((p) => p['name'] == provinceName);

    if (!mounted) return;
    setState(() {
      lastVisitedProvince = provinceName;
      _selectedProvinceForPanel = provinceName;
      if (index != -1) {
        _selectedIndex = index;
        _zoomPanBehavior.focalLatLng = MapLatLng(
          _provinces[index]['lat'],
          _provinces[index]['lng'],
        );
        _zoomPanBehavior.zoomLevel = 4.5;
      }
      _isSearching = false;
      _searchController.clear();
    });

    _panelController.forward();
  }

  void _closeProvincePanel() {
    _panelController.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _selectedProvinceForPanel = null;
        _selectedIndex = -1;
        _zoomPanBehavior.focalLatLng = const MapLatLng(13.7563, 100.5018);
        _zoomPanBehavior.zoomLevel = 1.0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Thailand National Network",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [Color(0xFF0F172A), Color(0xFF000000)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: 80,
              left: 10,
              right: 10,
              bottom: 20,
            ),
            child: AnimatedBuilder(
              animation: _panelController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(-100 * _panelController.value, 0),
                  child: child,
                );
              },
              child: SfMaps(
                layers: [
                  MapShapeLayer(
                    controller: _layerController,
                    source: _mapSource,
                    zoomPanBehavior: _zoomPanBehavior,
                    color: const Color(0xFF1565C0),
                    strokeColor: Colors.white.withOpacity(0.8),
                    strokeWidth: 1.0,
                    selectedIndex: _selectedIndex,
                    selectionSettings: const MapSelectionSettings(
                      color: Colors.orangeAccent,
                      strokeColor: Colors.white,
                      strokeWidth: 2,
                    ),
                    onSelectionChanged: (int index) {
                      if (index != -1) {
                        _openProvinceDetails(_provinces[index]['name']);
                      }
                    },
                    showDataLabels: true,
                    dataLabelSettings: const MapDataLabelSettings(
                      textStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      overflowMode: MapLabelOverflow.visible,
                    ),
                    shapeTooltipBuilder: (BuildContext context, int index) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.cyanAccent.withOpacity(0.5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyanAccent.withOpacity(0.2),
                              blurRadius: 15,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Text(
                          _provinces[index]['displayName'] ??
                              _provinces[index]['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                    tooltipSettings: const MapTooltipSettings(
                      color: Colors.transparent,
                    ),

                    initialMarkersCount: _realDevices.length,
                    markerBuilder: (BuildContext context, int index) {
                      if (index >= _realDevices.length) {
                        return const MapMarker(
                          latitude: 0,
                          longitude: 0,
                          child: SizedBox(),
                        );
                      }

                      final dev = _realDevices[index];
                      return MapMarker(
                        latitude: dev.lat,
                        longitude: dev.lng,
                        child: GestureDetector(
                          onTap: () => _jumpToDeviceDashboard(dev),
                          child: Tooltip(
                            message:
                                "Node: ${dev.name} (${dev.sn})\nZone: ${dev.zone}\nStatus: ${dev.isActive ? 'Online' : 'Offline'}",
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: dev.isActive
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                              ),
                            ),
                            textStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (dev.isActive)
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.greenAccent.withOpacity(
                                        0.3,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                Icon(
                                  LucideIcons.mapPin,
                                  color: dev.isActive
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          if (_selectedProvinceForPanel == null)
            Positioned(
              top: 150,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 260,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              LucideIcons.search,
                              size: 18,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Quick Search",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searchController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: "Type province name...",
                            hintStyle: const TextStyle(color: Colors.white38),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                    },
                                    child: const Icon(
                                      LucideIcons.x,
                                      size: 14,
                                      color: Colors.white70,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        if (_isSearching) ...[
                          const SizedBox(height: 8),
                          const Divider(height: 1, color: Colors.white24),
                          Flexible(
                            child: _searchResults.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      "Not found",
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    padding: EdgeInsets.zero,
                                    itemCount: _searchResults.length,
                                    itemBuilder: (context, index) {
                                      final province = _searchResults[index];
                                      return InkWell(
                                        onTap: () => _openProvinceDetails(
                                          province['name'],
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 4,
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                LucideIcons.mapPin,
                                                size: 14,
                                                color: Colors.cyanAccent,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  province['displayName'] ??
                                                      province['name'],
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (_selectedProvinceForPanel != null)
            Positioned(
              top: 80,
              bottom: 20,
              right: 20,
              child: SlideTransition(
                position: _panelSlideAnimation,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 320,
                      color: const Color(0xFF1F2937).withOpacity(0.9),
                      child: ProvinceSidePanel(
                        officialName: _selectedProvinceForPanel!,
                        displayName: _getDisplayName(
                          _selectedProvinceForPanel!,
                        ),
                        onClose: _closeProvincePanel,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (lastVisitedProvince != null && _selectedProvinceForPanel == null)
            Positioned(
              bottom: 40,
              right: 24,
              child: HoverScaleButton(
                onTap: () => _openProvinceDetails(lastVisitedProvince!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.cyanAccent.withOpacity(0.4),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyanAccent.withOpacity(0.1),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.history,
                              color: Colors.cyanAccent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Recent Zone",
                                style: TextStyle(
                                  color: Colors.cyanAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _getDisplayName(lastVisitedProvince!),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            LucideIcons.chevronRight,
                            color: Colors.white54,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==========================================
// ✅ เมนูจัดการพื้นที่ย่อย (เชื่อมต่อ Firestore)
// ==========================================
class ProvinceSidePanel extends StatefulWidget {
  final String officialName;
  final String displayName;
  final VoidCallback onClose;

  const ProvinceSidePanel({
    super.key,
    required this.officialName,
    required this.displayName,
    required this.onClose,
  });

  @override
  State<ProvinceSidePanel> createState() => _ProvinceSidePanelState();
}

class _ProvinceSidePanelState extends State<ProvinceSidePanel> {
  // ✅ ดึงข้อมูลแบบ Stream (Real-time)
  Stream<DocumentSnapshot> get _locationStream => FirebaseFirestore.instance
      .collection('locations')
      .doc(widget.officialName)
      .snapshots();

  void _showAddLocationDialog() {
    TextEditingController locCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: const Text(
          "Add New Sub-Location",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: TextField(
          controller: locCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "e.g. Science Building, 3rd Floor",
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () async {
              if (locCtrl.text.trim().isNotEmpty) {
                // ✅ เพิ่มข้อมูลโซนใหม่เข้าไปใน Firestore (Array)
                await FirebaseFirestore.instance
                    .collection('locations')
                    .doc(widget.officialName)
                    .set({
                      'zones': FieldValue.arrayUnion([locCtrl.text.trim()]),
                    }, SetOptions(merge: true));

                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteLocation(String zoneName) async {
    // ✅ ลบข้อมูลโซนออกจาก Firestore
    await FirebaseFirestore.instance
        .collection('locations')
        .doc(widget.officialName)
        .update({
          'zones': FieldValue.arrayRemove([zoneName]),
        });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 12, 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Zone Configuration",
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(LucideIcons.x, color: Colors.white54),
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),

        // ✅ ใช้ StreamBuilder ดึงข้อมูลจาก Firestore
        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream: _locationStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              List<String> locations = [];
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                if (data != null && data['zones'] != null) {
                  locations = List<String>.from(data['zones']);
                }
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Locations (${locations.length})",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _showAddLocationDialog,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                            minimumSize: const Size(0, 36),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: locations.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.mapPinOff,
                                  size: 48,
                                  color: Colors.white24,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "No locations configured",
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: locations.length,
                            itemBuilder: (context, index) {
                              final zoneName = locations[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      LucideIcons.building,
                                      color: Colors.blue,
                                      size: 18,
                                    ),
                                  ),
                                  title: Text(
                                    zoneName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    "Click to enter Dashboard",
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      LucideIcons.trash2,
                                      color: Colors.redAccent,
                                      size: 16,
                                    ),
                                    onPressed: () => _deleteLocation(zoneName),
                                    tooltip: "Remove",
                                  ),
                                  onTap: () {
                                    DashboardScreen.lastVisitedLocation =
                                        zoneName;
                                    if (!DashboardScreen.recentLocations
                                        .contains(zoneName)) {
                                      DashboardScreen.recentLocations.insert(
                                        0,
                                        zoneName,
                                      );
                                    }
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const DashboardScreen(),
                                      ),
                                      (route) => false,
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class HoverScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const HoverScaleButton({super.key, required this.child, required this.onTap});
  @override
  State<HoverScaleButton> createState() => _HoverScaleButtonState();
}

class _HoverScaleButtonState extends State<HoverScaleButton> {
  bool _isHovering = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovering ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: widget.child,
        ),
      ),
    );
  }
}
