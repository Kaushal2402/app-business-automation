import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../data/models/business_profile_model.dart';

abstract class AuthRepository {
  Future<Either<Failure, BusinessProfile?>> getProfile();
  Future<Either<Failure, void>> saveProfile(BusinessProfile profile);
  
  // New navigation & security methods
  Future<bool> isOnboardingCompleted();
  Future<void> setOnboardingCompleted();
  Future<bool> isPinSet();
  Future<void> savePin(String pin);
  Future<bool> verifyPin(String pin);
  Future<void> deletePin();
}
