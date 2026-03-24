import 'package:dartz/dartz.dart';
import 'package:business_automation/core/error/failures.dart';
import 'package:business_automation/core/usecases/usecase.dart';
import 'package:business_automation/features/auth/data/models/business_profile_model.dart';
import 'package:business_automation/features/auth/domain/repositories/auth_repository.dart';

class SaveBusinessProfile implements UseCase<void, BusinessProfile> {
  final AuthRepository repository;

  SaveBusinessProfile(this.repository);

  @override
  Future<Either<Failure, void>> call(BusinessProfile params) async {
    return await repository.saveProfile(params);
  }
}
