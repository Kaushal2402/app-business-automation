import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:business_automation/core/utils/isar_service.dart';
import 'package:business_automation/features/crm/data/models/lead_model.dart';
import 'package:business_automation/features/dashboard/data/models/settings_model.dart';
import 'package:business_automation/features/invoicing/data/models/invoice_model.dart';
import 'package:business_automation/injection_container.dart';

class BackupService {
  static const String _backupExtension = 'bizbackup';
  static const int _backupVersion = 1;

  final IsarService _isarService = sl<IsarService>();

  // ─────────────────── EXPORT ───────────────────

  Future<bool> exportBackup() async {
    try {
      final isar = _isarService.isar;

      final settings = await isar.settingsModels.where().findFirst();
      final leads = await isar.leads.where().findAll();
      final invoices = await isar.invoices.where().findAll();

      final backupMap = {
        'version': _backupVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': settings != null ? _settingsToJson(settings) : null,
        'leads': leads.map(_leadToJson).toList(),
        'invoices': invoices.map(_invoiceToJson).toList(),
      };

      final json = const JsonEncoder.withIndent('  ').convert(backupMap);

      // Save to application documents directory (persists, not temp)
      final dir = await getApplicationDocumentsDirectory();
      final date = DateTime.now().toIso8601String().split('T').first; // YYYY-MM-DD
      final filePath = '${dir.path}/bizbackup_$date.$_backupExtension';
      final file = File(filePath);
      await file.writeAsString(json);

      // Share the file using XFile
      final xFile = XFile(filePath, mimeType: 'application/octet-stream', name: 'bizbackup_$date.$_backupExtension');
      final result = await Share.shareXFiles(
        [xFile],
        subject: 'Business App Backup - $date',
        text: 'Restore this file on your new device using the Business App.',
      );

      // ShareResultStatus.dismissed is still a valid result (user shared or dismissed)
      return result.status != ShareResultStatus.unavailable;
    } catch (e, s) {
      // ignore: avoid_print
      print('[BackupService] Export error: $e\n$s');
      return false;
    }
  }

  // ─────────────────── IMPORT ───────────────────

  Future<BackupImportResult> importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [_backupExtension],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return BackupImportResult.cancelled;
      }

      final path = result.files.single.path;
      if (path == null) return BackupImportResult.error;

      final file = File(path);
      final raw = await file.readAsString();
      final Map<String, dynamic> data = json.decode(raw);

      // Version check
      final version = data['version'] as int? ?? 0;
      if (version != _backupVersion) return BackupImportResult.versionMismatch;

      final isar = _isarService.isar;

      await isar.writeTxn(() async {
        // Clear existing data
        await isar.leads.clear();
        await isar.invoices.clear();
        await isar.settingsModels.clear();

        // Restore settings
        if (data['settings'] != null) {
          final settings = _settingsFromJson(data['settings'] as Map<String, dynamic>);
          await isar.settingsModels.put(settings);
        }

        // Restore leads
        final leadsJson = data['leads'] as List<dynamic>? ?? [];
        for (final lj in leadsJson) {
          final lead = _leadFromJson(lj as Map<String, dynamic>);
          await isar.leads.put(lead);
        }

        // Restore invoices
        final invoicesJson = data['invoices'] as List<dynamic>? ?? [];
        for (final ij in invoicesJson) {
          final invoice = _invoiceFromJson(ij as Map<String, dynamic>);
          await isar.invoices.put(invoice);
        }
      });

      return BackupImportResult.success;
    } catch (e) {
      return BackupImportResult.error;
    }
  }

  // ─────────────────── SERIALIZERS ───────────────────

  Map<String, dynamic> _settingsToJson(SettingsModel s) => {
    'themeMode': s.themeMode.name,
    'currencyCode': s.currencyCode,
    'currencySymbol': s.currencySymbol,
    'defaultTaxRate': s.defaultTaxRate,
    'languageCode': s.languageCode,
    'biometricsEnabled': s.biometricsEnabled,
    'businessName': s.businessName,
    'businessEmail': s.businessEmail,
    'businessPhone': s.businessPhone,
    'businessAddress': s.businessAddress,
    'businessTaxNumber': s.businessTaxNumber,
    'businessLogoPath': s.businessLogoPath,
  };

  SettingsModel _settingsFromJson(Map<String, dynamic> j) {
    final s = SettingsModel();
    s.id = 0; // Singleton
    s.themeMode = ThemeModePreference.values.firstWhere(
      (e) => e.name == j['themeMode'],
      orElse: () => ThemeModePreference.light,
    );
    s.currencyCode = j['currencyCode'] ?? 'INR';
    s.currencySymbol = j['currencySymbol'] ?? '₹';
    s.defaultTaxRate = (j['defaultTaxRate'] as num?)?.toDouble() ?? 18.0;
    s.languageCode = j['languageCode'] ?? 'en';
    s.biometricsEnabled = j['biometricsEnabled'] ?? true;
    s.businessName = j['businessName'] ?? '';
    s.businessEmail = j['businessEmail'] ?? '';
    s.businessPhone = j['businessPhone'] ?? '';
    s.businessAddress = j['businessAddress'] ?? '';
    s.businessTaxNumber = j['businessTaxNumber'] ?? '';
    s.businessLogoPath = j['businessLogoPath'] ?? '';
    return s;
  }

  Map<String, dynamic> _leadToJson(Lead l) => {
    'name': l.name,
    'phone': l.phone,
    'email': l.email,
    'status': l.status.name,
    'estimatedValue': l.estimatedValue,
    'notes': l.notes,
    'createdAt': l.createdAt.toIso8601String(),
    'nextFollowUp': l.nextFollowUp?.toIso8601String(),
    'lastMessageSent': l.lastMessageSent,
  };

  Lead _leadFromJson(Map<String, dynamic> j) {
    final l = Lead();
    l.name = j['name'] ?? '';
    l.phone = j['phone'];
    l.email = j['email'];
    l.status = LeadStatus.values.firstWhere(
      (e) => e.name == j['status'],
      orElse: () => LeadStatus.newLead,
    );
    l.estimatedValue = (j['estimatedValue'] as num?)?.toDouble();
    l.notes = j['notes'];
    l.createdAt = DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now();
    l.nextFollowUp = j['nextFollowUp'] != null ? DateTime.tryParse(j['nextFollowUp']) : null;
    l.lastMessageSent = j['lastMessageSent'];
    return l;
  }

  Map<String, dynamic> _invoiceToJson(Invoice inv) => {
    'invoiceNumber': inv.invoiceNumber,
    'customerName': inv.customerName,
    'customerPhone': inv.customerPhone,
    'customerEmail': inv.customerEmail,
    'customerAddress': inv.customerAddress,
    'date': inv.date.toIso8601String(),
    'dueDate': inv.dueDate.toIso8601String(),
    'items': inv.items.map((i) => {
      'description': i.description,
      'quantity': i.quantity,
      'unitPrice': i.unitPrice,
      'taxRate': i.taxRate,
      'taxAmount': i.taxAmount,
      'total': i.total,
    }).toList(),
    'subtotal': inv.subtotal,
    'taxRate': inv.taxRate,
    'taxAmount': inv.taxAmount,
    'discountAmount': inv.discountAmount,
    'total': inv.total,
    'status': inv.status.name,
    'notes': inv.notes,
    'paymentTerms': inv.paymentTerms,
    'nextReminder': inv.nextReminder?.toIso8601String(),
    'createdAt': inv.createdAt?.toIso8601String(),
    'updatedAt': inv.updatedAt?.toIso8601String(),
  };

  Invoice _invoiceFromJson(Map<String, dynamic> j) {
    final inv = Invoice();
    inv.invoiceNumber = j['invoiceNumber'] ?? '';
    inv.customerName = j['customerName'] ?? '';
    inv.customerPhone = j['customerPhone'];
    inv.customerEmail = j['customerEmail'];
    inv.customerAddress = j['customerAddress'];
    inv.date = DateTime.tryParse(j['date'] ?? '') ?? DateTime.now();
    inv.dueDate = DateTime.tryParse(j['dueDate'] ?? '') ?? DateTime.now();
    inv.items = ((j['items'] as List<dynamic>?) ?? []).map((item) {
      final i = InvoiceItem();
      i.description = item['description'];
      i.quantity = item['quantity'] ?? 1;
      i.unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0;
      i.taxRate = (item['taxRate'] as num?)?.toDouble() ?? 0;
      i.taxAmount = (item['taxAmount'] as num?)?.toDouble() ?? 0;
      i.total = (item['total'] as num?)?.toDouble() ?? 0;
      return i;
    }).toList();
    inv.subtotal = (j['subtotal'] as num?)?.toDouble() ?? 0;
    inv.taxRate = (j['taxRate'] as num?)?.toDouble() ?? 0;
    inv.taxAmount = (j['taxAmount'] as num?)?.toDouble() ?? 0;
    inv.discountAmount = (j['discountAmount'] as num?)?.toDouble() ?? 0;
    inv.total = (j['total'] as num?)?.toDouble() ?? 0;
    inv.status = InvoiceStatus.values.firstWhere(
      (e) => e.name == j['status'],
      orElse: () => InvoiceStatus.draft,
    );
    inv.notes = j['notes'];
    inv.paymentTerms = j['paymentTerms'];
    inv.nextReminder = j['nextReminder'] != null ? DateTime.tryParse(j['nextReminder']) : null;
    inv.createdAt = j['createdAt'] != null ? DateTime.tryParse(j['createdAt']) : null;
    inv.updatedAt = j['updatedAt'] != null ? DateTime.tryParse(j['updatedAt']) : null;
    return inv;
  }
}

enum BackupImportResult {
  success,
  cancelled,
  error,
  versionMismatch,
}
