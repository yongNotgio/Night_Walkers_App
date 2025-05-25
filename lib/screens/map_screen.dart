import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const MaterialApp(home: MapScreen()));
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _currentPosition;
  String _selectedMap = 'Street View';

  final Map<String, String> _mapStyles = {
    'Street View': 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
    'Satellite View':
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  };

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
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
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _currentPosition == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(center: _currentPosition, zoom: 16),
                    children: [
                      TileLayer(
                        urlTemplate: _mapStyles[_selectedMap]!,
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'com.example.night_walkers_app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 80,
                            height: 80,
                            point: _currentPosition!,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 40,
                            ),
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
                ],
              ),
    );
  }
}
