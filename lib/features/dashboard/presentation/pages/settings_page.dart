import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:business_automation/core/theme/app_colors.dart';
import 'package:business_automation/core/services/backup_service.dart';
import 'package:business_automation/features/auth/domain/repositories/auth_repository.dart';
import 'package:business_automation/features/dashboard/presentation/cubit/settings_cubit.dart';
import 'package:business_automation/features/dashboard/data/models/settings_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:business_automation/l10n/app_localizations.dart';
import 'package:business_automation/core/widgets/app_bottom_sheet.dart';
import 'package:business_automation/injection_container.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        if (state is! SettingsLoaded) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final settings = state.settings;
        final cubit = context.read<SettingsCubit>();

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text(AppLocalizations.of(context)!.appSettings, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(AppLocalizations.of(context)!.businessProfile),
                const SizedBox(height: 12),
                _buildSettingTile(
                  context,
                  Icons.business_rounded, 
                  AppLocalizations.of(context)!.businessDetails, 
                  settings.businessName.isEmpty ? AppLocalizations.of(context)!.setupProfile : settings.businessName,
                  onTap: () => _showProfileEditor(context, settings, cubit),
                ),
                const SizedBox(height: 32),
                _buildSectionHeader(AppLocalizations.of(context)!.security),
                const SizedBox(height: 12),
                _buildSettingTile(
                  context,
                  Icons.fingerprint_rounded, 
                  AppLocalizations.of(context)!.biometrics, 
                  AppLocalizations.of(context)!.biometricsDesc,
                  trailing: Switch(
                    value: settings.biometricsEnabled, 
                    onChanged: (v) => cubit.updateBiometrics(v),
                    activeColor: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSettingTile(
                  context,
                  Icons.pin_rounded,
                  'Change Security PIN',
                  'Update your 4-digit access code',
                  onTap: () => _showChangePinSheet(context),
                ),
                const SizedBox(height: 32),
                _buildSectionHeader(AppLocalizations.of(context)!.appearance),
                const SizedBox(height: 12),
                _buildSettingTile(
                  context,
                  Icons.dark_mode_rounded, 
                  AppLocalizations.of(context)!.theme, 
                  settings.themeMode.name.toUpperCase(),
                  onTap: () => _showThemePicker(context, settings, cubit),
                ),
                const SizedBox(height: 32),
                _buildSectionHeader(AppLocalizations.of(context)!.language),
                const SizedBox(height: 12),
                _buildSettingTile(
                  context,
                  Icons.language_rounded, 
                  AppLocalizations.of(context)!.appLanguage, 
                  _getLanguageName(context, settings.languageCode),
                  onTap: () => _showLanguagePicker(context, settings, cubit),
                ),
                const SizedBox(height: 32),
                _buildSectionHeader(AppLocalizations.of(context)!.billingDefaults),
                const SizedBox(height: 12),
                _buildSettingTile(
                  context,
                  Icons.currency_exchange_rounded, 
                  AppLocalizations.of(context)!.currency, 
                  '${settings.currencyCode} (${settings.currencySymbol})',
                  onTap: () => _showCurrencyPicker(context, settings, cubit),
                ),
                const SizedBox(height: 12),
                _buildSettingTile(
                  context,
                  Icons.percent_rounded, 
                  AppLocalizations.of(context)!.taxRate, 
                  '${settings.defaultTaxRate}%',
                  onTap: () => _showTaxRatePicker(context, settings, cubit),
                ),
                const SizedBox(height: 48),

                // ── Data & Backup ──────────────────────────────────
                _buildSectionHeader('Data & Backup'),
                const SizedBox(height: 12),
                _buildSettingTile(
                  context,
                  Icons.cloud_download_rounded,
                  'Export All Data',
                  'Download a .bizbackup file to transfer or save',
                  onTap: () => _exportData(context),
                ),
                const SizedBox(height: 48),

                Center(
                  child: Text(
                    'v1.1.0 - Premium Edition',
                    style: GoogleFonts.inter(color: AppColors.neutral500, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _exportData(BuildContext context) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final success = await BackupService().exportBackup();
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (context.mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export failed. Please try again.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _showChangePinSheet(BuildContext context) {
    final authRepo = sl<AuthRepository>();
    final List<int> oldPin = [];
    final List<int> newPin = [];
    final List<int> confirmPin = [];
    // stages: 0=enter old, 1=enter new, 2=confirm new
    int stage = 0;
    String? firstNewPin;
    String errorMsg = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          List<int> currentPin() {
            if (stage == 0) return oldPin;
            if (stage == 1) return newPin;
            return confirmPin;
          }

          String title() {
            if (stage == 0) return 'Enter Current PIN';
            if (stage == 1) return 'Enter New PIN';
            return 'Confirm New PIN';
          }

          String subtitle() {
            if (stage == 0) return 'Verify your existing security code';
            if (stage == 1) return 'Choose a strong 4-digit PIN';
            return 'Re-enter the new PIN to confirm';
          }

          Future<void> onKeyPress(int value) async {
            final pin = currentPin();
            if (pin.length >= 4) return;
            pin.add(value);
            setSheetState(() => errorMsg = '');

            if (pin.length == 4) {
              final entered = pin.join();

              if (stage == 0) {
                // Verify old PIN
                final valid = await authRepo.verifyPin(entered);
                if (valid) {
                  setSheetState(() { stage = 1; newPin.clear(); });
                } else {
                  setSheetState(() { oldPin.clear(); errorMsg = 'Incorrect PIN. Try again.'; });
                }
              } else if (stage == 1) {
                // Validate new PIN strength
                final repeating = RegExp(r'^(.)\1{3}$');
                if (entered == '1234' || entered == '4321' || repeating.hasMatch(entered)) {
                  setSheetState(() { newPin.clear(); errorMsg = 'Choose a stronger PIN (avoid 1234 or repeating digits)'; });
                } else {
                  firstNewPin = entered;
                  setSheetState(() { stage = 2; confirmPin.clear(); });
                }
              } else {
                // Confirm new PIN
                if (firstNewPin == entered) {
                  await authRepo.savePin(entered);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ PIN updated successfully!'), behavior: SnackBarBehavior.floating),
                  );
                } else {
                  setSheetState(() { stage = 1; newPin.clear(); confirmPin.clear(); firstNewPin = null; errorMsg = 'PINs do not match. Re-enter new PIN.'; });
                }
              }
            } else {
              setSheetState(() {});
            }
          }

          void onDelete() {
            final pin = currentPin();
            if (pin.isNotEmpty) setSheetState(() => pin.removeLast());
          }

          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.neutral500.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 24),
                    Icon(Icons.lock_reset_rounded, size: 52, color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text(title(), style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(subtitle(), style: GoogleFonts.inter(fontSize: 14, color: AppColors.neutral500)),
                    const SizedBox(height: 32),
                    // PIN dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (i) {
                        final filled = i < currentPin().length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          width: 16, height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled ? AppColors.primary : Colors.transparent,
                            border: Border.all(color: filled ? AppColors.primary : AppColors.neutral500, width: 2),
                          ),
                        );
                      }),
                    ),
                    if (errorMsg.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(errorMsg, style: GoogleFonts.inter(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w500)),
                    ],
                    const SizedBox(height: 32),
                    // Keypad
                    ...[[1,2,3],[4,5,6],[7,8,9]].map((row) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: row.map((n) => GestureDetector(
                          onTap: () => onKeyPress(n),
                          child: Container(
                            width: 72, height: 72, margin: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.08)),
                            child: Center(child: Text('$n', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600))),
                          ),
                        )).toList(),
                      ),
                    )),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 96 + 24),
                        GestureDetector(
                          onTap: () => onKeyPress(0),
                          child: Container(
                            width: 72, height: 72, margin: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.08)),
                            child: Center(child: Text('0', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600))),
                          ),
                        ),
                        GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            width: 72, height: 72, margin: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.transparent),
                            child: const Center(child: Icon(Icons.backspace_rounded, size: 24)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getLanguageName(BuildContext context, String code) {
    switch (code) {
      case 'en': return AppLocalizations.of(context)!.english;
      case 'es': return AppLocalizations.of(context)!.spanish;
      case 'fr': return AppLocalizations.of(context)!.french;
      default: return AppLocalizations.of(context)!.english;
    }
  }

  void _showThemePicker(BuildContext context, SettingsModel settings, SettingsCubit cubit) {
    AppBottomSheet.show(
      context: context,
      title: AppLocalizations.of(context)!.theme,
      children: ThemeModePreference.values.map((mode) => AppBottomSheet.buildOptionTile(
        context: context,
        title: mode.name.toUpperCase(),
        isSelected: settings.themeMode == mode,
        onTap: () {
          cubit.updateTheme(mode);
          Navigator.pop(context);
        },
      )).toList(),
    );
  }

  void _showLanguagePicker(BuildContext context, SettingsModel settings, SettingsCubit cubit) {
    final langs = {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
    };
    AppBottomSheet.show(
      context: context,
      title: AppLocalizations.of(context)!.appLanguage,
      children: langs.entries.map((entry) => AppBottomSheet.buildOptionTile(
        context: context,
        title: entry.value,
        isSelected: settings.languageCode == entry.key,
        onTap: () {
          cubit.updateLanguage(entry.key);
          Navigator.pop(context);
        },
      )).toList(),
    );
  }

  void _showCurrencyPicker(BuildContext context, SettingsModel settings, SettingsCubit cubit) {
    final currencies = {
      'INR': '₹',
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
    };
    AppBottomSheet.show(
      context: context,
      title: AppLocalizations.of(context)!.currency,
      children: currencies.entries.map((entry) => AppBottomSheet.buildOptionTile(
        context: context,
        title: '${entry.key} (${entry.value})',
        isSelected: settings.currencyCode == entry.key,
        onTap: () {
          cubit.updateCurrency(entry.key, entry.value);
          Navigator.pop(context);
        },
      )).toList(),
    );
  }

  void _showTaxRatePicker(BuildContext context, SettingsModel settings, SettingsCubit cubit) {
    final controller = TextEditingController(text: settings.defaultTaxRate.toString());
    AppBottomSheet.show(
      context: context,
      title: AppLocalizations.of(context)!.taxRate,
      children: [
        _buildDialogField(context, controller, 'Tax Rate (%)', Icons.percent_rounded, keyboardType: TextInputType.number),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            final rate = double.tryParse(controller.text);
            if (rate != null) {
              cubit.updateTaxRate(rate);
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(AppLocalizations.of(context)!.saveRate),
        ),
      ],
    );
  }

  void _showProfileEditor(BuildContext context, SettingsModel settings, SettingsCubit cubit) {
    final nameController = TextEditingController(text: settings.businessName);
    final emailController = TextEditingController(text: settings.businessEmail);
    final phoneController = TextEditingController(text: settings.businessPhone);
    final addressController = TextEditingController(text: settings.businessAddress);
    final taxNoController = TextEditingController(text: settings.businessTaxNumber);
    String logoPath = settings.businessLogoPath;

    AppBottomSheet.show(
      context: context,
      title: AppLocalizations.of(context)!.businessProfile,
      children: [
        StatefulBuilder(
          builder: (context, setSheetState) => Column(
            children: [
              Center(
                child: GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final image = await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      setSheetState(() => logoPath = image.path);
                    }
                  },
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                      image: logoPath.isNotEmpty ? DecorationImage(image: FileImage(File(logoPath)), fit: BoxFit.cover) : null,
                    ),
                    child: logoPath.isEmpty ? const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 32) : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildDialogField(context, nameController, AppLocalizations.of(context)!.businessName, Icons.store_rounded),
              const SizedBox(height: 16),
              _buildDialogField(context, emailController, AppLocalizations.of(context)!.businessEmail, Icons.email_rounded, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildDialogField(context, phoneController, AppLocalizations.of(context)!.businessPhone, Icons.phone_rounded, keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              _buildDialogField(context, taxNoController, AppLocalizations.of(context)!.taxNumber, Icons.receipt_long_rounded),
              const SizedBox(height: 16),
              _buildDialogField(context, addressController, AppLocalizations.of(context)!.businessAddress, Icons.location_on_rounded, maxLines: 2),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    cubit.updateProfile(
                      name: nameController.text,
                      email: emailController.text,
                      phone: phoneController.text,
                      address: addressController.text,
                      taxNumber: taxNoController.text,
                      logoPath: logoPath,
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    shadowColor: AppColors.primary.withOpacity(0.3),
                  ),
                  child: Text(AppLocalizations.of(context)!.saveProfile, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDialogField(
    BuildContext context,
    TextEditingController controller, 
    String label, 
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: AppColors.neutral500, fontWeight: FontWeight.w400, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: AppColors.primary),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(letterSpacing: 1.2, fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.neutral500),
    );
  }

  Widget _buildSettingTile(BuildContext context, IconData icon, String title, String subtitle, {Widget? trailing, VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: isDark ? Colors.white12 : AppColors.background, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(subtitle, style: GoogleFonts.inter(color: AppColors.neutral500, fontSize: 12)),
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.neutral500),
      ),
    );
  }
}
