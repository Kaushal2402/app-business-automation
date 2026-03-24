import 'package:isar/isar.dart';

part 'business_profile_model.g.dart';

@collection
class BusinessProfile {
  Id id = Isar.autoIncrement;

  late String name;
  String? industry;
  String? logoPath;
  String? taxId;
  String? phone;
  String? address;

  DateTime? createdAt;
}
