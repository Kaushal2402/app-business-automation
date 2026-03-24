import 'package:isar/isar.dart';
import 'package:business_automation/core/utils/isar_service.dart';
import 'package:business_automation/features/crm/data/models/lead_model.dart';

abstract class LeadRepository {
  Future<List<Lead>> getLeads();
  Future<void> saveLead(Lead lead);
  Future<void> deleteLead(int id);
}

class LeadRepositoryImpl implements LeadRepository {
  final IsarService isarService;

  LeadRepositoryImpl(this.isarService);

  @override
  Future<List<Lead>> getLeads() async {
    // Re-check schema if needed, but leads should be sorted by creation
    return await isarService.isar.leads.where().sortByCreatedAtDesc().findAll();
  }

  @override
  Future<void> saveLead(Lead lead) async {
    await isarService.isar.writeTxn(() async {
      await isarService.isar.leads.put(lead);
    });
  }

  @override
  Future<void> deleteLead(int id) async {
    await isarService.isar.writeTxn(() async {
      await isarService.isar.leads.delete(id);
    });
  }
}
