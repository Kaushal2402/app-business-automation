import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:business_automation/features/auth/data/models/business_profile_model.dart';
import 'package:business_automation/features/auth/domain/usecases/save_business_profile.dart';

abstract class ProfileState {}
class ProfileInitial extends ProfileState {}
class ProfileLoading extends ProfileState {}
class ProfileSaved extends ProfileState {}
class ProfileError extends ProfileState {
  final String message;
  ProfileError(this.message);
}

class ProfileCubit extends Cubit<ProfileState> {
  final SaveBusinessProfile saveBusinessProfile;

  ProfileCubit({required this.saveBusinessProfile}) : super(ProfileInitial());

  Future<void> saveProfile(BusinessProfile profile) async {
    emit(ProfileLoading());
    final result = await saveBusinessProfile(profile);
    result.fold(
      (failure) => emit(ProfileError('Failed to save profile')),
      (_) => emit(ProfileSaved()),
    );
  }
}
