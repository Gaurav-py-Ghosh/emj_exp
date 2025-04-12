import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter_platform_interface/src/types/location.dart';
import 'package:vibration/vibration.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/emoji_model.dart';

class EmojiCatchScreen extends StatefulWidget {
  final EmojiTier emojiTier;
  final VoidCallback onCatchComplete;
  final LatLng? catchLocation;

  const EmojiCatchScreen({
    super.key,
    required this.emojiTier,
    required this.onCatchComplete,
    this.catchLocation,
  });

  @override
  State<EmojiCatchScreen> createState() => _EmojiCatchScreenState();
}

class _EmojiCatchScreenState extends State<EmojiCatchScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  late AnimationController _catchController;
  late AnimationController _specialAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isCaught = false;
  bool _cameraError = false;
  bool _isDisposed = false;
  bool _isSaving = false;
  double _scanPosition = 0;
  Timer? _scanTimer;
  double _progressValue = 0;
  Timer? _progressTimer;
  bool _showCaptureOptions = false;
  XFile? _capturedImage;
  bool _isScanning = false;
  final GlobalKey _captureKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    final catchDuration = Duration(
      seconds: widget.emojiTier.tier == 1 ? 10 : 
               widget.emojiTier.tier == 2 ? 12 : 15,
    );

    _catchController = AnimationController(
      vsync: this,
      duration: catchDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_isDisposed) {
          _catchComplete();
        }
      });

    if (widget.emojiTier.hasSpecialAnimation) {
      _specialAnimationController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      )..repeat(reverse: true);

      _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
        CurvedAnimation(
          parent: _specialAnimationController,
          curve: Curves.elasticOut,
        ),
      );

      _opacityAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(
          parent: _specialAnimationController,
          curve: Curves.easeInOut,
        ),
      );
    }

    _setupCamera();
  }

  Future<void> _setupCamera() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      _controller = CameraController(
        cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        ),
        ResolutionPreset.max,
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
    } catch (e) {
      debugPrint('Error: $e');
      if (!mounted || _isDisposed) return;
      setState(() => _cameraError = true);
    }
  }

  void _startScanning() {
    setState(() => _isScanning = true);
    _catchController.forward();
    
    _scanTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || _isDisposed || !_isScanning) {
        timer.cancel();
        return;
      }
      setState(() {
        _scanPosition = (_scanPosition + 0.02) % 1;
      });
    });

    const totalSteps = 100;
    final stepDuration = Duration(
      milliseconds: (widget.emojiTier.tier == 1 ? 10000 : 
                    widget.emojiTier.tier == 2 ? 12000 : 15000) ~/ totalSteps,
    );
    
    _progressTimer = Timer.periodic(stepDuration, (timer) {
      if (!mounted || _isDisposed || !_isScanning) {
        timer.cancel();
        return;
      }
      setState(() {
        _progressValue = (_progressValue + (1 / totalSteps)).clamp(0.0, 1.0);
        if (_progressValue >= 1.0) timer.cancel();
      });
    });
  }

  Future<void> _takePicture() async {
    try {
      setState(() {
        _showCaptureOptions = false;
        _isSaving = true;
      });

      final boundary = _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to capture screenshot');

      final directory = Directory('/storage/emulated/0/Pictures/EmojiExp');
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }

      final fileName = 'emoji_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      setState(() {
        _isSaving = false;
        _capturedImage = XFile(filePath);
      });

      _showPhotoPreview(XFile(filePath));
    } catch (e) {
      debugPrint('Error taking picture: $e');
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to take picture')),
      );
    }
  }

  void _showPhotoPreview(XFile image) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(File(image.path)),
            const SizedBox(height: 20),
            const Text(
              'Photo saved to gallery!',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _catchComplete() async {
    if (!mounted || _isDisposed) return;

    if (widget.emojiTier.tier >= 2) {
      await Vibration.vibrate(duration: widget.emojiTier.tier == 3 ? 1000 : 500);
    }

    setState(() {
      _isCaught = true;
      _isScanning = false;
      _scanTimer?.cancel();
      _progressTimer?.cancel();
    });

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted || _isDisposed) return;
    widget.onCatchComplete();
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _catchController.dispose();
    if (widget.emojiTier.hasSpecialAnimation) {
      _specialAnimationController.dispose();
    }
    _controller?.dispose();
    _scanTimer?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraError) {
      return _buildErrorScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_initializeControllerFuture != null)
            FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    _controller != null &&
                    _controller!.value.isInitialized) {
                  return Center(
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: RepaintBoundary(
                        key: _captureKey,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(_controller!),
                            Center(
                              child: widget.emojiTier.hasSpecialAnimation
                                  ? AnimatedBuilder(
                                      animation: _specialAnimationController,
                                      builder: (context, child) {
                                        return Opacity(
                                          opacity: _opacityAnimation.value,
                                          child: Transform.scale(
                                            scale: _scaleAnimation.value,
                                            child: Text(
                                              widget.emojiTier.emoji,
                                              style: const TextStyle(fontSize: 100),
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : Text(
                                      widget.emojiTier.emoji,
                                      style: const TextStyle(fontSize: 100),
                                    ),
                            ),
                            if (_isScanning)
                              Positioned(
                                top: _scanPosition * MediaQuery.of(context).size.height,
                                child: Container(
                                  width: MediaQuery.of(context).size.width,
                                  height: 2,
                                  color: Colors.red.withOpacity(0.7),
                                ),
                              ),
                            if (_isScanning)
                              Positioned(
                                bottom: 100,
                                left: 20,
                                right: 20,
                                child: Column(
                                  children: [
                                    Text(
                                      'Scanning... (Tier ${widget.emojiTier.tier})',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    LinearProgressIndicator(
                                      value: _progressValue,
                                      minHeight: 10,
                                      backgroundColor: Colors.grey[800],
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        _getProgressColor(widget.emojiTier.tier),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),

          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  heroTag: 'capture',
                  backgroundColor: Colors.white,
                  onPressed: () {
                    setState(() => _showCaptureOptions = true);
                  },
                  child: const Icon(Icons.camera_alt, color: Colors.black),
                ),
                FloatingActionButton(
                  heroTag: 'scan',
                  backgroundColor: Colors.blue,
                  onPressed: _isScanning ? null : _startScanning,
                  child: const Icon(Icons.qr_code_scanner, color: Colors.white),
                ),
              ],
            ),
          ),

          if (_showCaptureOptions) _buildCaptureOptionsModal(),

          if (_isSaving)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildCaptureOptionsModal() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Take a photo with the emoji?',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _takePicture,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  child: const Text('Take Photo'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () => setState(() => _showCaptureOptions = false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getProgressColor(int tier) {
    switch (tier) {
      case 1: return Colors.blue;
      case 2: return Colors.purple;
      case 3: return Colors.orange;
      default: return Colors.green;
    }
  }

  Widget _buildErrorScreen() {
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
              ),
              child: const Text(
                'Back to Map',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}