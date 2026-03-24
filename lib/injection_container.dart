import 'package:get_it/get_it.dart';
import 'core/utils/isar_service.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/crm/data/repositories/lead_repository.dart';
import 'features/crm/presentation/cubit/lead_cubit.dart';
import 'features/invoicing/domain/repositories/invoice_repository.dart';
import 'features/invoicing/data/repositories/invoice_repository_impl.dart';
import 'features/invoicing/presentation/cubit/invoice_cubit.dart';
import 'core/services/notification_service.dart';
import 'core/services/whatsapp_service.dart';
import 'features/dashboard/data/repositories/settings_repository.dart';
import 'features/dashboard/presentation/cubit/settings_cubit.dart';
import 'features/dashboard/data/models/settings_model.dart';

final sl = GetIt.instance;

Future<void> init() async {
  //! Features - Auth

  // Repository
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl()));

  sl.registerFactory(() => LeadCubit(sl()));

  //! Features - CRM
  sl.registerLazySingleton<LeadRepository>(() => LeadRepositoryImpl(sl()));

  //! Features - Invoicing
  sl.registerFactory(() => InvoiceCubit(sl()));
  sl.registerLazySingleton<InvoiceRepository>(() => InvoiceRepositoryImpl(sl()));

  //! Features - Dashboard (Settings)
  sl.registerLazySingleton(() => SettingsRepository(sl<IsarService>().isar));
  sl.registerFactory(() => SettingsCubit(sl()));

  //! Core
  final isarService = IsarService();
  await isarService.init();
  sl.registerSingleton<IsarService>(isarService);

  final notificationService = NotificationService();
  await notificationService.init();
  sl.registerSingleton<NotificationService>(notificationService);

  //! External
}
