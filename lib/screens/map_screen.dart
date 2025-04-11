import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
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
  @override
  void initState() {
    super.initState();
    _initMap();
  }

  Future<void> _initMap() async {
    final location = await _locationService.getCurrentLocation();
    await _generateRandomEmojis(location, 10); // Generate 10 random emojis
    await _animateMarker(location);
    _mapController.animateCamera(
      CameraUpdate.newLatLngZoom(location, 18.0),
    ); // Zoomed in more
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
      markers.add(
        await EmojiMarker.createMarker(
          position: position,
          id: 'emoji$i',
          emoji: _getRandomEmoji(),
          size: 24, // Smaller size
        ),
      );
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
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Emoji Map")),
      body: GoogleMap(
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _initMap,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
