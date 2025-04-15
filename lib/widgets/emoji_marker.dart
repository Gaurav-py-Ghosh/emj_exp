// emoji_marker.dart (updated)
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart'; // Add this import for rootBundle
import 'emoji_model.dart';

class EmojiMarker {
  static Future<BitmapDescriptor> _getEmojiBitmap(
    String emoji, 
    int size, 
    int tier,
    DateTime spawnTime,
  ) async {
    // Increase canvas size for effects
    final canvasSize = size * 2.0;  // Increased from 1.5 to 2.0 for more effect space
    
    if (emoji == 'redbull') {
      try {
        // Load RedBull image with error handling
        final ByteData imageData = await rootBundle.load('assets/redmoji.png');
        final ui.Codec codec = await ui.instantiateImageCodec(
          imageData.buffer.asUint8List(),
          targetWidth: size,
          targetHeight: size,
        );
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        
        // Create canvas for effects
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        
        // Draw special effects for RedBull
        _drawRedBullEffects(canvas, canvasSize, size);
        
        // Draw the RedBull image
        canvas.drawImage(
          frameInfo.image,
          Offset((canvasSize - size) / 2, (canvasSize - size) / 2),
          Paint(),
        );
        
        final picture = recorder.endRecording();
        final image = await picture.toImage(canvasSize.toInt(), canvasSize.toInt());
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        
        return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
      } catch (e) {
        debugPrint('Error loading RedBull image: $e');
        // Fallback to default marker if image fails to load
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      }
    }

    // Regular emoji processing
    final remainingLife = spawnTime.difference(DateTime.now()).inMinutes;
    final opacity = remainingLife < 1 ? 0.8 + 0.2 * (remainingLife / 1) : 1.0;
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(
          fontSize: size.toDouble(),
          color: Colors.white.withOpacity(opacity),
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.5),
              offset: const Offset(2, 2),
              blurRadius: 0,
            ),
            Shadow(
              color: EmojiTier.getTierColor(tier).withOpacity(0.8),
              offset: const Offset(0, 0),
              blurRadius: 8,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    final offset = Offset(
      (canvasSize - textPainter.width) / 2,
      (canvasSize - textPainter.height) / 2,
    );
    
    // Draw tier-based effects
    if (tier >= 2) {
      _drawTierEffects(canvas, canvasSize, size, tier);
    }
    
    // Draw the emoji
    textPainter.paint(canvas, offset);
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(canvasSize.toInt(), canvasSize.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  // New method for RedBull specific effects
  static void _drawRedBullEffects(Canvas canvas, double canvasSize, int size) {
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    final pulseValue = (math.sin(now * 4 * math.pi)).abs();
    
    // Energy aura
    final aura = Paint()
      ..color = Colors.red.withOpacity(0.3 * pulseValue)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 15);
    
    canvas.drawCircle(
      Offset(canvasSize / 2, canvasSize / 2),
      size * 0.9,
      aura,
    );

    // Wing effects
    _drawWings(canvas, canvasSize, size);
  }

  // New method for wing effects
  static void _drawWings(Canvas canvas, double canvasSize, int size) {
    final wingPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    for (var i = 0; i < 2; i++) {
      final wingPath = Path();
      final angle = math.pi / 4 + (i * math.pi / 2);
      final wingLength = size * 1.2;
      
      wingPath.moveTo(canvasSize / 2, canvasSize / 2);
      wingPath.quadraticBezierTo(
        canvasSize / 2 + math.cos(angle) * wingLength * 0.6,
        canvasSize / 2 + math.sin(angle) * wingLength * 0.6,
        canvasSize / 2 + math.cos(angle) * wingLength,
        canvasSize / 2 + math.sin(angle) * wingLength,
      );
      
      canvas.drawPath(wingPath, wingPaint);
    }
  }

  // New method for tier-based effects
  static void _drawTierEffects(Canvas canvas, double canvasSize, int size, int tier) {
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    final pulseValue = (math.sin(now * 2 * math.pi)).abs();
    
    final outerGlow = Paint()
      ..color = EmojiTier.getTierColor(tier).withOpacity(0.2 * pulseValue)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8);
    
    canvas.drawCircle(
      Offset(canvasSize / 2, canvasSize / 2),
      size * 0.8,
      outerGlow,
    );
  }

  // Helper method to get tier colors
  static Color _getTierColor(int tier) {
    switch (tier) {
      case 1: 
        return Colors.cyan;
      case 2: 
        return Colors.purple;
      case 3: 
        return Colors.orange.shade400;
      default: 
        return Colors.blue;
    }
  }

  static Future<Marker> createMarker({
    required LatLng position,
    required String id,
    required String emoji,
    required int size,
    required int tier,
    required DateTime spawnTime,
    required VoidCallback onTap,
  }) async {
    final icon = await _getEmojiBitmap(emoji, size, tier, spawnTime);
    
    return Marker(
      markerId: MarkerId(id),
      position: position,
      icon: icon,
      anchor: const Offset(0.5, 0.5),
      onTap: onTap,
      zIndex: tier.toDouble(),
      consumeTapEvents: true,
    );
  }
}