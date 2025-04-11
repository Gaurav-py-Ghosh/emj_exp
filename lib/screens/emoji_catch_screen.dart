import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class EmojiCatchScreen extends StatefulWidget {
  final String emoji;
  final VoidCallback onCatchComplete;

  const EmojiCatchScreen({
    super.key,
    required this.emoji,
    required this.onCatchComplete,
  });

  @override
  State<EmojiCatchScreen> createState() => _EmojiCatchScreenState();
}

class _EmojiCatchScreenState extends State<EmojiCatchScreen> with TickerProviderStateMixin {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  late AnimationController _catchController;
  double _scanPosition = 0;
  Timer? _scanTimer;
  bool _isCaught = false;
  bool _cameraError = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _catchController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_isDisposed) {
          _catchComplete();
        }
      });

    _setupCamera();
    _startScanning();
    _catchController.forward();
  }

  Future<void> _checkCameraPermission() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.camera.status;
      if (!status.isGranted) {
        final result = await Permission.camera.request();
        if (!result.isGranted) {
          throw Exception('Camera permission not granted');
        }
      }
    }
  }

  Future<void> _setupCamera() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await _checkCameraPermission();
      
      final cameras = await availableCameras();
      
      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      _controller = CameraController(
        cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        ),
        ResolutionPreset.medium,
        enableAudio: false,
      );

      _initializeControllerFuture = _controller!.initialize().then((_) {
        if (!mounted || _isDisposed) return;
        setState(() {});
      }).catchError((e) {
        if (!mounted || _isDisposed) return;
        setState(() => _cameraError = true);
        debugPrint('Camera error: $e');
      });
    } on CameraException catch (e) {
      debugPrint('CameraException: ${e.description}');
      if (!mounted || _isDisposed) return;
      setState(() => _cameraError = true);
    } on PlatformException catch (e) {
      debugPrint('PlatformException: ${e.message}');
      if (!mounted || _isDisposed) return;
      setState(() => _cameraError = true);
    } catch (e) {
      debugPrint('Error: $e');
      if (!mounted || _isDisposed) return;
      setState(() => _cameraError = true);
    }
  }

  void _startScanning() {
    _scanTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || _isDisposed) {
        timer.cancel();
        return;
      }
      setState(() {
        _scanPosition = (_scanPosition + 0.02) % 1;
      });
    });
  }

  void _catchComplete() {
    if (!mounted || _isDisposed) return;
    setState(() {
      _isCaught = true;
      _scanTimer?.cancel();
    });
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _isDisposed) return;
      widget.onCatchComplete();
      Navigator.pop(context, true);
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _catchController.dispose();
    _controller?.dispose();
    _scanTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraError) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.white, size: 50),
              const SizedBox(height: 20),
              const Text(
                'Camera unavailable',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Back to Map'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: _initializeControllerFuture == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  if (_controller == null || !_controller!.value.isInitialized) {
                    return _buildErrorState();
                  }
                  return Stack(
                    children: [
                      CameraPreview(_controller!),
                      _buildEmojiDisplay(),
                      _buildScanningOverlay(),
                      _buildCatchProgress(),
                      _buildCloseButton(),
                    ],
                  );
                } else if (snapshot.hasError) {
                  return _buildErrorState();
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt, size: 50, color: Colors.white),
          const SizedBox(height: 20),
          const Text(
            'Camera initialization failed',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Return to Map'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiDisplay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.emoji,
            style: const TextStyle(fontSize: 100),
          ),
          const SizedBox(height: 20),
          Text(
            _isCaught ? 'Caught!' : 'Scanning...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningOverlay() {
    return Positioned(
      top: _scanPosition * MediaQuery.of(context).size.height,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: 2,
        color: Colors.red.withOpacity(0.7),
      ),
    );
  }

  Widget _buildCatchProgress() {
    return Positioned(
      bottom: 50,
      left: 20,
      right: 20,
      child: LinearProgressIndicator(
        value: _catchController.value,
        minHeight: 20,
        backgroundColor: Colors.grey[800],
        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Positioned(
      top: 40,
      right: 20,
      child: IconButton(
        icon: const Icon(Icons.close, color: Colors.white, size: 30),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }
}