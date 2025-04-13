import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:camera/camera.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:hive_flutter/hive_flutter.dart';
import '../widgets/emoji_model.dart';
import '../widgets/emoji_marker.dart';
import 'emoji_catch_screen.dart';
import 'inventory_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/storage_service.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  // Core components
  late GoogleMapController _mapController;
  late Set<Marker> _markers = {};
  final Location _location = Location();
  final Random _random = Random();
  final Map<String, DateTime> _emojiSpawnTimes = {};
  
  // Game state
  int _totalPoints = 0;
  late Box<EmojiInventoryItem> _inventoryBox;
  bool _isCatching = false;
  
  // Location tracking
  LatLng _currentPosition = const LatLng(0, 0);
  bool _locationReady = false;
  double _currentZoom = 18.0;
  StreamSubscription<LocationData>? _locationSubscription;
  double _distanceToClosestEmoji = double.infinity;
  double _currentHeading = 0.0;
  bool _compassEnabled = true;
  
  // Emoji management
  Set<String> _visibleEmojiIds = {};
  Timer? _emojiUpdateTimer;
  DateTime? _lastEmojiUpdate;
  
  // Camera
  List<CameraDescription>? _cameras;
  
  // Constants
  static const double _spawnRadius = 145.0;
  static const double _interactionRadius = 10;
  static const double _visibilityRadius = 20.0;
  static const Duration _emojiLifetime = Duration(minutes: 5);
  static const Duration _emojiRefreshInterval = Duration(minutes: 2);
  static const double _minEmojiDistance = 2.0;

  // Player icons
  late BitmapDescriptor _playerIconStill;
  late BitmapDescriptor _playerIconWalking;
  bool _isMoving = false;
  DateTime _lastLocationUpdate = DateTime.now();
  static const _movementThreshold = 0.3; // meters - lowered to make animation more responsive

  // Animation properties
  Timer? _walkingAnimationTimer;
  bool _showWalkingFrame = false;
  late AnimationController _radarAnimationController;
  late Animation<double> _radarAnimation;
  
  // Map style
  String _darkMapStyle = '';

  // Special locations
  final List<Map<String, dynamic>> _specialLocations = [
    {
      'position': const LatLng(28.248469525586557, 76.81188335320125),
      'name': 'Tuck Shop',
      'emoji': '👑'  // crown
    },
    {
      'position': const LatLng(28.24713543653385, 76.81113646602226),
      'name': 'Apartment A',
      'emoji': '🎯'  // target
    },
    {
      'position': const LatLng(28.247606829475224, 76.81369700185591),
      'name': 'Burger Sign',
      'emoji': '👑'  // crown
    },
    {
      'position': const LatLng(28.246286117629833, 76.81364496182871),
      'name': 'Library Path',
      'emoji': '🎯'  // target
    },
    {
      'position': const LatLng(28.246852907641117, 76.81440809842454),
      'name': 'Library Entrance',
      'emoji': '👑'  // crown
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeApp();
    
    // Initialize radar animation
    _radarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    
    _radarAnimation = Tween<double>(begin: 0.0, end: 2 * pi).animate(_radarAnimationController);
    
    // Load the dark map style
    _loadMapStyle();
  }

  Future<void> _loadMapStyle() async {
    _darkMapStyle = await rootBundle.loadString('assets/dark_map_style.json');
    
    // If the asset isn't available, use a fallback style
    if (_darkMapStyle.isEmpty) {
      _darkMapStyle = '''
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
    }
  }

  Future<void> _initializeApp() async {
    await _createPlayerIcons();
    await _initializeStorage();
    await _initializeCamera();
    await _initializeLocation();
  }

  // Improved player icons creation
  Future<void> _createPlayerIcons() async {
    try {
      final ByteData stillData = await rootBundle.load('assets/still.png');
      final ByteData walkingData = await rootBundle.load('assets/walking.png');
      
      // Increase icon size
      final ui.Codec stillCodec = await ui.instantiateImageCodec(
        stillData.buffer.asUint8List(),
        targetWidth: 96,  // Increased from 64 to 96
        targetHeight: 96, // Increased from 64 to 96
      );
      final ui.Codec walkingCodec = await ui.instantiateImageCodec(
        walkingData.buffer.asUint8List(),
        targetWidth: 96,  // Increased from 64 to 96
        targetHeight: 96, // Increased from 64 to 96
      );
      
      final ui.FrameInfo stillFrame = await stillCodec.getNextFrame();
      final ui.FrameInfo walkingFrame = await walkingCodec.getNextFrame();
      
      _playerIconStill = BitmapDescriptor.fromBytes(
        await stillFrame.image.toByteData(format: ui.ImageByteFormat.png)
          .then((byteData) => byteData!.buffer.asUint8List())
      );
      
      _playerIconWalking = BitmapDescriptor.fromBytes(
        await walkingFrame.image.toByteData(format: ui.ImageByteFormat.png)
          .then((byteData) => byteData!.buffer.asUint8List())
      );
    } catch (e) {
      debugPrint('Error loading player icons: $e');
      // Fallback to default markers if icons can't be loaded
      _playerIconStill = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      _playerIconWalking = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
    }
  }

  Future<void> _initializeStorage() async {
    _inventoryBox = await Hive.openBox<EmojiInventoryItem>(StorageService.inventoryBoxName);
    _calculateTotalPoints();
  }

  void _calculateTotalPoints() {
    _totalPoints = _inventoryBox.values.fold(0, (sum, item) => sum + item.points);
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  Future<void> _initializeLocation() async {
    try {
      final permissionStatus = await Permission.location.request();
      if (!permissionStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission required'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        final serviceRequest = await _location.requestService();
        if (!serviceRequest && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable location services'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      final initialLocation = await _location.getLocation();
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(initialLocation.latitude!, initialLocation.longitude!);
          _locationReady = true;
          
          // Initialize the heading if available
          if (initialLocation.heading != null) {
            _currentHeading = initialLocation.heading!;
          }
        });
      }

      _startLocationTracking();
      _startEmojiUpdateTimer();
      _generateEmojisAroundLocation();
      
    } catch (e) {
      debugPrint('Location initialization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Enhanced location tracking with heading
  void _startLocationTracking() {
    _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 1000,  // Changed from 500 to 2000ms
      distanceFilter: 5.0,  // Changed from 2.0 to 5.0m
    );

    _locationSubscription = _location.onLocationChanged.listen((LocationData currentLocation) {
      if (currentLocation.latitude == null || currentLocation.longitude == null) return;
      
      final newPosition = LatLng(currentLocation.latitude!, currentLocation.longitude!);
      final distance = _calculateDistance(_currentPosition, newPosition);
      final now = DateTime.now();
      
      // Update movement state
      final bool wasMoving = _isMoving;
      _isMoving = distance > _movementThreshold;
      
      // Update heading if available
      if (currentLocation.heading != null && currentLocation.heading! > 0) {
        _currentHeading = currentLocation.heading!;
        // Update map bearing if compass mode is enabled
        if (_compassEnabled) {
          _mapController.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: newPosition,
                zoom: _currentZoom,
                bearing: _currentHeading,
              ),
            ),
          );
        }
      }
      
      // Start/stop walking animation with faster timing
      if (_isMoving && _walkingAnimationTimer == null) {
        _walkingAnimationTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
          if (mounted) {
            setState(() => _showWalkingFrame = !_showWalkingFrame);
          }
        });
      } else if (!_isMoving && _walkingAnimationTimer != null) {
        _walkingAnimationTimer?.cancel();
        _walkingAnimationTimer = null;
        _showWalkingFrame = false;
      }
      
      if (!_locationReady || distance > 2 || wasMoving != _isMoving) {
        if (mounted) {
          setState(() {
            _currentPosition = newPosition;
            _locationReady = true;
            // Update player marker with appropriate icon
            _markers.removeWhere((m) => m.markerId.value == 'player');
            _markers.add(Marker(
              markerId: const MarkerId('player'),
              position: newPosition,
              icon: _isMoving ? (_showWalkingFrame ? _playerIconWalking : _playerIconStill) : _playerIconStill,
              zIndex: 2,
              anchor: const Offset(0.5, 0.5), // Center the marker
              // The rotation is fixed and determined by the heading, not computed from movement
              rotation: _currentHeading,
            ));
          });
        }
        
        // Only update camera target, not bearing (that's handled above)
        if (!_compassEnabled) {
          _updateMapCamera(newPosition);
        }
        
        _updateVisibleEmojis();
      }
      _lastLocationUpdate = now;
    }, onError: (e) {
      debugPrint('Location tracking error: $e');
    });
  }

  void _updateMapCamera(LatLng newPosition) {
    _mapController.animateCamera(
      CameraUpdate.newLatLng(newPosition),
    );
    }

  void _startEmojiUpdateTimer() {
    _emojiUpdateTimer?.cancel();
    _emojiUpdateTimer = Timer.periodic(_emojiRefreshInterval, (_) {
      if (_locationReady) {
        _generateEmojisAroundLocation();
      }
    });
  }

  // Emoji generation remains largely the same
  Future<void> _generateEmojisAroundLocation() async {
    if (!_locationReady) return;

    final now = DateTime.now();
    _lastEmojiUpdate = now;
    final existingMarkers = _markers.toSet();

    // Remove expired emojis
    _emojiSpawnTimes.removeWhere((id, spawnTime) {
      if (now.difference(spawnTime) > _emojiLifetime) {
        existingMarkers.removeWhere((m) => m.markerId.value == id);
        return true;
      }
      return false;
    });

    final newMarkers = <Marker>{};

    // Add special location emojis
    for (final location in _specialLocations) {
      final markerId = 'special_${location['name'].toString().toLowerCase().replaceAll(' ', '_')}';
      
      // Only add if not already present
      if (!_emojiSpawnTimes.containsKey(markerId)) {
        final emojiTier = EmojiTier(
          emoji: location['emoji'],
          tier: 3,
          points: 100,
          spawnChance: 1.0,
          hasSpecialAnimation: true
        );

        newMarkers.add(
          await EmojiMarker.createMarker(
            position: location['position'],
            id: markerId,
            emoji: location['emoji'],
            size: 70, // Tier 3 size
            tier: 3,
            spawnTime: now,
            onTap: () => _handleEmojiTap(location['position'], emojiTier),
          ),
        );
        
        _emojiSpawnTimes[markerId] = now;
      }
    }

    // Generate random emojis
    final newEmojiCount = 12 + _random.nextInt(5);  // Increased from 7 to 12

    for (int i = 0; i < newEmojiCount; i++) {
      final distance = _getStaggeredDistance(_spawnRadius);
      final angle = _random.nextDouble() * 2 * pi;
      final position = _calculateNewPosition(_currentPosition, distance, angle);
      
      if (_isTooCloseToOthers(position, existingMarkers)) continue;
      
      final emojiTier = _getWeightedRandomEmoji();
      final markerId = 'emoji_${position.latitude}_${position.longitude}_${now.millisecondsSinceEpoch}_$i';
      
      newMarkers.add(
        await EmojiMarker.createMarker(
          position: position,
          id: markerId,
          emoji: emojiTier.emoji,
          size: emojiTier.tier == 3 ? 70 : 60,
          tier: emojiTier.tier,
          spawnTime: now,
          onTap: () => _handleEmojiTap(position, emojiTier),
        ),
      );
      
      _emojiSpawnTimes[markerId] = now;
    }

    if (mounted) {
      setState(() {
        _markers = existingMarkers..addAll(newMarkers);
        _updateVisibleEmojis();
      });
    }
  }

  double _getStaggeredDistance(double maxRadius) {
    final roll = _random.nextDouble();
    if (roll < 0.2) return 4 + _random.nextDouble() * (maxRadius * 0.3);
    if (roll < 0.8) return maxRadius * 0.3 + _random.nextDouble() * (maxRadius * 0.5);
    return maxRadius * 0.8 + _random.nextDouble() * (maxRadius * 0.2);
  }

  bool _isTooCloseToOthers(LatLng position, Set<Marker> existingMarkers) {
    for (final marker in existingMarkers) {
      if (_calculateDistance(position, marker.position) < _minEmojiDistance) {
        return true;
      }
    }
    return false;
  }

  EmojiTier _getWeightedRandomEmoji() {
    const tierChances = {1: 0.7, 2: 0.2, 3: 0.1};
    final roll = _random.nextDouble();
    double cumulative = 0.0;
    int selectedTier = 1;

    for (final entry in tierChances.entries) {
      cumulative += entry.value;
      if (roll < cumulative) {
        selectedTier = entry.key;
        break;
      }
    }

    final tierEmojis = emojiTiers.where((emoji) => emoji.tier == selectedTier).toList();
    final emojiRoll = _random.nextDouble();
    cumulative = 0.0;

    for (final emoji in tierEmojis) {
      cumulative += emoji.spawnChance;
      if (emojiRoll < cumulative) {
        return EmojiTier(
          emoji: emoji.emoji,
          tier: emoji.tier,
          points: emoji.points,
          spawnChance: emoji.spawnChance,
          hasSpecialAnimation: emoji.tier >= 2
        );
      }
    }

    return EmojiTier(
      emoji: tierEmojis.first.emoji,
      tier: tierEmojis.first.tier,
      points: tierEmojis.first.points,
      spawnChance: tierEmojis.first.spawnChance,
      hasSpecialAnimation: tierEmojis.first.tier >= 2
    );
  }

  final Set<Marker> _hiddenMarkers = {};

  void _updateVisibleEmojis() {
    if (!_locationReady) return;

    final nowVisible = <String>{};
    const checkRadius = 20.0;

    if (mounted) {
      setState(() {
        // Move markers between visible and hidden sets based on distance
        for (final marker in _markers.union(_hiddenMarkers)) {
          if (marker.markerId.value == 'player') continue;
          
          final distance = _calculateDistance(_currentPosition, marker.position);
          if (distance <= checkRadius) {
            nowVisible.add(marker.markerId.value);
            _hiddenMarkers.remove(marker);
          } else {
            _hiddenMarkers.add(marker);
          }
        }

        _visibleEmojiIds = nowVisible;
        _markers.removeWhere((m) => 
          m.markerId.value != 'player' && 
          !nowVisible.contains(m.markerId.value)
        );
        _updateClosestEmoji();
      });
    }
  }

  void _updateClosestEmoji() {
    if (!_locationReady) {
      setState(() => _distanceToClosestEmoji = double.infinity);
      return;
    }

    double minDistance = double.infinity;
    // Check all markers, including those outside visibility radius
    for (final marker in _markers.union(_hiddenMarkers)) {
      if (marker.markerId.value == 'player') continue;
      
      final distance = _calculateDistance(_currentPosition, marker.position);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    setState(() => _distanceToClosestEmoji = minDistance);
  }

  void _handleEmojiTap(LatLng emojiPosition, EmojiTier emojiTier) async {
    if (!_locationReady || _isCatching) return;

    final distance = _calculateDistance(_currentPosition, emojiPosition);
    if (distance > _interactionRadius) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Too far away! (${distance.toStringAsFixed(1)}m)'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red[800],
          ),
        );
      }
      return;
    }

    setState(() => _isCatching = true);

    try {
      final caught = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => EmojiCatchScreen(
            emojiTier: emojiTier,
            catchLocation: emojiPosition,
            onCatchComplete: () => _addToInventory(emojiTier, emojiPosition),
          ),
        ),
      );

      if (caught ?? false) {
        if (mounted) {
          setState(() {
            _markers.removeWhere((m) => m.position == emojiPosition);
            _updateClosestEmoji();
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isCatching = false);
      }
    }
  }

  void _addToInventory(EmojiTier emojiTier, LatLng catchLocation) {
    final newItem = EmojiInventoryItem(
      emoji: emojiTier.emoji,
      points: emojiTier.points,
      tier: emojiTier.tier,
      caughtTime: DateTime.now(),
      caughtLocation: catchLocation,
    );

    _inventoryBox.add(newItem);
    
    if (mounted) {
      setState(() {
        _totalPoints += emojiTier.points;
      });
    }
  }

  LatLng _calculateNewPosition(LatLng center, double distance, double angle) {
    final distanceInDegrees = distance / 111300.0;
    return LatLng(
      center.latitude + distanceInDegrees * cos(angle),
      center.longitude + distanceInDegrees * sin(angle),
    );
  }

  double _calculateDistance(LatLng pos1, LatLng pos2) {
    return vm.Vector2(pos1.latitude.toDouble(), pos1.longitude.toDouble())
        .distanceTo(vm.Vector2(pos2.latitude.toDouble(), pos2.longitude.toDouble())) 
        * 111300.0;
  }

  Future<void> _centerMapOnUser() async {
    if (_locationReady) {
      await _mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentPosition,
            zoom: _currentZoom,
            bearing: _compassEnabled ? _currentHeading : 0,
          ),
        ),
      );
    }
  }

  void _toggleCompassMode() {
    setState(() {
      _compassEnabled = !_compassEnabled;
      
      if (_locationReady) {
        if (_compassEnabled) {
          // Enable compass mode - rotate map to match current heading
          _mapController.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: _currentPosition,
                zoom: _currentZoom,
                bearing: _currentHeading,
              ),
            ),
          );
        } else {
          // Disable compass mode - reset map rotation to north
          _mapController.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: _currentPosition,
                zoom: _currentZoom,
                bearing: 0,
              ),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_locationReady) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Sci-fi loading animation
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.cyanAccent, width: 2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Rotating radar effect
                    AnimatedBuilder(
                      animation: _radarAnimationController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _radarAnimationController.value * 2 * pi,
                          child: CustomPaint(
                            size: const Size(150, 150),
                            painter: RadarPainter(),
                          ),
                        );
                      },
                    ),
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                      strokeWidth: 2,
                    ),
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.cyan.withOpacity(0.1),
                            Colors.blue.withOpacity(0.05),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'INITIALIZING LOCATION',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  color: Colors.cyanAccent,
                  fontSize: 18,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'SCANNING COORDINATES...',
                style: TextStyle(
                  color: Colors.blue[200],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _initializeLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.cyanAccent, width: 1),
                  ),
                ),
                child: const Text('RETRY SCAN'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          "EMOJI Explorer",
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 20,
            color: Colors.cyanAccent,
            letterSpacing: 2.0,
          ),
        ),
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 8,
        shadowColor: Colors.blue.withOpacity(0.5),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.cyan, width: 1),
              gradient: LinearGradient(
                colors: [Colors.blue[900]!, Colors.blue[800]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                Text(
                  '$_totalPoints',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.inventory, color: Colors.cyan),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => InventoryScreen(inventory: _inventoryBox.values.toList()),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: _currentZoom,
              bearing: _compassEnabled ? _currentHeading : 0,
            ),
            markers: _markers,
            onMapCreated: (controller) {
              _mapController = controller;
              controller.setMapStyle('''
[
  {
    "elementType": "geometry",
    "stylers": [{"color": "#1d2c4d"}]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#8ec3b9"}]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#1a3646"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{"color": "#304a7d"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#0e1626"}]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [{"color": "#283d6a"}]
  }
]
''');
              _generateEmojisAroundLocation();
            },
            onCameraMove: (position) {
              setState(() {
                _currentZoom = position.zoom;
              });
              _updateVisibleEmojis();
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: true, // Custom compass will be used
            zoomControlsEnabled: false,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            mapToolbarEnabled: false,
          ),
          _buildRadarWidget(),
          _buildStatusOverlay(),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 120.0),  // Move FABs up
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Toggle compass mode button
            FloatingActionButton(
              heroTag: 'compass',
              backgroundColor: _compassEnabled ? Colors.cyan : Colors.grey[800],
              onPressed: _toggleCompassMode,
              mini: true,
              child: Icon(
                Icons.compass_calibration,
                color: _compassEnabled ? Colors.white : Colors.cyan,
              ),
            ),
            const SizedBox(height: 10),
            // Center on player button
            FloatingActionButton(
              heroTag: 'location',
              backgroundColor: const Color(0xFF1D1E33),
              onPressed: _centerMapOnUser,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Colors.blue[700]!, Colors.blue[900]!],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.my_location,
                  color: Colors.cyanAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOverlay() {
    return Positioned(
      top: 10,
      left: 10,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.cyan.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isMoving ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  _isMoving ? "MOVING" : "STATIONARY",
                  style: TextStyle(
                    color: _isMoving ? Colors.green : Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "HEADING: ${_currentHeading.toStringAsFixed(0)}°",
              style: const TextStyle(
                color: Colors.cyan,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarWidget() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: const Color(0xFF1D1E33).withOpacity(0.9),
          border: Border.all(color: Colors.cyan.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildEnhancedRadarIndicator(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emoji counter with sci-fi design
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[900]!.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: Colors.cyan.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.visibility, color: Colors.cyan, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'DETECTED: ${_visibleEmojiIds.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Distance indicator with sci-fi design
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _distanceToClosestEmoji <= _interactionRadius
                          ? Colors.green.withOpacity(0.3)
                          : Colors.blue[900]!.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: _distanceToClosestEmoji <= _interactionRadius
                            ? Colors.green
                            : Colors.cyan.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.near_me,
                            color: _distanceToClosestEmoji <= _interactionRadius
                              ? Colors.green
                              : Colors.cyan,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _distanceToClosestEmoji == double.infinity
                              ? 'NO TARGETS'
                              : 'Closest: ${_distanceToClosestEmoji.toStringAsFixed(1)}m',
                            style: TextStyle(
                              color: _distanceToClosestEmoji <= _interactionRadius
                                ? Colors.green
                                : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Enhanced progress bar with glowing effect
            Stack(
              children: [
                // Background
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Progress
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 8,
                  width: MediaQuery.of(context).size.width * 
                    (_distanceToClosestEmoji > _visibilityRadius
                      ? 0.0
                      : 1.0 - (_distanceToClosestEmoji / _visibilityRadius)),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: _distanceToClosestEmoji <= _interactionRadius
                        ? [Colors.green, Colors.greenAccent]
                        : [Colors.blue, Colors.cyanAccent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _distanceToClosestEmoji <= _interactionRadius
                          ? Colors.green.withOpacity(0.5)
                          : Colors.cyan.withOpacity(0.5),
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedRadarIndicator() {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 1),
              gradient: RadialGradient(
                colors: [
                  Colors.blue.withOpacity(0.1),
                  Colors.black.withOpacity(0.0),
                ],
              ),
            ),
          ),
          // Middle ring
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 1),
            ),
          ),
          // Inner ring
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.2), width: 1),
              gradient: RadialGradient(
                colors: [
                  Colors.blue.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Rotating scan line
          AnimatedBuilder(
            animation: _radarAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _radarAnimation.value,
                child: CustomPaint(
                  size: const Size(80, 80),
                  painter: RadarScanPainter(),
                ),
              );
            },
          ),
          // Center dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.cyanAccent,
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withOpacity(0.5),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          // Blinking pulse animation when emoji is close
          if (_distanceToClosestEmoji <= _interactionRadius * 1.5)
            AnimatedOpacity(
              opacity: _showWalkingFrame ? 0.7 : 0.2,  // Reuse the animation timer
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _distanceToClosestEmoji <= _interactionRadius
                      ? Colors.green
                      : Colors.orange,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _walkingAnimationTimer?.cancel();
    _locationSubscription?.cancel();
    _emojiUpdateTimer?.cancel();
    _radarAnimationController.dispose();
    _mapController.dispose();
      super.dispose();
  }
}

// Custom painter for radar background effect
class RadarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double radius = size.width / 2;

    // Draw radar sweep line
    final Path path = Path()
      ..moveTo(centerX, centerY)
      ..lineTo(centerX + radius * cos(0), centerY + radius * sin(0));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

// Custom painter for radar scan effect
class RadarScanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width / 2;

    // Create the gradient for the scan line
    final scanPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          Colors.cyanAccent.withOpacity(0.0),
          Colors.cyanAccent.withOpacity(0.5),
          Colors.cyanAccent.withOpacity(0.8),
          Colors.cyanAccent
        ],
        stops: const [0.0, 0.75, 0.85, 0.95, 1.0],
        startAngle: 0,
        endAngle: pi / 2,
      ).createShader(Rect.fromCircle(
        center: Offset(centerX, centerY),
        radius: radius,
      ))
      ..style = PaintingStyle.fill;

    // Draw the scan sweep
    final scanPath = Path()
      ..moveTo(centerX, centerY)
      ..lineTo(centerX, 0)
      ..arcTo(
        Rect.fromCircle(center: Offset(centerX, centerY), radius: radius),
        -pi / 2,  // Start at the top
        pi / 4,   // Sweep a quarter of the circle
        true,
      )
      ..lineTo(centerX, centerY)
      ..close();

    canvas.drawPath(scanPath, scanPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}