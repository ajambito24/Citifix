import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../constants/app_colors.dart';
import '../../constants/sampaloc_boundary.dart';
import '../../utils/screen_util.dart';
import 'my_reports.dart';

// ===== PIN COLORS (same palette as the admin map) =====
Color _pinColor(String status) {
  switch (status) {
    case 'in progress':
      return const Color(0xFF3B82F6);
    case 'resolved':
      return const Color(0xFF22C55E);
    case 'rejected':
      return const Color(0xFFB71C1C);
    default: // pending
      return const Color(0xFFF59E0B);
  }
}

// One of the user's reports that has valid coordinates.
class _MapReport {
  final String id;
  final Map<String, dynamic> data;
  final String reference;
  final String status;
  final LatLng point;

  _MapReport({
    required this.id,
    required this.data,
    required this.reference,
    required this.status,
    required this.point,
  });

  String get category => (data['category'] ?? 'Issue').toString();
  String get description => (data['description'] ?? '').toString();
  String get imageUrl => (data['imageUrl'] ?? '').toString();
}

class MapPage extends StatefulWidget {
  // Kept so existing call sites (ResidentHome, routes) still compile.
  // The old report-flow parameters are accepted but no longer used.
  final String category;
  final String description;
  final dynamic imageBytes;
  final String imageName;
  final double latitude;
  final double longitude;

  /// True when this page is the visible one. ResidentHome builds every tab
  /// at once, so the location is only requested when the Map tab is opened.
  final bool active;

  const MapPage({
    super.key,
    this.category = '',
    this.description = '',
    this.imageBytes,
    this.imageName = '',
    this.latitude = 14.5995,
    this.longitude = 120.9842,
    this.active = true,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();

  Position? _position;
  bool _loading = false;
  bool _hasRequested = false;
  String? _error;

  // ===== USER REPORTS =====
  StreamSubscription<QuerySnapshot>? _reportsSub;
  List<_MapReport> _reports = [];
  String? _reportsError;
  String _filter = 'active';
  String? _selectedId;

  static const _filters = <(String, String)>[
    ('active', 'Active'),
    ('all', 'All'),
    ('pending', 'Pending'),
    ('in progress', 'In Progress'),
    ('resolved', 'Resolved'),
    ('rejected', 'Rejected'),
  ];

  @override
  void initState() {
    super.initState();

    _listenToReports();

    if (widget.active) {
      // Wait for the first frame so the map is built before we move it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _locate();
      });
    }
  }

  @override
  void didUpdateWidget(covariant MapPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // The Map tab was just opened for the first time.
    if (widget.active && !oldWidget.active && !_hasRequested) {
      _locate();
    }
  }

  @override
  void dispose() {
    _reportsSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ===== REPORTS (same query My Reports uses) =====
  void _listenToReports() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _reportsSub = FirebaseFirestore.instance
        .collection('reports')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen(
      (snapshot) {
        final list = <_MapReport>[];

        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final lat = data['latitude'];
          final lng = data['longitude'];

          if (lat is! num || lng is! num) continue;

          list.add(
            _MapReport(
              id: doc.id,
              data: data,
              reference: reportReferenceOf(doc.id, data),
              status: _normalizeStatus(data['status']),
              point: LatLng(lat.toDouble(), lng.toDouble()),
            ),
          );
        }

        if (!mounted) return;

        setState(() {
          _reports = list;
          _reportsError = null;
        });
      },
      onError: (_) {
        if (!mounted) return;

        setState(() {
          _reportsError = 'Could not load your reports.';
        });
      },
    );
  }

  String _normalizeStatus(dynamic raw) {
    final s = (raw ?? 'pending').toString().toLowerCase().replaceAll('_', ' ');
    final status = s.trim();

    const known = ['pending', 'in progress', 'resolved', 'rejected'];
    return known.contains(status) ? status : 'pending';
  }

  bool _matches(String status) {
    switch (_filter) {
      case 'all':
        return true;
      case 'active':
        return status == 'pending' || status == 'in progress';
      default:
        return status == _filter;
    }
  }

  int _countFor(String key) {
    return _reports.where((r) => _matchesKey(r.status, key)).length;
  }

  bool _matchesKey(String status, String key) {
    if (key == 'all') return true;
    if (key == 'active') return status == 'pending' || status == 'in progress';
    return status == key;
  }

  void _openDetails(_MapReport report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportDetailPage(
          report: report.data,
          reference: report.reference,
        ),
      ),
    );
  }

  // ===== LOCATION (same permission flow as the report screen) =====
  Future<void> _locate() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _hasRequested = true;
      _error = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _fail('Please enable Location Services.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _fail('Location permission was denied.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _fail(
          'Location permission is permanently denied. '
          'Please enable it in device settings.',
        );
        return;
      }

      final result = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        _position = result;
        _loading = false;
      });

      _moveToUser();
    } catch (e) {
      _fail('Unable to get location: $e');
    }
  }

  void _fail(String message) {
    if (!mounted) return;

    setState(() {
      _error = message;
      _loading = false;
    });
  }

  // ===== CAMERA =====
  void _moveToUser() {
    final p = _position;
    if (p == null) return;

    try {
      _mapController.move(LatLng(p.latitude, p.longitude), 16);
    } catch (_) {
      // Map not ready yet; ignore.
    }
  }

  void _fitSampaloc() {
    try {
      _mapController.fitCamera(_sampalocFit());
    } catch (_) {
      // Map not ready yet; ignore.
    }
  }

  CameraFit _sampalocFit() {
    return CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(sampalocBoundary),
      padding: EdgeInsets.all(32.w),
    );
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);

    // Resolve the selected report; drop it if it is gone or filtered out.
    _MapReport? selected;
    for (final r in _reports) {
      if (r.id == _selectedId && _matches(r.status)) {
        selected = r;
        break;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Map',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _buildMap(),

                // Area label
                Positioned(
                  top: 12.h,
                  left: 12.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 10.r,
                          offset: Offset(0, 3.h),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_city,
                          size: 16.w,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'Sampaloc, Manila',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Status filter dropdown (kept clear of the map buttons)
                Positioned(
                  top: 56.h,
                  left: 12.w,
                  child: _buildFilterDropdown(),
                ),

                if (_reportsError != null)
                  Positioned(
                    top: 106.h,
                    left: 12.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 8.r,
                          ),
                        ],
                      ),
                      child: Text(
                        _reportsError!,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),

                // Map buttons
                Positioned(
                  top: 12.h,
                  right: 12.w,
                  child: Column(
                    children: [
                      _mapButton(
                        icon: Icons.my_location,
                        onTap: _position == null ? _locate : _moveToUser,
                      ),
                      SizedBox(height: 10.h),
                      _mapButton(
                        icon: Icons.fit_screen,
                        onTap: _fitSampaloc,
                      ),
                    ],
                  ),
                ),

                // Floating card for the tapped pin
                if (selected != null)
                  Positioned(
                    left: 12.w,
                    right: 12.w,
                    bottom: 12.h,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: ScreenUtil.maxContentWidth,
                        ),
                        child: _buildReportCard(selected),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildInfoPanel(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final p = _position;

    final visible = _reports.where((r) => _matches(r.status)).toList();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCameraFit: _sampalocFit(),
        minZoom: 10,
        maxZoom: 19,
        // Tapping empty map closes the floating card.
        onTap: (_, __) {
          if (_selectedId != null) {
            setState(() {
              _selectedId = null;
            });
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          // Match this to your Android applicationId.
          userAgentPackageName: 'com.example.citifix_manila',
        ),

        // Sampaloc border (the only boundary drawn)
        PolygonLayer(
          polygons: [
            Polygon(
              points: sampalocBoundary,
              color: AppColors.primarySoft,
              borderColor: AppColors.primary,
              borderStrokeWidth: 3,
            ),
          ],
        ),

        // The user's report pins (under the location dot)
        MarkerLayer(
          markers: [
            for (final r in visible)
              Marker(
                point: r.point,
                width: 48.w,
                height: 48.w,
                child: _reportPin(r),
              ),
          ],
        ),

        // Current location
        if (p != null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(p.latitude, p.longitude),
                width: 64.w,
                height: 64.w,
                child: _userDot(),
              ),
            ],
          ),

        // Required by OpenStreetMap's tile usage policy.
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }

  Widget _reportPin(_MapReport report) {
    final color = _pinColor(report.status);
    final isSelected = report.id == _selectedId;
    final size = isSelected ? 34.w : 26.w;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _selectedId = report.id;
        });
      },
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: AppColors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 6.r,
                offset: Offset(0, 2.h),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userDot() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing halo
        Container(
          width: 56.w,
          height: 56.w,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryRing,
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(0.6, 0.6),
              end: const Offset(1, 1),
              duration: 1200.ms,
              curve: Curves.easeInOut,
            ),
        // Dot
        Container(
          width: 22.w,
          height: 22.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            border: Border.all(color: AppColors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 6.r,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mapButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44.w,
        height: 44.w,
        decoration: BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10.r,
              offset: Offset(0, 3.h),
            ),
          ],
        ),
        child: Icon(icon, size: 22.w, color: AppColors.primary),
      ),
    );
  }

  // ===== FILTER DROPDOWN =====
  Widget _buildFilterDropdown() {
    return Container(
      width: 160.w,
      height: 40.h,
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8.r,
            offset: Offset(0, 3.h),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filter,
          isExpanded: true,
          dropdownColor: AppColors.white,
          borderRadius: BorderRadius.circular(16.r),
          icon: Icon(
            Icons.keyboard_arrow_down,
            size: 20.w,
            color: AppColors.primary,
          ),
          items: [
            for (final f in _filters)
              DropdownMenuItem<String>(
                value: f.$1,
                child: Text(
                  '${f.$2} ${_countFor(f.$1)}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _filter = value;
            });
          },
        ),
      ),
    );
  }

  // ===== FLOATING REPORT CARD =====
  Widget _buildReportCard(_MapReport report) {
    final color = _pinColor(report.status);

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16.r,
            offset: Offset(0, 6.h),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          Container(
            width: 72.w,
            height: 72.w,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: report.imageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: Image.network(
                      report.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.broken_image,
                        size: 24.w,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : Icon(
                    Icons.report_problem,
                    size: 24.w,
                    color: AppColors.textSecondary,
                  ),
          ),
          SizedBox(width: 12.w),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        report.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedId = null;
                        });
                      },
                      child: Icon(
                        Icons.close,
                        size: 20.w,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    reportReferenceChip(report.reference),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: Text(
                        reportFormatDate(report.data['createdAt']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (report.description.isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  Text(
                    report.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      height: 1.3,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                SizedBox(height: 8.h),
                Row(
                  children: [
                    // Same color as the pin, so the two always match.
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: color.withAlpha(31),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7.w,
                            height: 7.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            reportStatusLabel(report.status),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _openDetails(report),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View details',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 18.w,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== INFO PANEL =====
  Widget _buildInfoPanel() {
    final p = _position;

    String title;
    String subtitle;
    Color titleColor = AppColors.textPrimary;
    IconData icon = Icons.my_location;
    Color iconColor = AppColors.primary;

    if (_loading) {
      title = 'Finding your location…';
      subtitle = 'Please wait a moment.';
    } else if (_error != null) {
      title = 'Location unavailable';
      subtitle = _error!;
      titleColor = AppColors.error;
      icon = Icons.location_off;
      iconColor = AppColors.error;
    } else if (p != null) {
      title = 'Your Location';
      subtitle = 'Lat ${p.latitude.toStringAsFixed(6)}, '
          'Lng ${p.longitude.toStringAsFixed(6)}\n'
          '±${p.accuracy.round()} m accuracy';
    } else {
      title = 'Your Location';
      subtitle = 'Tap the location button to find yourself.';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16.r,
            offset: Offset(0, -4.h),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ScreenUtil.maxContentWidth,
            ),
            child: Row(
              children: [
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(31),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: _loading
                      ? Padding(
                          padding: EdgeInsets.all(12.w),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.5,
                          ),
                        )
                      : Icon(icon, size: 22.w, color: iconColor),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.sp,
                          height: 1.3,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_loading) ...[
                  SizedBox(width: 8.w),
                  _error != null
                      ? TextButton(
                          onPressed: _locate,
                          child: Text(
                            'Retry',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : IconButton(
                          onPressed: _locate,
                          icon: Icon(
                            Icons.refresh,
                            size: 24.w,
                            color: AppColors.primary,
                          ),
                        ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}