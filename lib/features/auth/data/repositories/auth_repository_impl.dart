import 'package:dartz/dartz.dart';
import 'package:business_automation/core/error/failures.dart';
import 'package:business_automation/core/utils/isar_service.dart';
import 'package:business_automation/features/auth/data/models/business_profile_model.dart';
import 'package:business_automation/features/auth/domain/repositories/auth_repository.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthRepositoryImpl implements AuthRepository {
  final IsarService isarService;
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  static const String _pinKey = 'user_pin';
  static const String _onboardingKey = 'onboarding_completed';

  AuthRepositoryImpl(this.isarService);

  @override
  Future<Either<Failure, BusinessProfile?>> getProfile() async {
    try {
      final profile = await isarService.isar.businessProfiles.where().findFirst();
      return Right(profile);
    } catch (e) {
      return Left(DatabaseFailure());
    }
  }

  @override
  Future<Either<Failure, void>> saveProfile(BusinessProfile profile) async {
    try {
      await isarService.isar.writeTxn(() async {
        await isarService.isar.businessProfiles.put(profile);
      });
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure());
    }
  }

  @override
  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  @override
  Future<void> setOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }

  @override
  Future<bool> isPinSet() async {
    final pin = await secureStorage.read(key: _pinKey);
    return pin != null && pin.isNotEmpty;
  }

  @override
  Future<void> savePin(String pin) async {
    await secureStorage.write(key: _pinKey, value: pin);
  }

  @override
  Future<bool> verifyPin(String pin) async {
    final storedPin = await secureStorage.read(key: _pinKey);
    return storedPin == pin;
  }

  @override
  Future<void> deletePin() async {
    await secureStorage.delete(key: _pinKey);
  }
}
