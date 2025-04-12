import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:camera/camera.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../widgets/emoji_model.dart';
import '../widgets/emoji_marker.dart';
import 'emoji_catch_screen.dart';
import 'inventory_screen.dart';
import 'package:permission_handler/permission_handler.dart';

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
  final List<EmojiInventoryItem> _inventory = [];
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

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _initializeCamera();
    await _initializeLocation();
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

  void _startLocationTracking() {
    _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 1000,
      distanceFilter: 3.0,
    );

    _locationSubscription = _location.onLocationChanged.listen((LocationData currentLocation) {
      if (currentLocation.latitude == null || currentLocation.longitude == null) return;
      
      final newPosition = LatLng(currentLocation.latitude!, currentLocation.longitude!);
      
      if (!_locationReady || _calculateDistance(_currentPosition, newPosition) > 5) {
        if (mounted) {
          setState(() {
            _currentPosition = newPosition;
            _locationReady = true;
          });
        }
        _updateMapCamera(newPosition);
        _updateVisibleEmojis();
      }
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

  Future<void> _generateEmojisAroundLocation() async {
    if (!_locationReady) return;

    debugPrint('Generating emojis around: $_currentPosition');
    
    final now = DateTime.now();
    _lastEmojiUpdate = now;
    final existingMarkers = _markers.toSet();

    _emojiSpawnTimes.removeWhere((id, spawnTime) {
      if (now.difference(spawnTime) > _emojiLifetime) {
        existingMarkers.removeWhere((m) => m.markerId.value == id);
        return true;
      }
      return false;
    });

    final newMarkers = <Marker>{};
    final newEmojiCount = 5 + _random.nextInt(5);

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
        return emoji;
      }
    }

    return tierEmojis.first;
  }

  void _updateVisibleEmojis() {
    if (!_locationReady) return;

    final nowVisible = <String>{};
    double checkRadius = _visibilityRadius;

    if (_currentZoom < 16) checkRadius *= 1.5;
    if (_currentZoom < 14) checkRadius *= 2;

    for (final marker in _markers) {
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
    if (mounted) {
      setState(() {
        _inventory.add(EmojiInventoryItem(
          emoji: emojiTier.emoji,
          points: emojiTier.points,
          tier: emojiTier.tier,
          caughtTime: DateTime.now(),
          caughtLocation: catchLocation,
        ));
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
                builder: (context) => InventoryScreen(inventory: _inventory),
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
              setState(() => _currentZoom = position.zoom);
              _updateVisibleEmojis();
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            zoomControlsEnabled: false,
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
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'refresh',
            onPressed: _generateEmojisAroundLocation,
            child: const Icon(Icons.refresh),
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
    _locationSubscription?.cancel();
    _emojiUpdateTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }
}