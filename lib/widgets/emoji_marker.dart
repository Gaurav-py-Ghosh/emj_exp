// lib/widgets/emoji_marker.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class EmojiMarker {
  static Future<BitmapDescriptor> _getEmojiBitmap(String emoji, int size) async {
    final textStyle = TextStyle(
      fontSize: size.toDouble(),
      color: Colors.black,
    );

    final textSpan = TextSpan(
      text: emoji,
      style: textStyle,
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    // Add padding for shadow
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final width = textPainter.width + 4;
    final height = textPainter.height + 4;

    // Draw shadow first
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    
    textPainter.paint(canvas, const Offset(2, 2));

    // Draw main emoji
    textPainter.paint(canvas, Offset.zero);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  static Future<Marker> createMarker({
    required LatLng position,
    required String id,
    required String emoji,
    required int size,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) async {
    final icon = await _getEmojiBitmap(emoji, size);
    
    return Marker(
      markerId: MarkerId(id),
      position: position,
      icon: icon,
      anchor: const Offset(0.5, 0.5),
      onTap: onTap, // Ensure this is set
      consumeTapEvents: true, // Allow tap events to be consumed
    );
  }
}