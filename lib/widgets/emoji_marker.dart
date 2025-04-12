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
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(
          fontSize: size.toDouble(),
          color: Colors.black.withOpacity(opacity),
          shadows: tier >= 3 ? [
            Shadow(
              blurRadius: 10.0,
              color: Colors.yellow,
              offset: Offset(0, 0),)
          ] : null,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Add pulsing effect for rare emojis
    if (tier >= 2) {
      final pulseValue = (math.sin(DateTime.now().millisecond / 1000 * 2 * math.pi)).abs();
      final pulseColor = tier == 3 
          ? Colors.yellow.withOpacity(0.3 * pulseValue * opacity)
          : Colors.white.withOpacity(0.3 * opacity);
      
      final paint = Paint()
        ..color = pulseColor
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(size / 2, size / 2),
        size / 2,
        paint,
      );
    }
    
    textPainter.paint(canvas, Offset.zero);
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
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