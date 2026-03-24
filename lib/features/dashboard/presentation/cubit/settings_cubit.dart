import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/settings_model.dart';
import '../../data/repositories/settings_repository.dart';

abstract class SettingsState {}
class SettingsInitial extends SettingsState {}
class SettingsLoading extends SettingsState {}
class SettingsLoaded extends SettingsState {
  final SettingsModel settings;
  SettingsLoaded(this.settings);
}

class SettingsCubit extends Cubit<SettingsState> {
  final SettingsRepository repository;

  SettingsCubit(this.repository) : super(SettingsInitial());

  Future<void> loadSettings() async {
    emit(SettingsLoading());
    final settings = await repository.getSettings();
    emit(SettingsLoaded(settings));
  }

  Future<void> updateTheme(ThemeModePreference mode) async {
    if (state is SettingsLoaded) {
      final current = (state as SettingsLoaded).settings;
      current.themeMode = mode;
      await repository.saveSettings(current);
      emit(SettingsLoaded(current));
    }
  }

  Future<void> updateCurrency(String code, String symbol) async {
    if (state is SettingsLoaded) {
      final current = (state as SettingsLoaded).settings;
      current.currencyCode = code;
      current.currencySymbol = symbol;
      await repository.saveSettings(current);
      emit(SettingsLoaded(current));
    }
  }

  Future<void> updateTaxRate(double rate) async {
    if (state is SettingsLoaded) {
      final current = (state as SettingsLoaded).settings;
      current.defaultTaxRate = rate;
      await repository.saveSettings(current);
      emit(SettingsLoaded(current));
    }
  }

  Future<void> updateLanguage(String code) async {
    if (state is SettingsLoaded) {
      final current = (state as SettingsLoaded).settings;
      current.languageCode = code;
      await repository.saveSettings(current);
      emit(SettingsLoaded(current));
    }
  }

  Future<void> updateBiometrics(bool enabled) async {
    if (state is SettingsLoaded) {
      final current = (state as SettingsLoaded).settings;
      current.biometricsEnabled = enabled;
      await repository.saveSettings(current);
      emit(SettingsLoaded(current));
    }
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? address,
    String? taxNumber,
    String? logoPath,
  }) async {
    if (state is SettingsLoaded) {
      final current = (state as SettingsLoaded).settings;
      if (name != null) current.businessName = name;
      if (email != null) current.businessEmail = email;
      if (phone != null) current.businessPhone = phone;
      if (address != null) current.businessAddress = address;
      if (taxNumber != null) current.businessTaxNumber = taxNumber;
      if (logoPath != null) current.businessLogoPath = logoPath;
      
      await repository.saveSettings(current);
      emit(SettingsLoaded(current));
    }
  }
}
