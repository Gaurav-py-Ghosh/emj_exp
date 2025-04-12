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

class _MapScreenState extends State<MapScreen> {
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
  
  // Emoji management
  Set<String> _visibleEmojiIds = {};
  Timer? _emojiUpdateTimer;
  DateTime? _lastEmojiUpdate;
  
  // Camera
  List<CameraDescription>? _cameras;
  
  // Constants
  static const double _spawnRadius = 145.0;
  static const double _interactionRadius = 7.5;
  static const double _visibilityRadius = 20.0;
  static const Duration _emojiLifetime = Duration(minutes: 5);
  static const Duration _emojiRefreshInterval = Duration(minutes: 2);
  static const double _minEmojiDistance = 2.0;

  // Player icons
  late BitmapDescriptor _playerIconStill;
  late BitmapDescriptor _playerIconWalking;
  bool _isMoving = false;
  DateTime _lastLocationUpdate = DateTime.now();
  static const _movementThreshold = 0.5; // meters

  // Add this property at the top of the class
  Timer? _walkingAnimationTimer;
  bool _showWalkingFrame = false;

  // Add these properties to the class
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
  }

  Future<void> _initializeApp() async {
    await _createPlayerIcons();
    await _initializeStorage();
    await _initializeCamera();
    await _initializeLocation();
  }

  // Modify _createPlayerIcons to resize the icons
  Future<void> _createPlayerIcons() async {
    final ByteData stillData = await rootBundle.load('assets/still.png');
    final ByteData walkingData = await rootBundle.load('assets/walking.png');
    
    // Resize the icons to be smaller (adjust size as needed)
    final ui.Codec stillCodec = await ui.instantiateImageCodec(
      stillData.buffer.asUint8List(),
      targetWidth: 32, // Adjust size as needed
      targetHeight: 32,
    );
    final ui.Codec walkingCodec = await ui.instantiateImageCodec(
      walkingData.buffer.asUint8List(),
      targetWidth: 32, // Adjust size as needed
      targetHeight: 32,
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
            const SnackBar(content: Text('Location permission required')),
          );
        }
        return;
      }

      final serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        final serviceRequest = await _location.requestService();
        if (!serviceRequest && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services')),
          );
          return;
        }
      }

      final initialLocation = await _location.getLocation();
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(initialLocation.latitude!, initialLocation.longitude!);
          _locationReady = true;
        });
      }

      _startLocationTracking();
      _startEmojiUpdateTimer();
      _generateEmojisAroundLocation();
      
    } catch (e) {
      debugPrint('Location initialization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location error: ${e.toString()}')),
        );
      }
    }
  }

  // Modify _startLocationTracking
  void _startLocationTracking() {
    _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 1000,
      distanceFilter: 3.0,
    );

    _locationSubscription = _location.onLocationChanged.listen((LocationData currentLocation) {
      if (currentLocation.latitude == null || currentLocation.longitude == null) return;
      
      final newPosition = LatLng(currentLocation.latitude!, currentLocation.longitude!);
      final distance = _calculateDistance(_currentPosition, newPosition);
      final now = DateTime.now();
      
      // Update movement state
      final bool wasMoving = _isMoving;
      _isMoving = distance > _movementThreshold;
      
      // Start/stop walking animation
      if (_isMoving && _walkingAnimationTimer == null) {
        _walkingAnimationTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
          if (mounted) {
            setState(() => _showWalkingFrame = !_showWalkingFrame);
          }
        });
      } else if (!_isMoving && _walkingAnimationTimer != null) {
        _walkingAnimationTimer?.cancel();
        _walkingAnimationTimer = null;
        _showWalkingFrame = false;
      }
      
      if (!_locationReady || distance > 5 || wasMoving != _isMoving) {
        if (mounted) {
          setState(() {
            _currentPosition = newPosition;
            _locationReady = true;
            // Update player marker with appropriate icon and no rotation
            _markers.removeWhere((m) => m.markerId.value == 'player');
            _markers.add(Marker(
              markerId: const MarkerId('player'),
              position: newPosition,
              icon: _isMoving ? (_showWalkingFrame ? _playerIconWalking : _playerIconStill) : _playerIconStill,
              zIndex: 2,
              anchor: const Offset(0.5, 0.5), // Center the marker
            ));
          });
        }
        _updateMapCamera(newPosition);
        _updateVisibleEmojis();
      }
      _lastLocationUpdate = now;
    }, onError: (e) {
      debugPrint('Location tracking error: $e');
    });
  }

  void _updateMapCamera(LatLng newPosition) {
    if (_mapController != null) {
      _mapController.animateCamera(
        CameraUpdate.newLatLng(newPosition),
      );
    }
  }

  void _startEmojiUpdateTimer() {
    _emojiUpdateTimer?.cancel();
    _emojiUpdateTimer = Timer.periodic(_emojiRefreshInterval, (_) {
      if (_locationReady) {
        _generateEmojisAroundLocation();
      }
    });
  }

  // Modify _generateEmojisAroundLocation to include special locations
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
          hasSpecialAnimation: true  // Add this line
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

    // Generate random emojis as before
    final newEmojiCount = 7 + _random.nextInt(5);

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
          hasSpecialAnimation: emoji.tier >= 2  // Add this line
        );
      }
    }

    return EmojiTier(
      emoji: tierEmojis.first.emoji,
      tier: tierEmojis.first.tier,
      points: tierEmojis.first.points,
      spawnChance: tierEmojis.first.spawnChance,
      hasSpecialAnimation: tierEmojis.first.tier >= 2  // Add this line
    );
  }

  void _updateVisibleEmojis() {
    if (!_locationReady) return;

    final nowVisible = <String>{};
    double checkRadius = _visibilityRadius;

    if (_currentZoom < 16) checkRadius *= 1.5;
    if (_currentZoom < 14) checkRadius *= 2;

    for (final marker in _markers) {
      // Skip player marker when counting emojis
      if (marker.markerId.value == 'player') continue;
      
      final distance = _calculateDistance(_currentPosition, marker.position);
      if (distance <= checkRadius) {
        nowVisible.add(marker.markerId.value);
      }
    }

    if (mounted) {
      setState(() {
        _visibleEmojiIds = nowVisible;
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
    for (final marker in _markers) {
      if (!_visibleEmojiIds.contains(marker.markerId.value)) continue;
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
    if (_locationReady && _mapController != null) {
      await _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition, _currentZoom),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_locationReady) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text('Initializing location...'),
              TextButton(
                onPressed: _initializeLocation,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Emoji GO"),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Chip(
              label: Text('$_totalPoints pts'),
              backgroundColor: Colors.blue,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.inventory),
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
            ),
            markers: _markers.where((m) => _visibleEmojiIds.contains(m.markerId.value)).toSet(),
            onMapCreated: (controller) {
              _mapController = controller;
              _generateEmojisAroundLocation();
            },
            onCameraMove: (position) {
              setState(() {
                _currentZoom = position.zoom;
              });
              _updateVisibleEmojis();
            },
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            zoomControlsEnabled: false,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
          ),
          _buildRadarWidget(),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'location',
            onPressed: _centerMapOnUser,
            child: const Icon(Icons.my_location),
          ),
          
        ],
      ),
    );
  }

  Widget _buildRadarWidget() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Card(
        color: Colors.black.withOpacity(0.7),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildRadarIndicator(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nearby: ${_visibleEmojiIds.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        _distanceToClosestEmoji == double.infinity
                          ? 'No emojis detected'
                          : 'Closest: ${_distanceToClosestEmoji.toStringAsFixed(1)}m',
                        style: TextStyle(
                          color: _distanceToClosestEmoji <= _interactionRadius
                            ? Colors.green
                            : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _distanceToClosestEmoji > _visibilityRadius
                    ? 1.0
                    : _distanceToClosestEmoji / _visibilityRadius,
                backgroundColor: Colors.grey[800],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _distanceToClosestEmoji <= _interactionRadius
                    ? Colors.green
                    : Colors.orange,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadarIndicator() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blue, width: 2),
      ),
      child: Stack(
        children: [
          if (_distanceToClosestEmoji != double.infinity)
            AnimatedRotation(
              duration: const Duration(seconds: 3),
              turns: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: SweepGradient(
                    colors: [
                      Colors.transparent,
                      Colors.blue.withOpacity(0.3),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          Center(
            child: Icon(
              Icons.location_searching,
              color: Colors.blue[200],
              size: 30,
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
    _mapController.dispose();
    super.dispose();
  }
}