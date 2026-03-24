import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class LocalFailure extends Failure {
  const LocalFailure(super.message);
}

class DatabaseFailure extends Failure {
  const DatabaseFailure([super.message = 'Database Error']);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}
