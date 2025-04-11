// emoji_model.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';

class EmojiTier {
  final String emoji;
  final int points;
  final int tier;
  final bool hasSpecialAnimation;
  final double spawnChance;

  const EmojiTier({
    required this.emoji,
    required this.points,
    required this.tier,
    required this.hasSpecialAnimation,
    required this.spawnChance,
  });
}

class EmojiInventoryItem {
  final String emoji;
  final int points;
  final int tier;
  final DateTime caughtTime;
  final LatLng? caughtLocation;

  EmojiInventoryItem({
    required this.emoji,
    required this.points,
    required this.tier,
    required this.caughtTime,
    this.caughtLocation,
  });
}

class Hotspot {
  final LatLng location;
  final int guaranteedTier;
  final String name;
  final double radius;

  const Hotspot({
    required this.location,
    required this.guaranteedTier,
    required this.name,
    this.radius = 150.0, // meters
  });
}

const List<EmojiTier> emojiTiers = [
  EmojiTier(emoji: '😀', points: 1, tier: 1, hasSpecialAnimation: false, spawnChance: 0.6),
  EmojiTier(emoji: '😎', points: 1, tier: 1, hasSpecialAnimation: false, spawnChance: 0.25),
  EmojiTier(emoji: '🤔', points: 1, tier: 1, hasSpecialAnimation: false, spawnChance: 0.15),
  EmojiTier(emoji: '🌟', points: 3, tier: 2, hasSpecialAnimation: true, spawnChance: 0.7),
  EmojiTier(emoji: '✨', points: 3, tier: 2, hasSpecialAnimation: true, spawnChance: 0.3),
  EmojiTier(emoji: '🎯', points: 5, tier: 3, hasSpecialAnimation: true, spawnChance: 0.8),
  EmojiTier(emoji: '👑', points: 5, tier: 3, hasSpecialAnimation: true, spawnChance: 0.2),
];

const List<Hotspot> hotspots = [
  Hotspot(
    location: LatLng(37.7749, -122.4194), // SF coordinates
    guaranteedTier: 3,
    name: "City Center",
    radius: 200.0,
  ),
  Hotspot(
    location: LatLng(37.7813, -122.4167),
    guaranteedTier: 2,
    name: "Park Area",
    radius: 150.0,
  ),
];