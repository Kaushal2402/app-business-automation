import 'package:isar/isar.dart';
import '../../../../core/utils/isar_service.dart';
import '../../domain/repositories/invoice_repository.dart';
import '../models/invoice_model.dart';

class InvoiceRepositoryImpl implements InvoiceRepository {
  final IsarService isarService;

  InvoiceRepositoryImpl(this.isarService);

  @override
  Future<List<Invoice>> getInvoices() async {
    return await isarService.isar.invoices.where().sortByDateDesc().findAll();
  }

  @override
  Future<Invoice?> getInvoiceById(int id) async {
    return await isarService.isar.invoices.get(id);
  }

  @override
  Future<void> saveInvoice(Invoice invoice) async {
    await isarService.isar.writeTxn(() async {
      invoice.updatedAt = DateTime.now();
      if (invoice.createdAt == null) {
        invoice.createdAt = DateTime.now();
      }
      await isarService.isar.invoices.put(invoice);
    });
  }

  @override
  Future<void> deleteInvoice(int id) async {
    await isarService.isar.writeTxn(() async {
      await isarService.isar.invoices.delete(id);
    });
  }

  @override
  Future<String> generateInvoiceNumber() async {
    final count = await isarService.isar.invoices.count();
    final year = DateTime.now().year.toString().substring(2);
    // Simple INV-YY-0001 format
    return 'INV-$year-${(count + 1).toString().padLeft(4, '0')}';
  }
}
