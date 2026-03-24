import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:business_automation/features/crm/data/models/lead_model.dart';
import 'package:business_automation/features/crm/data/repositories/lead_repository.dart';

abstract class LeadState {}
class LeadInitial extends LeadState {}
class LeadLoading extends LeadState {}
class LeadLoaded extends LeadState {
  final List<Lead> allLeads;
  final List<Lead> filteredLeads;
  final String searchQuery;
  
  LeadLoaded(this.allLeads, {this.filteredLeads = const [], this.searchQuery = ''});
}
class LeadError extends LeadState {
  final String message;
  LeadError(this.message);
}

class LeadCubit extends Cubit<LeadState> {
  final LeadRepository repository;

  LeadCubit(this.repository) : super(LeadInitial());

  Future<void> loadLeads({bool silent = false}) async {
    if (!silent) emit(LeadLoading());
    try {
      final leads = await repository.getLeads();
      final query = state is LeadLoaded ? (state as LeadLoaded).searchQuery : '';
      
      if (query.isEmpty) {
        emit(LeadLoaded(leads, filteredLeads: leads, searchQuery: ''));
      } else {
        final filtered = _filterLeads(leads, query);
        emit(LeadLoaded(leads, filteredLeads: filtered, searchQuery: query));
      }
    } catch (e) {
      emit(LeadError('Failed to load leads'));
    }
  }

  List<Lead> _filterLeads(List<Lead> leads, String query) {
    return leads.where((lead) {
      final nameMatch = lead.name.toLowerCase().contains(query.toLowerCase());
      final phoneMatch = lead.phone?.contains(query) ?? false;
      return nameMatch || phoneMatch;
    }).toList();
  }

  void searchLeads(String query) {
    if (state is LeadLoaded) {
      final allLeads = (state as LeadLoaded).allLeads;
      if (query.isEmpty) {
        emit(LeadLoaded(allLeads, filteredLeads: allLeads, searchQuery: ''));
      } else {
        final filtered = _filterLeads(allLeads, query);
        emit(LeadLoaded(allLeads, filteredLeads: filtered, searchQuery: query));
      }
    }
  }

  Future<void> addLead(Lead lead) async {
    try {
      await repository.saveLead(lead);
      await loadLeads(silent: true);
    } catch (e) {
      emit(LeadError('Failed to save lead'));
    }
  }

  Future<void> updateLead(Lead lead) async {
    try {
      await repository.saveLead(lead);
      await loadLeads(silent: true);
    } catch (e) {
      emit(LeadError('Failed to update lead'));
    }
  }

  Future<void> updateLeadStatus(Lead lead, LeadStatus newStatus) async {
    lead.status = newStatus;
    await updateLead(lead);
  }

  Future<void> deleteLead(int id) async {
    try {
      await repository.deleteLead(id);
      await loadLeads(silent: true);
    } catch (e) {
      emit(LeadError('Failed to delete lead'));
    }
  }
}
