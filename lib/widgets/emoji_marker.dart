// emoji_marker.dart (updated)
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'emoji_model.dart';

class EmojiMarker {
  static Future<BitmapDescriptor> _getEmojiBitmap(
    String emoji, 
    int size, 
    int tier,
    DateTime spawnTime,
  ) async {
    final remainingLife = spawnTime.difference(DateTime.now()).inMinutes;
    final opacity = remainingLife < 1 ? 0.8 + 0.2 * (remainingLife / 1) : 1.0;
    
    // Increase canvas size to accommodate effects
    final canvasSize = size * 1.5;
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(
          fontSize: size.toDouble(),
          color: Colors.white.withOpacity(opacity),
          shadows: [
            // 3D effect shadows
            Shadow(
              color: Colors.black.withOpacity(0.5),
              offset: const Offset(2, 2),
              blurRadius: 0,
            ),
            // Glow effect based on tier
            Shadow(
              color: _getTierColor(tier).withOpacity(0.8),
              offset: const Offset(0, 0),
              blurRadius: 8,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Center the emoji in the larger canvas
    final offset = Offset(
      (canvasSize - textPainter.width) / 2,
      (canvasSize - textPainter.height) / 2
    );
    
    // Add holographic effect for higher tiers
    if (tier >= 2) {
      final now = DateTime.now().millisecondsSinceEpoch / 1000;
      final pulseValue = (math.sin(now * 2 * math.pi)).abs();
      
      // Outer glow
      final outerGlow = Paint()
        ..color = _getTierColor(tier).withOpacity(0.2 * pulseValue)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8);
      
      canvas.drawCircle(
        Offset(canvasSize / 2, canvasSize / 2),
        size / 1.8,
        outerGlow,
      );
      
      // Holographic rings
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
      
      for (var i = 0; i < 3; i++) {
        final ringPhase = (now + i * 0.3) % 1.0;
        final ringRadius = size * (0.4 + ringPhase * 0.3);
        ringPaint.color = _getTierColor(tier).withOpacity((1 - ringPhase) * 0.3);
        
        canvas.drawCircle(
          Offset(canvasSize / 2, canvasSize / 2),
          ringRadius,
          ringPaint,
        );
      }
    }
    
    // Draw the emoji
    textPainter.paint(canvas, offset);
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(canvasSize.toInt(), canvasSize.toInt());
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
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