import 'package:isar/isar.dart';

part 'invoice_model.g.dart';

@collection
class Invoice {
  Id id = Isar.autoIncrement;

  late String invoiceNumber;
  late String customerName;
  String? customerPhone;
  String? customerEmail;
  String? customerAddress;

  late DateTime date;
  late DateTime dueDate;

  List<InvoiceItem> items = [];

  double subtotal = 0;
  double taxRate = 0; // percentage
  double taxAmount = 0;
  double discountAmount = 0;
  late double total;

  @enumerated
  late InvoiceStatus status;

  String? notes;
  String? paymentTerms;

  DateTime? nextReminder;

  DateTime? createdAt;
  DateTime? updatedAt;
}

@embedded
class InvoiceItem {
  String? description;
  int quantity = 1;
  double unitPrice = 0;
  double taxRate = 0; // percentage
  double taxAmount = 0;
  double total = 0;
}

enum InvoiceStatus {
  draft,
  sent,
  paid,
  overdue,
  cancelled
}
