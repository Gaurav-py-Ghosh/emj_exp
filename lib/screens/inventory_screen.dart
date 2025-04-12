// inventory_screen.dart
import 'package:emoji_exp/widgets/emoji_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
// import 'emoji_model.dart';

class InventoryScreen extends StatelessWidget {
  final List<EmojiInventoryItem> inventory;

  const InventoryScreen({super.key, required this.inventory});

  @override
  Widget build(BuildContext context) {
    final totalPoints = inventory.fold(0, (sum, item) => sum + item.points);
    final byTier = {
      1: inventory.where((item) => item.tier == 1).toList(),
      2: inventory.where((item) => item.tier == 2).toList(),
      3: inventory.where((item) => item.tier == 3).toList(),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emoji Collection'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Total Points'),
                        Text(
                          '$totalPoints',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Total Caught'),
                        Text(
                          '${inventory.length}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Tier 1'),
                      Tab(text: 'Tier 2'),
                      Tab(text: 'Tier 3'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildTierList(byTier[1] ?? []),
                        _buildTierList(byTier[2] ?? []),
                        _buildTierList(byTier[3] ?? []),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierList(List<EmojiInventoryItem> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text('No emojis caught yet'),
      );
    }

    return ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    final item = items[index];
    final formattedTime = DateFormat.Hms().format(item.caughtTime);

    return FutureBuilder<List<Placemark>>(
      future: item.caughtLocation != null
          ? placemarkFromCoordinates(
              item.caughtLocation!.latitude,
              item.caughtLocation!.longitude,
            )
          : Future.value([]),
      builder: (context, snapshot) {
        String locationText = 'Location: Unknown';
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final place = snapshot.data!.first;
          locationText =
              'Location: ${place.locality ?? ''}, ${place.country ?? ''}';
        }

        return ListTile(
          leading: Text(item.emoji, style: const TextStyle(fontSize: 30)),
          title: Text('${item.points} points'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Caught: ${item.caughtTime.toString().split(' ')[0]} $formattedTime'),
              if (item.caughtLocation != null)
                Text(locationText, style: const TextStyle(fontSize: 12)),
            ],
          ),
          trailing: Chip(
            label: Text('Tier ${item.tier}'),
            backgroundColor: _getTierColor(item.tier),
          ),
        );
      },
    );
  },
);

  }

  Color _getTierColor(int tier) {
    switch (tier) {
      case 1: return Colors.blue;
      case 2: return Colors.purple;
      case 3: return Colors.orange;
      default: return Colors.grey;
    }
  }
}