import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:business_automation/l10n/app_localizations.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:business_automation/features/dashboard/presentation/cubit/settings_cubit.dart';
import 'package:business_automation/features/dashboard/data/models/settings_model.dart';
import 'package:business_automation/core/theme/app_theme.dart';
import 'package:business_automation/features/auth/presentation/pages/splash_page.dart';
import 'package:business_automation/injection_container.dart' as di;
import 'package:business_automation/injection_container.dart' show sl;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  runApp(
    BlocProvider(
      create: (_) => sl<SettingsCubit>()..loadSettings(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        ThemeMode themeMode = ThemeMode.system;
        Locale locale = const Locale('en');

        if (state is SettingsLoaded) {
          switch (state.settings.themeMode) {
            case ThemeModePreference.light: themeMode = ThemeMode.light; break;
            case ThemeModePreference.dark: themeMode = ThemeMode.dark; break;
            case ThemeModePreference.system: themeMode = ThemeMode.system; break;
          }
          locale = Locale(state.settings.languageCode);
        }

        return MaterialApp(
          title: 'Business Automation',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('es'),
            Locale('fr'),
          ],
          home: const SplashPage(),
        );
      },
    );
  }
}
