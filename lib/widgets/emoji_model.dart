import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive/hive.dart';

// part 'emoji_model.g.dart';

@HiveType(typeId: 0)
class EmojiInventoryItem {
  @HiveField(0)
  final String emoji;
  @HiveField(1)
  final int points;
  @HiveField(2)
  final int tier;
  @HiveField(3)
  final DateTime caughtTime;
  @HiveField(4)
  final double? lat;
  @HiveField(5)
  final double? lng;

  EmojiInventoryItem({
    required this.emoji,
    required this.points,
    required this.tier,
    required this.caughtTime,
    LatLng? caughtLocation,
  }) : 
    lat = caughtLocation?.latitude,
    lng = caughtLocation?.longitude;

  LatLng? get caughtLocation => 
    (lat != null && lng != null) ? LatLng(lat!, lng!) : null;
}

class EmojiInventoryItemAdapter extends TypeAdapter<EmojiInventoryItem> {
  @override
  final int typeId = 0;

  @override
  EmojiInventoryItem read(BinaryReader reader) {
    return EmojiInventoryItem(
      emoji: reader.readString(),
      points: reader.readInt(),
      tier: reader.readInt(),
      caughtTime: reader.read() as DateTime,
      caughtLocation: reader.readBool()
          ? LatLng(reader.readDouble(), reader.readDouble())
          : null,
    );
  }

  @override
  void write(BinaryWriter writer, EmojiInventoryItem obj) {
    writer.writeString(obj.emoji);
    writer.writeInt(obj.points);
    writer.writeInt(obj.tier);
    writer.write(obj.caughtTime);
    if (obj.caughtLocation != null) {
      writer.writeBool(true);
      writer.writeDouble(obj.caughtLocation!.latitude);
      writer.writeDouble(obj.caughtLocation!.longitude);
    } else {
      writer.writeBool(false);
    }
  }
}

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

class Hotspot {
  final LatLng location;
  final int guaranteedTier;
  final String name;
  final double radius;

  const Hotspot({
    required this.location,
    required this.guaranteedTier,
    required this.name,
    this.radius = 150.0,
  });
}

const List<EmojiTier> emojiTiers = [
  EmojiTier(emoji: '😀', points: 1, tier: 1, hasSpecialAnimation: false, spawnChance: 0.6),
  EmojiTier(emoji: '😎', points: 1, tier: 1, hasSpecialAnimation: false, spawnChance: 0.25),
  EmojiTier(emoji: '🤔', points: 1, tier: 1, hasSpecialAnimation: false, spawnChance: 0.1),
  EmojiTier(emoji: '🌟', points: 3, tier: 2, hasSpecialAnimation: true, spawnChance: 0.03),
  EmojiTier(emoji: '✨', points: 3, tier: 2, hasSpecialAnimation: true, spawnChance: 0.015),
  EmojiTier(emoji: '🎯', points: 5, tier: 3, hasSpecialAnimation: true, spawnChance: 0.005),
  EmojiTier(emoji: '👑', points: 5, tier: 3, hasSpecialAnimation: true, spawnChance: 0.005),
];

const List<Hotspot> hotspots = [
  Hotspot(
    location: LatLng(37.7749, -122.4194),
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