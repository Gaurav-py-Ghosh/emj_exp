import 'package:google_maps_flutter/google_maps_flutter.dart';

class EmojiTier {
  final String emoji;
  final int points;
  final int tier;
  final bool hasSpecialAnimation;

  const EmojiTier({
    required this.emoji,
    required this.points,
    required this.tier,
    required this.hasSpecialAnimation,
  });
}

class EmojiInventoryItem {
  final String emoji;
  final int points;
  final DateTime caughtTime;

  EmojiInventoryItem({
    required this.emoji,
    required this.points,
    required this.caughtTime,
  });
}

const List<EmojiTier> emojiTiers = [
  EmojiTier(emoji: '😀', points: 1, tier: 1, hasSpecialAnimation: false),
  EmojiTier(emoji: '😎', points: 1, tier: 1, hasSpecialAnimation: false),
  EmojiTier(emoji: '🤔', points: 1, tier: 1, hasSpecialAnimation: false),
  EmojiTier(emoji: '🌟', points: 3, tier: 2, hasSpecialAnimation: true),
  EmojiTier(emoji: '✨', points: 3, tier: 2, hasSpecialAnimation: true),
  EmojiTier(emoji: '🎯', points: 5, tier: 3, hasSpecialAnimation: true),
  EmojiTier(emoji: '👑', points: 5, tier: 3, hasSpecialAnimation: true),
];

class Hotspot {
  final LatLng location;
  final int guaranteedTier;

  Hotspot({required this.location, required this.guaranteedTier});
}