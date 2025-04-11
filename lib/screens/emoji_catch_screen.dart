import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/emoji_model.dart';

class EmojiCatchScreen extends StatefulWidget {
  final EmojiTier emojiTier;
  final VoidCallback onCatchComplete;

  const EmojiCatchScreen({
    super.key,
    required this.emojiTier,
    required this.onCatchComplete,
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
  double _scanPosition = 0;
  Timer? _scanTimer;
  bool _isCaught = false;
  bool _cameraError = false;
  bool _isDisposed = false;
  double _progressValue = 0;
  Timer? _progressTimer;

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
    _startScanning();
    _startProgressTimer();
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

  void _startProgressTimer() {
    const totalSteps = 100;
    const stepDuration = Duration(milliseconds: 100);
    
    _progressTimer = Timer.periodic(stepDuration, (timer) {
      if (!mounted || _isDisposed) {
        timer.cancel();
        return;
      }
      setState(() {
        _progressValue = (_progressValue + (1 / totalSteps)).clamp(0.0, 1.0);
        if (_progressValue >= 1.0) timer.cancel();
      });
    });
  }

  void _catchComplete() async {
    if (!mounted || _isDisposed) return;
    
    // Vibrate based on tier
    if (widget.emojiTier.tier >= 2) {
      await Vibration.vibrate(duration: widget.emojiTier.tier == 3 ? 1000 : 500);
    }

    setState(() {
      _isCaught = true;
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
        children: [
          // Camera Preview
          if (_initializeControllerFuture != null)
            FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    _controller != null &&
                    _controller!.value.isInitialized) {
                  return CameraPreview(_controller!);
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),
          
          // Overlay
          Container(
            color: Colors.black.withOpacity(0.4),
            child: Column(
              children: [
                const Spacer(),
                _buildEmojiDisplay(),
                const Spacer(),
                _buildProgressIndicator(),
                const SizedBox(height: 30),
              ],
            ),
          ),
          
          // Scanning Line
          Positioned(
            top: _scanPosition * MediaQuery.of(context).size.height,
            child: Container(
              width: MediaQuery.of(context).size.width,
              height: 2,
              color: Colors.red.withOpacity(0.7),
            ),
          ),
          
          // Close Button
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context, false),
            ),
          ),
        ],
      ),
    );
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

  Widget _buildEmojiDisplay() {
    final emojiWidget = Text(
      widget.emojiTier.emoji,
      style: const TextStyle(fontSize: 100),
    );

    if (!widget.emojiTier.hasSpecialAnimation) {
      return emojiWidget;
    }

    return AnimatedBuilder(
      animation: _specialAnimationController,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: emojiWidget,
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        Text(
          _isCaught ? 'Caught!' : 'Scanning... (Tier ${widget.emojiTier.tier})',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: LinearProgressIndicator(
            value: _progressValue,
            minHeight: 20,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(
              _getProgressColor(widget.emojiTier.tier),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${widget.emojiTier.points} points',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
      ],
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
}