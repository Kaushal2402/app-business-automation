import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/invoice_model.dart';
import '../../domain/repositories/invoice_repository.dart';

abstract class InvoiceState {}
class InvoiceInitial extends InvoiceState {}
class InvoiceLoading extends InvoiceState {}
class InvoiceLoaded extends InvoiceState {
  final List<Invoice> invoices;
  final List<Invoice> filteredInvoices;
  final String searchQuery;

  InvoiceLoaded(this.invoices, {this.filteredInvoices = const [], this.searchQuery = ''});
}
class InvoiceError extends InvoiceState {
  final String message;
  InvoiceError(this.message);
}

class InvoiceCubit extends Cubit<InvoiceState> {
  final InvoiceRepository repository;

  InvoiceCubit(this.repository) : super(InvoiceInitial());

  Future<void> loadInvoices({bool silent = false}) async {
    if (!silent) emit(InvoiceLoading());
    try {
      final invoices = await repository.getInvoices();
      final query = state is InvoiceLoaded ? (state as InvoiceLoaded).searchQuery : '';
      
      if (query.isEmpty) {
        emit(InvoiceLoaded(invoices, filteredInvoices: invoices, searchQuery: ''));
      } else {
        final filtered = _filterInvoices(invoices, query);
        emit(InvoiceLoaded(invoices, filteredInvoices: filtered, searchQuery: query));
      }
    } catch (e) {
      emit(InvoiceError('Failed to load invoices'));
    }
  }

  List<Invoice> _filterInvoices(List<Invoice> invoices, String query) {
    return invoices.where((invoice) {
      final nameMatch = invoice.customerName.toLowerCase().contains(query.toLowerCase());
      final numberMatch = invoice.invoiceNumber.toLowerCase().contains(query.toLowerCase());
      return nameMatch || numberMatch;
    }).toList();
  }

  void searchInvoices(String query) {
    if (state is InvoiceLoaded) {
      final allInvoices = (state as InvoiceLoaded).invoices;
      if (query.isEmpty) {
        emit(InvoiceLoaded(allInvoices, filteredInvoices: allInvoices, searchQuery: ''));
      } else {
        final filtered = _filterInvoices(allInvoices, query);
        emit(InvoiceLoaded(allInvoices, filteredInvoices: filtered, searchQuery: query));
      }
    }
  }

  Future<void> addInvoice(Invoice invoice) async {
    try {
      await repository.saveInvoice(invoice);
      await loadInvoices(silent: true);
    } catch (e) {
      emit(InvoiceError('Failed to save invoice'));
    }
  }

  Future<void> updateInvoice(Invoice invoice) async {
    try {
      await repository.saveInvoice(invoice);
      await loadInvoices(silent: true);
    } catch (e) {
      emit(InvoiceError('Failed to update invoice'));
    }
  }

  Future<void> deleteInvoice(int id) async {
    try {
      await repository.deleteInvoice(id);
      await loadInvoices(silent: true);
    } catch (e) {
      emit(InvoiceError('Failed to delete invoice'));
    }
  }

  Future<String> getNextInvoiceNumber() async {
    return await repository.generateInvoiceNumber();
  }
}
