// lib/widgets/emoji_interaction_handler.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';

class EmojiInteractionHandler {
  final Function(LatLng) onEmojiTapped;
  final Function(String, LatLng) onEmojiLongPressed;

  EmojiInteractionHandler({
    required this.onEmojiTapped,
    required this.onEmojiLongPressed,
  });

  void handleTap(String emojiId, LatLng position) {
    onEmojiTapped(position);
  }

  void handleLongPress(String emojiId, LatLng position) {
    onEmojiLongPressed(emojiId, position);
  }
}