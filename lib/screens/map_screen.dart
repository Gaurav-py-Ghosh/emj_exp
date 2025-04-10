import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import '../widgets/emoji_marker.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  Marker? _animatedMarker;
  final LocationService _locationService = LocationService();
  final Random _random = Random();
  
  // Add map style
  final String _darkMapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#1d2c4d"
        }
      ]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#8ec3b9"
        }
      ]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#1a3646"
        }
      ]
    },
    {
      "featureType": "administrative.country",
      "elementType": "geometry.stroke",
      "stylers": [
        {
          "color": "#4b6878"
        }
      ]
    },
    {
      "featureType": "administrative.land_parcel",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#64779e"
        }
      ]
    },
    {
      "featureType": "administrative.province",
      "elementType": "geometry.stroke",
      "stylers": [
        {
          "color": "#4b6878"
        }
      ]
    },
    {
      "featureType": "landscape.man_made",
      "elementType": "geometry.stroke",
      "stylers": [
        {
          "color": "#334e87"
        }
      ]
    },
    {
      "featureType": "landscape.natural",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#023e58"
        }
      ]
    },
    {
      "featureType": "poi",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#283d6a"
        }
      ]
    },
    {
      "featureType": "poi",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#6f9ba5"
        }
      ]
    },
    {
      "featureType": "poi",
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#1d2c4d"
        }
      ]
    },
    {
      "featureType": "poi.park",
      "elementType": "geometry.fill",
      "stylers": [
        {
          "color": "#023e58"
        }
      ]
    },
    {
      "featureType": "poi.park",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#3C7680"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#304a7d"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#98a5be"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#1d2c4d"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#2c6675"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry.stroke",
      "stylers": [
        {
          "color": "#255763"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#b0d5ce"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#023e58"
        }
      ]
    },
    {
      "featureType": "transit",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#98a5be"
        }
      ]
    },
    {
      "featureType": "transit",
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#1d2c4d"
        }
      ]
    },
    {
      "featureType": "transit.line",
      "elementType": "geometry.fill",
      "stylers": [
        {
          "color": "#283d6a"
        }
      ]
    },
    {
      "featureType": "transit.station",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#3a4762"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#0e1626"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#4e6d70"
        }
      ]
    }
  ]
  ''';

  // Animation controller for radar effect
  late AnimationController _radarController;
  late Animation<double> _radarAnimation;

  // Status message
  String _statusMessage = "Initializing system...";
  bool _showMessage = true;

  // Location stats
  double _distance = 0.0;
  int _emojiCount = 0;
  
  @override
  void initState() {
    super.initState();
    
    // Setup radar animation
    _radarController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _radarAnimation = Tween<double>(begin: 0, end: 1.0).animate(_radarController);
    
    // Initialize map
    _initMap();
    
    // Auto-hide status message after delay
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showMessage = false;
        });
      }
    });
    
    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: const Color(0xFF0B1622),
    ));
  }

  Future<void> _initMap() async {
    setState(() {
      _statusMessage = "Acquiring location...";
    });
    
    final location = await _locationService.getCurrentLocation();
    
    setState(() {
      _statusMessage = "Scanning area...";
      _emojiCount = 10;
    });
    
    await _generateRandomEmojis(location, 10); // Generate 10 random emojis
    await _animateMarker(location);
    
    if (_mapController != null) {
      _mapController.animateCamera(CameraUpdate.newLatLngZoom(location, 18.0));
      
      // Apply map style
      _mapController.setMapStyle(_darkMapStyle);
    }
    
    setState(() {
      _statusMessage = "Area secured. System online.";
    });
    
    // Auto-hide status message after delay
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showMessage = false;
        });
      }
    });
  }

  Future<void> _generateRandomEmojis(LatLng center, int count) async {
    const radius = 0.0001; // ~10 meters in degrees
    final markers = <Marker>[];
    
    for (int i = 0; i < count; i++) {
      final offsetLat = (_random.nextDouble() * 2 - 1) * radius;
      final offsetLng = (_random.nextDouble() * 2 - 1) * radius;
      final position = LatLng(
        center.latitude + offsetLat,
        center.longitude + offsetLng,
      );
      
      markers.add(await EmojiMarker.createMarker(
        position: position,
        id: 'emoji_$i',
        emoji: _getRandomEmoji(),
        size: 24, // Smaller size
      ));
    }
    
    setState(() {
      _markers.addAll(markers);
    });
  }

  String _getRandomEmoji() {
    final emojis = ['😀', '😂', '🤩', '😎', '🤪', '🧐', '🥳', '😍', '🤯', '👻'];
    return emojis[_random.nextInt(emojis.length)];
  }

  Future<void> _animateMarker(LatLng destination) async {
    _markers.removeWhere((m) => m.markerId.value == 'animatedMarker');
    
    final newMarker = await EmojiMarker.createMarker(
      position: destination,
      id: 'animatedMarker',
      emoji: '📍',
      size: 32,
    );
    
    setState(() {
      _animatedMarker = newMarker;
      _markers.add(newMarker);
      
      // Calculate distance for display (just for UI effect)
      _distance = _random.nextDouble() * 100;
      
      // Show status message
      _statusMessage = "Target acquired at: ${destination.latitude.toStringAsFixed(6)}, ${destination.longitude.toStringAsFixed(6)}";
      _showMessage = true;
    });
    
    // Auto-hide status message after delay
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showMessage = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    _radarController.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController.setMapStyle(_darkMapStyle);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1622),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.radar, color: Colors.cyan.shade400),
            const SizedBox(width: 8),
            const Text(
              "QUANTUM LOCATOR",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () {
              setState(() {
                _statusMessage = "System preferences unavailable in field mode";
                _showMessage = true;
              });
              
              Timer(const Duration(seconds: 3), () {
                if (mounted) {
                  setState(() {
                    _showMessage = false;
                  });
                }
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0), // Will be quickly replaced
              zoom: 18.0,
            ),
            markers: _markers,
            onMapCreated: _onMapCreated,
            onTap: (LatLng tappedPoint) async {
              await _animateMarker(tappedPoint);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
          ),
          
          // Radar overlay
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _radarAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: RadarPainter(
                    progress: _radarAnimation.value,
                  ),
                );
              },
            ),
          ),
          
          // HUD elements
          SafeArea(
            child: Column(
              children: [
                // Status message
                AnimatedOpacity(
                  opacity: _showMessage ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.cyan.shade700, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.cyan.shade400, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusMessage,
                            style: TextStyle(
                              color: Colors.cyan.shade100,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Bottom HUD
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.cyan.shade900, width: 1),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatCard(
                            icon: Icons.location_on,
                            title: "TARGETS",
                            value: "$_emojiCount",
                          ),
                          _buildStatCard(
                            icon: Icons.route,
                            title: "DISTANCE",
                            value: "${_distance.toStringAsFixed(2)} m",
                          ),
                          _buildStatCard(
                            icon: Icons.speed,
                            title: "SCAN",
                            value: "ACTIVE",
                            valueColor: Colors.greenAccent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          color: Colors.cyan.shade900,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.cyan.shade700.withOpacity(0.5),
              spreadRadius: 1,
              blurRadius: 8,
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF0B1622),
          onPressed: _initMap,
          child: AnimatedBuilder(
            animation: _radarController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _radarController.value * 2 * pi,
                child: Icon(
                  Icons.my_location,
                  color: Colors.cyan.shade400,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.cyan.shade400, size: 16),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// Custom painter for radar effect
class RadarPainter extends CustomPainter {
  final double progress;
  
  RadarPainter({required this.progress});
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.4;
    
    // Draw scan line
    final scanPaint = Paint()
      ..color = Colors.cyan.shade400.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    final angle = 2 * pi * progress;
    final scanX = center.dx + radius * cos(angle);
    final scanY = center.dy + radius * sin(angle);
    
    canvas.drawLine(center, Offset(scanX, scanY), scanPaint);
    
    // Draw radar circles
    final circlePaint = Paint()
      ..color = Colors.cyan.shade400.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    for (int i = 1; i <= 3; i++) {
      final circleRadius = radius * (i / 3);
      canvas.drawCircle(center, circleRadius, circlePaint);
    }
    
    // Draw scan area
    final scanAreaPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0,
        endAngle: angle,
        colors: [
          Colors.transparent,
          Colors.cyan.shade400.withOpacity(0.1),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    
    canvas.drawCircle(center, radius, scanAreaPaint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}