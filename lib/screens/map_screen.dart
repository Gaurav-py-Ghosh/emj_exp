import 'dart:async';
import 'dart:math';
import 'package:emoji_exp/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:camera/camera.dart';
import '../widgets/emoji_marker.dart';
import '../widgets/emoji_model.dart';
import 'emoji_catch_screen.dart';
import 'inventory_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  Marker? _animatedMarker;
  final LocationService _locationService = LocationService();
  final Random _random = Random();
  int _totalPoints = 0;
  bool _isCatching = false;
  Timer? _generationTimer;
  LatLng? _currentLocation;
  double _distanceToClosestEmoji = double.infinity;
  final List<EmojiInventoryItem> _inventory = [];
  final Hotspot _specialHotspot = Hotspot(
    location: LatLng(37.7749, -122.4194), // Example coordinates (SF)
    guaranteedTier: 3,
  );
  List<CameraDescription>? _cameras;
  DateTime? _lastGenerationTime;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initMap();
    _startGenerationTimer();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  void _startGenerationTimer() {
    _generationTimer = Timer.periodic(
      const Duration(minutes: 10), 
      (_) => _generateEmojisAroundLocation(),
    );
  }

  Future<void> _initMap() async {
    try {
      final location = await _locationService.getCurrentLocation();
      setState(() => _currentLocation = location);
      await _generateEmojisAroundLocation();
      await _animateMarker(location);
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(location, 18.0),
      );
    } catch (e) {
      debugPrint('Map initialization error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to initialize map')),
      );
    }
  }

  Future<void> _generateEmojisAroundLocation() async {
    if (_currentLocation == null) return;

    final newMarkers = <Marker>[];
    const radius = 350 / 111300.0; // Convert meters to degrees
    _lastGenerationTime = DateTime.now();

    // Generate regular emojis with tier distribution
    for (int i = 0; i < 15; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final distance = _random.nextDouble() * radius;
      final offsetLat = distance * cos(angle);
      final offsetLng = distance * sin(angle);
      
      final position = LatLng(
        _currentLocation!.latitude + offsetLat,
        _currentLocation!.longitude + offsetLng,
      );

      // Tier distribution: 70% Tier 1, 25% Tier 2, 5% Tier 3
      final tierRoll = _random.nextInt(100);
      EmojiTier emojiTier;
      if (tierRoll < 70) {
        emojiTier = emojiTiers.where((e) => e.tier == 1).elementAt(_random.nextInt(3));
      } else if (tierRoll < 95) {
        emojiTier = emojiTiers.where((e) => e.tier == 2).elementAt(_random.nextInt(2));
      } else {
        emojiTier = emojiTiers.where((e) => e.tier == 3).elementAt(_random.nextInt(2));
      }

      newMarkers.add(
        await EmojiMarker.createMarker(
          position: position,
          id: 'emoji_${DateTime.now().millisecondsSinceEpoch}_$i',
          emoji: emojiTier.emoji,
          size: emojiTier.tier == 3 ? 70 : 60, // Larger for tier 3
          tier: emojiTier.tier,
          onTap: () => _handleEmojiTap(position, emojiTier),
        ),
      );
    }

    // Generate guaranteed hotspot emoji if within range
    final hotspotDistance = _calculateDistance(_currentLocation!, _specialHotspot.location);
    if (hotspotDistance <= 350) {
      final hotspotTier = emojiTiers.where((e) => e.tier == _specialHotspot.guaranteedTier).first;
      newMarkers.add(
        await EmojiMarker.createMarker(
          position: _specialHotspot.location,
          id: 'hotspot_emoji',
          emoji: hotspotTier.emoji,
          size: 80, // Extra large for hotspot
          tier: hotspotTier.tier,
          onTap: () => _handleEmojiTap(_specialHotspot.location, hotspotTier),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _markers
          ..clear()
          ..addAll(newMarkers);
        _updateClosestEmoji();
      });
    }
  }

  double _calculateDistance(LatLng pos1, LatLng pos2) {
    const earthRadius = 6371000.0; // meters
    final lat1 = pos1.latitude * pi / 180;
    final lon1 = pos1.longitude * pi / 180;
    final lat2 = pos2.latitude * pi / 180;
    final lon2 = pos2.longitude * pi / 180;

    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  void _handleEmojiTap(LatLng emojiPosition, EmojiTier emojiTier) async {
    if (_currentLocation == null || _isCatching) return;

    final distance = _calculateDistance(_currentLocation!, emojiPosition);
    if (distance > 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Too far away! ${distance.toStringAsFixed(1)}m'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isCatching = true);

    try {
      final caught = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => EmojiCatchScreen(
            emojiTier: emojiTier,
            onCatchComplete: () => _addToInventory(emojiTier),
          ),
        ),
      );

      if (caught ?? false) {
        _markers.removeWhere((m) => m.position == emojiPosition);
        _updateClosestEmoji();
      }
    } catch (e) {
      debugPrint('Error catching emoji: $e');
    } finally {
      if (mounted) {
        setState(() => _isCatching = false);
      }
    }
  }

  void _addToInventory(EmojiTier emojiTier) {
    setState(() {
      _inventory.add(EmojiInventoryItem(
        emoji: emojiTier.emoji,
        points: emojiTier.points,
        caughtTime: DateTime.now(),
      ));
      _totalPoints += emojiTier.points;
    });
  }

  void _updateClosestEmoji() {
    if (_currentLocation == null || _markers.isEmpty) {
      setState(() => _distanceToClosestEmoji = double.infinity);
      return;
    }

    double minDistance = double.infinity;
    for (final marker in _markers) {
      final distance = _calculateDistance(_currentLocation!, marker.position);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    setState(() => _distanceToClosestEmoji = minDistance);
  }

  Future<void> _animateMarker(LatLng destination) async {
    _markers.removeWhere((m) => m.markerId.value == 'animatedMarker');
    final newMarker = await EmojiMarker.createMarker(
      position: destination,
      id: 'animatedMarker',
      emoji: '📍',
      size: 32,
      tier: 0,
      onTap: () {},
    );
    if (mounted) {
      setState(() {
        _animatedMarker = newMarker;
        _markers.add(newMarker);
        _updateClosestEmoji();
      });
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _generationTimer?.cancel();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Emoji Map"),
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
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0),
              zoom: 18.0,
            ),
            markers: _markers.where((marker) {
              if (_currentLocation == null) return false;
              final distance = _calculateDistance(
                _currentLocation!, 
                marker.position
              );
              return distance <= 15; // Only show within 15m
            }).toSet(),
            onMapCreated: _onMapCreated,
            onTap: (LatLng tappedPoint) async {
              await _animateMarker(tappedPoint);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildDistanceIndicator(),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'location',
            onPressed: _initMap,
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'refresh',
            onPressed: _generateEmojisAroundLocation,
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'hotspot',
            onPressed: () => _mapController.animateCamera(
              CameraUpdate.newLatLng(_specialHotspot.location),
            ),
            child: const Icon(Icons.star),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceIndicator() {
    return Card(
      color: Colors.black.withOpacity(0.7),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  _lastGenerationTime == null 
                    ? 'Generating soon...'
                    : 'Next gen: ${_formatTimeRemaining()}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.emoji_emotions, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  _distanceToClosestEmoji == double.infinity
                    ? 'No emojis nearby'
                    : 'Closest: ${_distanceToClosestEmoji.toStringAsFixed(1)}m',
                  style: TextStyle(
                    color: _distanceToClosestEmoji <= 7 
                      ? Colors.green 
                      : Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _distanceToClosestEmoji > 15 
                  ? 1.0 
                  : _distanceToClosestEmoji / 15,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(
                _distanceToClosestEmoji <= 7 
                  ? Colors.green 
                  : Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeRemaining() {
    if (_lastGenerationTime == null) return '0:00';
    final nextGen = _lastGenerationTime!.add(const Duration(minutes: 10));
    final remaining = nextGen.difference(DateTime.now());
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}