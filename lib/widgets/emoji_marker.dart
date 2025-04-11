import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class EmojiMarker {
  static Future<BitmapDescriptor> _getEmojiBitmap(String emoji, int size) async {
    final textPainter = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(
          fontSize: size.toDouble(),
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
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
    required VoidCallback onTap,
  }) async {
    final icon = await _getEmojiBitmap(emoji, size);
    
    return Marker(
      markerId: MarkerId(id),
      position: position,
      icon: icon,
      anchor: const Offset(0.5, 0.5),
      onTap: onTap,
    );
  }
}