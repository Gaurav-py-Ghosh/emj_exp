import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/emoji_model.dart';

class StorageService {
  static const _inventoryBoxName = 'inventory';
   static String get inventoryBoxName => _inventoryBoxName;

  static Future<void> init() async {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);
    Hive.registerAdapter(EmojiInventoryItemAdapter());
    await Hive.openBox<EmojiInventoryItem>(_inventoryBoxName);
  }

  static Future<void> saveInventory(List<EmojiInventoryItem> inventory) async {
    final box = Hive.box<EmojiInventoryItem>(_inventoryBoxName);
    await box.clear();
    await box.addAll(inventory);
  }

  static List<EmojiInventoryItem> loadInventory() {
    final box = Hive.box<EmojiInventoryItem>(_inventoryBoxName);
    return box.values.toList();
  }
}