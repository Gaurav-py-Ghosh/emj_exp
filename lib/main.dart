import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emoji Exp',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MapScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  late Marker _animatedMarker;
  BitmapDescriptor? _emojiIcon;
  
  // Default location (San Francisco) before real location is fetched.
  final LatLng _currentLocation = const LatLng(37.7749, -122.4194);
  
  AnimationController? _animationController;
  Animation<double>? _latAnimation;
  Animation<double>? _lngAnimation;
  
  @override
  void initState() {
    super.initState();
    _loadEmojiIcon();
    _fetchCurrentLocation();
  }
  
  /// Loads the emoji icon from assets.
  Future<void> _loadEmojiIcon() async {
    BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(12, 12)),
      'assets/emoji.png',
    ).then((icon) {
      setState(() {
        _emojiIcon = icon;
      });
    });
  }

  
  /// Fetches the current location using the location package.
  Future<void> _fetchCurrentLocation() async {
    Location location = Location();
    
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }
    
    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }
    
    LocationData locData = await location.getLocation();
    LatLng newLocation = LatLng(locData.latitude!, locData.longitude!);
    _animateMarker(newLocation);
    _mapController.animateCamera(CameraUpdate.newLatLngZoom(newLocation, 14.0));
  }
  
  /// Smoothly animates the emoji marker from its current position to [destination].
  void _animateMarker(LatLng destination) {
    // Get the starting position of the current animated marker.
    final startLat = _animatedMarker.position.latitude;
    final startLng = _animatedMarker.position.longitude;
    
    // Dispose of any previous animation.
    _animationController?.dispose();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    // Create tweens for latitude and longitude.
    _latAnimation = Tween<double>(begin: startLat, end: destination.latitude)
      .animate(_animationController!);
    _lngAnimation = Tween<double>(begin: startLng, end: destination.longitude)
      .animate(_animationController!);
    
    _animationController!.addListener(() {
      LatLng newPos = LatLng(_latAnimation!.value, _lngAnimation!.value);
      setState(() {
        // Remove the old marker and add a new one at the updated position.
        _markers.removeWhere((marker) => marker.markerId == const MarkerId('animatedMarker'));
        _animatedMarker = Marker(
          markerId: const MarkerId('animatedMarker'),
          position: newPos,
          icon: _emojiIcon ?? BitmapDescriptor.defaultMarker,
          infoWindow: const InfoWindow(title: 'Emoji Marker'),
        );
        _markers.add(_animatedMarker);
      });
    });
    
    _animationController!.forward();
  }
  
  @override
  void dispose() {
    _animationController?.dispose();
    _mapController.dispose();
    super.dispose();
  }
  
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // Initialize the animated marker.
    _animatedMarker = Marker(
      markerId: const MarkerId('animatedMarker'),
      position: _currentLocation,
      icon: _emojiIcon ?? BitmapDescriptor.defaultMarker,
      infoWindow: const InfoWindow(title: 'Emoji Marker'),
    );
    setState(() {
      _markers.add(_animatedMarker);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Emoji Exp Map"),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _currentLocation,
          zoom: 14.0,
        ),
        markers: _markers,
        onMapCreated: _onMapCreated,
        // Tapping on the map moves the emoji marker smoothly to that location.
        onTap: (LatLng tappedPoint) {
          _animateMarker(tappedPoint);
        },
        myLocationEnabled: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
