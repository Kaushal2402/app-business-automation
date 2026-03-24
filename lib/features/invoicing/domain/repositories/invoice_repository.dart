import '../../data/models/invoice_model.dart';

abstract class InvoiceRepository {
  Future<List<Invoice>> getInvoices();
  Future<Invoice?> getInvoiceById(int id);
  Future<void> saveInvoice(Invoice invoice);
  Future<void> deleteInvoice(int id);
  Future<String> generateInvoiceNumber();
}
