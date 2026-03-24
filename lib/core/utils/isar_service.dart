import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/auth/data/models/business_profile_model.dart';
import '../../features/crm/data/models/lead_model.dart';
import '../../features/invoicing/data/models/invoice_model.dart';
import '../../features/dashboard/data/models/settings_model.dart';

class IsarService {
  late Isar isar;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [BusinessProfileSchema, LeadSchema, InvoiceSchema, SettingsModelSchema],
      directory: dir.path,
    );
  }
}
