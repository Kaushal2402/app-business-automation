import 'package:isar/isar.dart';
import '../models/settings_model.dart';

class SettingsRepository {
  final Isar isar;

  SettingsRepository(this.isar);

  Future<SettingsModel> getSettings() async {
    final settings = await isar.settingsModels.get(0);
    if (settings == null) {
      final defaultSettings = SettingsModel();
      await isar.writeTxn(() => isar.settingsModels.put(defaultSettings));
      return defaultSettings;
    }
    return settings;
  }

  Future<void> saveSettings(SettingsModel settings) async {
    await isar.writeTxn(() => isar.settingsModels.put(settings));
  }
}
