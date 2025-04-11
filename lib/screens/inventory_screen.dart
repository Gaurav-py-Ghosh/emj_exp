import 'package:flutter/material.dart';
import '../widgets/emoji_model.dart';

class InventoryScreen extends StatelessWidget {
  final List<EmojiInventoryItem> inventory;

  const InventoryScreen({super.key, required this.inventory});

  @override
  Widget build(BuildContext context) {
    final totalPoints = inventory.fold(0, (sum, item) => sum + item.points);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emoji Inventory'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Total Points: $totalPoints',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: inventory.length,
              itemBuilder: (context, index) {
                final item = inventory[index];
                return ListTile(
                  leading: Text(item.emoji, style: const TextStyle(fontSize: 30)),
                  title: Text('${item.points} points'),
                  subtitle: Text('Caught: ${item.caughtTime.toString()}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}