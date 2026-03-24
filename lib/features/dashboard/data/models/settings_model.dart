import 'package:isar/isar.dart';

part 'settings_model.g.dart';

@collection
class SettingsModel {
  Id id = 0; // Singleton settings

  @Enumerated(EnumType.name)
  ThemeModePreference themeMode = ThemeModePreference.light;

  String currencyCode = 'INR';
  String currencySymbol = '₹';
  double defaultTaxRate = 18.0;
  String languageCode = 'en';
  bool biometricsEnabled = true;

  // Business Profile Details
  String businessName = '';
  String businessEmail = '';
  String businessPhone = '';
  String businessAddress = '';
  String businessTaxNumber = '';
  String businessLogoPath = '';

  SettingsModel({
    this.themeMode = ThemeModePreference.light,
    this.currencyCode = 'INR',
    this.currencySymbol = '₹',
    this.defaultTaxRate = 18.0,
    this.languageCode = 'en',
    this.biometricsEnabled = true,
    this.businessName = '',
    this.businessEmail = '',
    this.businessPhone = '',
    this.businessAddress = '',
    this.businessTaxNumber = '',
    this.businessLogoPath = '',
  });
}

enum ThemeModePreference { light, dark, system }
