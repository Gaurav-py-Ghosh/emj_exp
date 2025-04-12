import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_maps_flutter_platform_interface/src/types/location.dart';
import 'package:vibration/vibration.dart';
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
  late AnimationController _pulseAnimationController;
  late AnimationController _rotationController;
  late AnimationController _scannerController;
  late AnimationController _captureAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scannerAnimation;
  late Animation<Color?> _scannerColorAnimation;
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
  bool _isPausedScanning = false;
  final GlobalKey _captureKey = GlobalKey();
  
  // Variables for enhanced effects
  List<Particle> _particles = [];
  Timer? _particleTimer;
  bool _showCaptureAnimation = false;
  bool _showHologramEffect = false;
  final math.Random _random = math.Random();

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
          _captureEmoji();
        }
      });

    _specialAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
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
    
    // Pulse animation for the scanning effect
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Rotation animation for high-tech elements
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _rotationController,
        curve: Curves.linear,
      ),
    );
    
    // Scanner animation
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    _scannerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scannerController,
        curve: Curves.easeInOut,
      ),
    );
    
    _scannerColorAnimation = ColorTween(
      begin: _getTierColor(widget.emojiTier.tier).withOpacity(0.5),
      end: _getTierColor(widget.emojiTier.tier).withOpacity(0.9),
    ).animate(_scannerController);
    
    // Capture animation
    _captureAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

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
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _initializeControllerFuture = _controller!.initialize().then((_) {
        if (!mounted || _isDisposed) return;
        setState(() {
          _showHologramEffect = true;
        });
        _playBootupSound();
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

  void _playBootupSound() {
    // This would be implemented with a sound package
    // For now we'll just use vibration as feedback
    Vibration.vibrate(duration: 100, amplitude: 50);
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
      _isPausedScanning = false;
      _showHologramEffect = false;
    });
    _catchController.forward();
    
    // Vibration feedback based on tier
    Vibration.vibrate(duration: 200, amplitude: widget.emojiTier.tier * 50);
    
    _scanTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || _isDisposed || !_isScanning || _isPausedScanning) {
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
      if (!mounted || _isDisposed || !_isScanning || _isPausedScanning) {
        return;
      }
      setState(() {
        _progressValue = (_progressValue + (1 / totalSteps)).clamp(0.0, 1.0);
        if (_progressValue >= 1.0) timer.cancel();
      });
    });
    
    // Create particles for scanning effect
    _createParticles();
  }
  
  void _pauseScanning() {
    if (!_isScanning) return;
    
    setState(() {
      _isPausedScanning = true;
    });
    
    // Pause the catch controller
    _catchController.stop();
  }
  
  void _resumeScanning() {
    if (!_isScanning || !_isPausedScanning) return;
    
    setState(() {
      _isPausedScanning = false;
    });
    
    // Resume the catch controller
    _catchController.forward();
  }
  
  void _createParticles() {
    _particles = [];
    _particleTimer?.cancel();
    
    _particleTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted || _isDisposed || !_isScanning || _isPausedScanning) {
        return;
      }
      
      setState(() {
        // Add new particles (fewer for better performance)
        for (int i = 0; i < 2; i++) {
          _particles.add(Particle(
            position: Offset(
              _random.nextDouble() * MediaQuery.of(context).size.width,
              _random.nextDouble() * MediaQuery.of(context).size.height,
            ),
            velocity: Offset(
              (_random.nextDouble() - 0.5) * 3, // Reduced velocity for smoother movement
              (_random.nextDouble() - 0.5) * 3,
            ),
            color: _getTierColor(widget.emojiTier.tier),
            size: 3 + _random.nextDouble() * 7, // Smaller particles for better performance
            lifespan: 25 + _random.nextInt(40),
          ));
        }
        
        // Update existing particles
        for (int i = _particles.length - 1; i >= 0; i--) {
          _particles[i].update();
          if (_particles[i].isDead()) {
            _particles.removeAt(i);
          }
        }
        
        // Limit maximum number of particles for performance
        if (_particles.length > 40) {
          _particles = _particles.sublist(_particles.length - 40);
        }
      });
    });
  }

  Future<void> _takePicture() async {
    try {
      // Pause scanning if active
      if (_isScanning && !_isPausedScanning) {
        _pauseScanning();
      }
      
      setState(() {
        _showCaptureOptions = false;
        _isSaving = true;
      });

      // Wait a short delay to ensure UI updates before capture
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0); // Reduced for performance
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to capture screenshot');

      final tempDir = await getTemporaryDirectory();
      final directory = Directory('${tempDir.path}/EmojiExp');
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
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: _getTierColor(widget.emojiTier.tier),
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Image.file(
                    File(image.path),
                    fit: BoxFit.contain,
                  ),
                ),
                Container(
                  color: Colors.black,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Specimen Photo Saved',
                        style: TextStyle(
                          color: _getTierColor(widget.emojiTier.tier),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Continue scanning to complete capture',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (_isScanning && _isPausedScanning) {
                            _resumeScanning();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getTierColor(widget.emojiTier.tier),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30, 
                            vertical: 12
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'CONTINUE SCANNING',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _captureEmoji() async {
    if (!mounted || _isDisposed) return;

    setState(() {
      _showCaptureAnimation = true;
    });
    
    // Start the capture animation
    _captureAnimationController.reset();
    _captureAnimationController.forward();
    
    // Intense vibration patterns based on tier
    if (widget.emojiTier.tier == 1) {
      Vibration.vibrate(pattern: [0, 100, 50, 100]);
    } else if (widget.emojiTier.tier == 2) {
      Vibration.vibrate(pattern: [0, 150, 50, 150, 50, 150]);
    } else {
      Vibration.vibrate(pattern: [0, 200, 50, 200, 50, 200, 50, 200]);
    }

    await Future.delayed(const Duration(milliseconds: 1500));
    
    setState(() {
      _isCaught = true;
      _isScanning = false;
      _isPausedScanning = false;
      _scanTimer?.cancel();
      _progressTimer?.cancel();
      _particleTimer?.cancel();
    });

    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted || _isDisposed) return;
    widget.onCatchComplete();
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _catchController.dispose();
    _specialAnimationController.dispose();
    _pulseAnimationController.dispose();
    _rotationController.dispose();
    _scannerController.dispose();
    _captureAnimationController.dispose();
    _controller?.dispose();
    _scanTimer?.cancel();
    _progressTimer?.cancel();
    _particleTimer?.cancel();
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
                    child: RepaintBoundary(
                      key: _captureKey,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Camera preview fitted to screen dimensions
                          _buildCameraPreview(),
                          
                          // Sci-fi interface overlay with reduced complexity
                          CustomPaint(
                            painter: GridPainter(
                              color: _getTierColor(widget.emojiTier.tier).withOpacity(0.15),
                              gridSpacing: 40, // Increase spacing for better performance
                            ),
                          ),
                          
                          // Corner interface elements
                          _buildCornerElements(),
                          
                          // Emoji display with animations
                          if (!_isCaught) _buildEmojiDisplay(),
                          
                          // Scanning effect - optimized
                          if (_isScanning) ...[
                            // Horizontal scanner line
                            AnimatedBuilder(
                              animation: _scannerAnimation,
                              builder: (context, child) {
                                return Positioned(
                                  top: _scannerAnimation.value * MediaQuery.of(context).size.height,
                                  child: Container(
                                    width: MediaQuery.of(context).size.width,
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: _getTierColor(widget.emojiTier.tier).withOpacity(0.8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _getTierColor(widget.emojiTier.tier).withOpacity(0.6),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            
                            // Particle effects - only drawn when visible and limited count
                            if (_particles.isNotEmpty)
                              CustomPaint(
                                painter: ParticlePainter(particles: _particles),
                                size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
                              ),
                            
                            // Progress indicator
                            Positioned(
                              bottom: 100,
                              left: 20,
                              right: 20,
                              child: Column(
                                children: [
                                  Text(
                                    _isPausedScanning ? 'SCAN PAUSED' : 'ANALYZING ${widget.emojiTier.emoji} SPECIMEN',
                                    style: TextStyle(
                                      color: _getTierColor(widget.emojiTier.tier),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                      shadows: [
                                        Shadow(
                                          color: _getTierColor(widget.emojiTier.tier).withOpacity(0.7),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        'TIER ${widget.emojiTier.tier}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${(_progressValue * 100).toInt()}%',
                                        style: TextStyle(
                                          color: _getTierColor(widget.emojiTier.tier),
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Stack(
                                        children: [
                                          Container(
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.white24,
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            height: 10,
                                            width: constraints.maxWidth * _progressValue,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(10),
                                              gradient: LinearGradient(
                                                colors: [
                                                  _getTierColor(widget.emojiTier.tier).withOpacity(0.7),
                                                  _getTierColor(widget.emojiTier.tier),
                                                ],
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: _getTierColor(widget.emojiTier.tier).withOpacity(0.5),
                                                  blurRadius: 8,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                          
                          // Capture animation effect - optimized to be smoother
                          if (_showCaptureAnimation)
                            AnimatedBuilder(
                              animation: _captureAnimationController,
                              builder: (context, child) {
                                final double value = _captureAnimationController.value;
                                return Stack(
                                  children: [
                                    // White flash at beginning removed to avoid red flash issue
                                    
                                    // Expanding circle effect
                                    Center(
                                      child: Container(
                                        width: value * MediaQuery.of(context).size.width * 1.5,
                                        height: value * MediaQuery.of(context).size.width * 1.5,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.transparent,
                                          border: Border.all(
                                            color: _getTierColor(widget.emojiTier.tier).withOpacity((1 - value) * 0.8),
                                            width: (1 - value) * 5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    // Simplified radial lines effect
                                    CustomPaint(
                                      painter: CaptureEffectPainter(
                                        progress: value,
                                        color: _getTierColor(widget.emojiTier.tier),
                                        numLines: 16, // Reduced for better performance
                                      ),
                                      size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
                                    ),
                                    
                                    // Success text
                                    if (value > 0.7)
                                      Center(
                                        child: Text(
                                          'CAPTURE SUCCESSFUL',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 28 * (value - 0.7) * 3.3,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 2,
                                            shadows: [
                                              Shadow(
                                                color: _getTierColor(widget.emojiTier.tier),
                                                blurRadius: 15,
                                                offset: const Offset(0, 0),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                }
                return _buildLoadingScreen();
              },
            ),

          // Action buttons
          if (!_isCaught && !_showCaptureAnimation)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.camera_alt,
                      backgroundColor: Colors.grey[850]!,
                      foregroundColor: Colors.white,
                      onPressed: () {
                        if (_isScanning) {
                          _takePicture();
                        } else {
                          setState(() => _showCaptureOptions = true);
                        }
                      },
                      label: 'PHOTO',
                    ),
                    const SizedBox(width: 20),
                    _buildActionButton(
                      icon: _isScanning && !_isPausedScanning ? Icons.pause : Icons.radar,
                      backgroundColor: _isScanning && !_isPausedScanning
                          ? Colors.grey[700]!
                          : _getTierColor(widget.emojiTier.tier),
                      foregroundColor: Colors.white,
                      onPressed: _isScanning && !_isPausedScanning
                          ? _pauseScanning
                          : _isPausedScanning
                              ? _resumeScanning
                              : _startScanning,
                      label: _isScanning && !_isPausedScanning
                          ? 'PAUSE'
                          : _isPausedScanning
                              ? 'RESUME'
                              : 'SCAN',
                      isActive: _isScanning && !_isPausedScanning,
                    ),
                  ],
                ),
              ),
            ),

          if (_showCaptureOptions) _buildCaptureOptionsModal(),

          if (_isSaving)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 70,
                      height: 70,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getTierColor(widget.emojiTier.tier),
                        ),
                        strokeWidth: 6,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'PROCESSING CAPTURE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildCameraPreview() {
    // This ensures the camera preview is properly fitted to the screen
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;
    
    final camera = _controller!.value;
    final previewRatio = camera.aspectRatio;
    
    // Calculate the scaled size for the preview
    Widget preview;
    
    if (deviceRatio > previewRatio) {
      // Screen is wider than camera preview, scale by width
      preview = SizedBox(
        width: size.width,
        height: size.width / previewRatio,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.fitWidth,
              child: SizedBox(
                width: size.width,
                height: size.width / camera.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            ),
          ),
        ),
      );
    } else {
      // Screen is taller than camera preview, scale by height
      preview = SizedBox(
        width: size.height * previewRatio,
        height: size.height,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.fitHeight,
              child: SizedBox(
                width: size.height * camera.aspectRatio,
                height: size.height,
                child: CameraPreview(_controller!),
              ),
            ),
          ),
        ),
      );
    }
    
    return Center(child: preview);
  }
  
    Widget _buildEmojiDisplay() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: _showHologramEffect ? [
            BoxShadow(
              color: _getTierColor(widget.emojiTier.tier).withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ] : null,
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _specialAnimationController,
            _pulseAnimationController,
          ]),
          builder: (context, child) {
            return Transform.scale(
              scale: _showHologramEffect 
                  ? _scaleAnimation.value * _pulseAnimation.value
                  : _scaleAnimation.value,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_showHologramEffect) ...[
                    // Simplified hologram effect
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _getTierColor(widget.emojiTier.tier),
                          width: 3,
                        ),
                      ),
                    ),
                  ],
                  
                  // The emoji itself
                  Opacity(
                    opacity: _opacityAnimation.value,
                    child: Text(
                      widget.emojiTier.emoji,
                      style: TextStyle(
                        fontSize: 100,
                        shadows: _showHologramEffect ? [
                          Shadow(
                            color: _getTierColor(widget.emojiTier.tier),
                            blurRadius: 15,
                            offset: const Offset(0, 0),)
                        ] : null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildCornerElements() {
    return Stack(
      children: [
        // Top-left corner - enhanced with location info
        Positioned(
          top: 40,
          left: 20,
          child: Container(
            width: 120,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _getTierColor(widget.emojiTier.tier).withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.emojiTier.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ID:${widget.emojiTier.tier}',
                      style: TextStyle(
                        color: _getTierColor(widget.emojiTier.tier),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (widget.catchLocation != null)
                  Text(
                    '${widget.catchLocation!.latitude.toStringAsFixed(2)},\n${widget.catchLocation!.longitude.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        // Top-right corner - simplified
        Positioned(
          top: 40,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _getTierColor(widget.emojiTier.tier).withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'TIER ${widget.emojiTier.tier}',
                  style: TextStyle(
                    color: _getTierColor(widget.emojiTier.tier),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'SPECIMEN',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaptureOptionsModal() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: _getTierColor(widget.emojiTier.tier),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _getTierColor(widget.emojiTier.tier).withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CAPTURE OPTIONS',
                  style: TextStyle(
                    color: _getTierColor(widget.emojiTier.tier),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 1,
                  color: Colors.white24,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Save specimen to research database?',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildOptionButton(
                      label: 'CANCEL',
                      color: Colors.grey[700]!,
                      onPressed: () => setState(() => _showCaptureOptions = false),
                      icon: Icons.close,
                    ),
                    _buildOptionButton(
                      label: 'CAPTURE',
                      color: _getTierColor(widget.emojiTier.tier),
                      onPressed: _takePicture,
                      icon: Icons.camera_alt,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildOptionButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
    required IconData icon,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required Color backgroundColor,
    required Color foregroundColor,
    required VoidCallback? onPressed,
    required String label,
    bool isActive = false,
  }) {
    // Disable photo button if scanning hasn't started
    final bool isPhotoButton = label == 'PHOTO';
    final bool isEnabled = isPhotoButton ? _isScanning : true;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: isActive ? [
              BoxShadow(
                color: backgroundColor.withOpacity(0.6),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ] : null,
          ),
          child: FloatingActionButton(
            heroTag: label.toLowerCase(),
            backgroundColor: isEnabled ? backgroundColor : Colors.grey[800],
            onPressed: isEnabled ? onPressed : null,
            child: Icon(
              icon, 
              color: isEnabled ? foregroundColor : Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isEnabled 
                ? (isActive ? backgroundColor : Colors.white70)
                : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Background grid
          CustomPaint(
            painter: GridPainter(
              color: _getTierColor(widget.emojiTier.tier).withOpacity(0.15),
              gridSpacing: 30,
            ),
          ),
          
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                    border: Border.all(
                      color: _getTierColor(widget.emojiTier.tier).withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getTierColor(widget.emojiTier.tier),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'INITIALIZING SCANNER',
                  style: TextStyle(
                    color: _getTierColor(widget.emojiTier.tier),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'CALIBRATING SYSTEMS...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background grid
          CustomPaint(
            painter: GridPainter(
              color: Colors.red.withOpacity(0.15),
              gridSpacing: 30,
            ),
          ),
          
          Center(
            child: Container(
              padding: const EdgeInsets.all(30),
              width: MediaQuery.of(context).size.width * 0.8,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.withOpacity(0.2),
                      border: Border.all(color: Colors.red, width: 2),
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'SYSTEM ERROR',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Camera initialization failed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Scanner systems offline',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.arrow_back, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'RETURN TO MAP',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTierColor(int tier) {
    switch (tier) {
      case 1: return Colors.blue;
      case 2: return Colors.purple;
      case 3: return Colors.orange;
      default: return Colors.green;
    }
  }
}

// Custom Painters

class GridPainter extends CustomPainter {
  final Color color;
  final double gridSpacing;

  GridPainter({required this.color, required this.gridSpacing});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw vertical lines
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) => 
      color != oldDelegate.color || gridSpacing != oldDelegate.gridSpacing;
}

class CaptureEffectPainter extends CustomPainter {
  final double progress;
  final Color color;
  final int numLines;

  CaptureEffectPainter({
    required this.progress,
    required this.color,
    this.numLines = 16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxLength = size.width;
    
    for (int i = 0; i < numLines; i++) {
      final angle = 2 * math.pi * i / numLines;
      
      // Calculate line length based on progress
      double lineLength = 0;
      if (progress < 0.5) {
        // Lines grow
        lineLength = maxLength * progress * 2;
      } else {
        // Lines shrink
        lineLength = maxLength * (1 - (progress - 0.5) * 2);
      }
      
      final paint = Paint()
        ..color = color.withOpacity(1 - progress)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      
      final start = Offset(
        center.dx + lineLength * 0.2 * math.cos(angle),
        center.dy + lineLength * 0.2 * math.sin(angle),
      );
      
      final end = Offset(
        center.dx + lineLength * math.cos(angle),
        center.dy + lineLength * math.sin(angle),
      );
      
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(CaptureEffectPainter oldDelegate) => 
      progress != oldDelegate.progress || 
      color != oldDelegate.color || 
      numLines != oldDelegate.numLines;
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity(
          particle.lifespan / particle.initialLifespan * 0.7)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(particle.position, particle.size, paint);
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}

// Particle class for effects
class Particle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  int lifespan;
  final int initialLifespan;
  
  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.lifespan,
  }) : initialLifespan = lifespan;
  
  void update() {
    position += velocity;
    lifespan--;
    
    // Slow down particles gradually
    velocity *= 0.98;
  }
  
  bool isDead() => lifespan <= 0;
}