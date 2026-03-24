import 'package:isar/isar.dart';

part 'lead_model.g.dart';

@collection
class Lead {
  Id id = Isar.autoIncrement;

  late String name;
  String? phone;
  String? email;
  
  @Enumerated(EnumType.name)
  late LeadStatus status;
  
  double? estimatedValue;
  String? notes;
  
  DateTime createdAt = DateTime.now();
  
  DateTime? nextFollowUp;
  String? lastMessageSent;
}

enum LeadStatus {
  newLead,
  contacted,
  proposal,
  won,
  lost
}
