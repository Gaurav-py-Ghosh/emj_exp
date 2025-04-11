// emoji_marker.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'emoji_model.dart';

class EmojiMarker {
  static Future<BitmapDescriptor> _getEmojiBitmap(String emoji, int size, int tier) async {
    final textPainter = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(
          fontSize: size.toDouble(),
          color: Colors.black,
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
    
    // Add background circle for better visibility
    if (tier >= 2) {
      final paint = Paint()
        ..color = tier == 3 ? Colors.yellow.withOpacity(0.3) : Colors.white.withOpacity(0.3)
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
    required VoidCallback onTap,
  }) async {
    final icon = await _getEmojiBitmap(emoji, size, tier);
    
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