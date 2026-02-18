import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:night_walkers_app/widgets/user_location_marker.dart';
import 'package:night_walkers_app/widgets/fixed_compass.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _currentPosition;
  String _selectedMap = 'Street View';
  double? _heading;
  StreamSubscription<CompassEvent>? _compassSubscription;
  List<LatLng> _fieldOfVisionPolygon = [];
  bool _isConnected = true;

  final Map<String, String> _mapStyles = {
    'Street View': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'Satellite View':
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  };

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _getCurrentLocation();
    _requestPermissions();
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final dynamic connectivityResult = await Connectivity().checkConnectivity();
    final bool hasConnection =
        connectivityResult is List<ConnectivityResult>
            ? connectivityResult.any((result) => result != ConnectivityResult.none)
            : connectivityResult != ConnectivityResult.none;
    if (!mounted) return;
    setState(() {
      _isConnected = hasConnection;
    });
  }

  Future<void> _requestPermissions() async {
    // Request location permission, which is required for compass on Android.
    if (await Permission.locationWhenInUse.request().isGranted) {
      _startCompass();
    }
  }

  void _startCompass() {
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent? event) {
      if (!mounted) return;
      if (event != null && event.heading != null) {
        setState(() {
          _heading = event.heading!;
          _updateFieldOfVisionPolygon();
        });
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _updateFieldOfVisionPolygon();
    });
  }

  void _updateFieldOfVisionPolygon() {
    if (_currentPosition == null || _heading == null) return;

    const double distance = 350;
    const double fovAngle = 60; // Field of vision angle in degrees
    const int segments = 20; // Number of segments for the arcs

    List<LatLng> points = [_currentPosition!];

    final Distance haversineDistance = Distance();

    for (int i = 0; i <= segments; i++) {
      double angle = (_heading! - fovAngle / 2) + (fovAngle / segments) * i;
      LatLng point = haversineDistance.offset(
        _currentPosition!,
        distance,
        angle,
      );
      points.add(point);
    }

    points.add(_currentPosition!); // Close the polygon

    _fieldOfVisionPolygon = points;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          !_isConnected
              ? const Center(
                  child: Text(
                    'No internet connection. Map cannot be loaded.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.red),
                  ),
                )
              : _currentPosition == null
                  ? const Center(child: CircularProgressIndicator())
                  : Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(center: _currentPosition, zoom: 16, rotation: -(_heading ?? 0)),
                    children: [
                      TileLayer(
                        urlTemplate: _mapStyles[_selectedMap]!,
                        userAgentPackageName: 'com.example.night_walkers_app',
                      ),
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: _fieldOfVisionPolygon,
                            color: Colors.blueAccent.withOpacity(0.3),
                            borderColor: Colors.blueAccent,
                            borderStrokeWidth: 1.0,
                            isFilled: true,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 80,
                            height: 80,
                            point: _currentPosition!,
                            child: UserLocationMarker(heading: _heading ?? 0.0),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: 40,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      color: Colors.white.withOpacity(0.9),
                      child: DropdownButton<String>(
                        value: _selectedMap,
                        underline: const SizedBox(),
                        onChanged: (value) {
                          setState(() {
                            _selectedMap = value!;
                          });
                        },
                        items:
                            _mapStyles.keys.map((style) {
                              return DropdownMenuItem<String>(
                                value: style,
                                child: Text(style),
                              );
                            }).toList(),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 100,
                    right: 10,
                    child: FixedCompass(heading: _heading ?? 0.0),
                  ),
                ],
              ),
    );
  }
}
