import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../constants/app_colors.dart';
import '../../constants/sampaloc_boundary.dart';
import '../../utils/screen_util.dart';

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

  @override
  void initState() {
    super.initState();

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
    _mapController.dispose();
    super.dispose();
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

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCameraFit: _sampalocFit(),
        minZoom: 10,
        maxZoom: 19,
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