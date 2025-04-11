import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import '../widgets/emoji_marker.dart';
import 'package:camera/camera.dart';
import 'emoji_catch_screen.dart';

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
  int _caughtEmojis = 0;
  bool _isCatching = false;
  late AnimationController _catchAnimationController;
  List<CameraDescription>? _cameras;

  @override
  void initState() {
    super.initState();
    _catchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _initializeCamera();
    _initMap();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  Future<void> _initMap() async {
    try {
      final location = await _locationService.getCurrentLocation();
      await _generateRandomEmojis(location, 10);
      await _animateMarker(location);
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(location, 20.0),
      );
    } catch (e) {
      debugPrint('Map initialization error: $e');
    }
  }

  Future<void> _generateRandomEmojis(LatLng center, int count) async {
    const radius = 0.0001;
    final markers = <Marker>[];
    for (int i = 0; i < count; i++) {
      final offsetLat = (_random.nextDouble() * 2 - 1) * radius;
      final offsetLng = (_random.nextDouble() * 2 - 1) * radius;
      final position = LatLng(
        center.latitude + offsetLat,
        center.longitude + offsetLng,
      );
      final emoji = _getRandomEmoji();
      markers.add(
        await EmojiMarker.createMarker(
          position: position,
          id: 'emoji$i',
          emoji: emoji,
          size: 60,
          onTap: () => _startCatchingEmoji('emoji$i', emoji),
        ),
      );
    }
    if (mounted) {
      setState(() {
        _markers.addAll(markers);
      });
    }
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
      onTap: () {},
    );
    if (mounted) {
      setState(() {
        _animatedMarker = newMarker;
        _markers.add(newMarker);
      });
    }
  }

  void _startCatchingEmoji(String markerId, String emoji) async {
    if (_isCatching || _cameras == null) return;
    
    try {
      setState(() => _isCatching = true);
      
      final caught = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => EmojiCatchScreen(
            emoji: emoji,
            onCatchComplete: () => _catchEmoji(markerId),
          ),
        ),
      );

      if (caught ?? false) {
        _catchEmoji(markerId);
      }
    } on CameraException catch (e) {
      debugPrint('CameraException: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera access required for catching')),
      );
    } on PlatformException catch (e) {
      debugPrint('PlatformException: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message ?? 'Unknown error'}')),
      );
    } catch (e) {
      debugPrint('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start catching')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCatching = false);
      }
    }
  }

  void _catchEmoji(String markerId) {
    if (mounted) {
      setState(() {
        _markers.removeWhere((m) => m.markerId.value == markerId);
        _caughtEmojis++;
      });
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _catchAnimationController.dispose();
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
              label: Text('Caught: $_caughtEmojis'),
              backgroundColor: Colors.blue,
            ),
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(0, 0),
          zoom: 20.0,
        ),
        markers: _markers,
        onMapCreated: _onMapCreated,
        onTap: (LatLng tappedPoint) async {
          await _animateMarker(tappedPoint);
        },
        myLocationEnabled: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _initMap,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}