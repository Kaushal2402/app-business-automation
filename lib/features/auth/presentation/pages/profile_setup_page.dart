import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:business_automation/core/services/backup_service.dart';
import 'package:business_automation/core/theme/app_colors.dart';
import 'package:business_automation/features/dashboard/presentation/cubit/settings_cubit.dart';
import 'package:business_automation/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:business_automation/l10n/app_localizations.dart';
import 'package:business_automation/injection_container.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _taxNumberController = TextEditingController();
  String? _logoPath;
  bool _sheetShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showImportOrCreateSheet());
  }

  void _showImportOrCreateSheet() {
    if (_sheetShown) return;
    _sheetShown = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(width: 44, height: 4, decoration: BoxDecoration(color: AppColors.neutral500.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 28),
                // Icon
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.storefront_rounded, size: 40, color: AppColors.primary),
                ),
                const SizedBox(height: 20),
                Text('Setup Your Business', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Import your existing data or start fresh', style: GoogleFonts.inter(fontSize: 14, color: AppColors.neutral500), textAlign: TextAlign.center),
                const SizedBox(height: 32),

                // Option 1: Import
                _buildSetupOption(
                  ctx,
                  icon: Icons.cloud_upload_rounded,
                  iconColor: AppColors.primary,
                  title: 'Import Old Business',
                  subtitle: 'Restore from a .bizbackup file',
                  onTap: () => _handleImport(ctx),
                ),
                const SizedBox(height: 16),

                // Option 2: Create New
                _buildSetupOption(
                  ctx,
                  icon: Icons.add_business_rounded,
                  iconColor: const Color(0xFF22C55E),
                  title: 'Create New Business',
                  subtitle: 'Set up your business profile from scratch',
                  onTap: () => Navigator.pop(ctx),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSetupOption(BuildContext ctx, {required IconData icon, required Color iconColor, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(ctx).cardColor,
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppColors.neutral500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.neutral500),
          ],
        ),
      ),
    );
  }

  Future<void> _handleImport(BuildContext sheetCtx) async {
    Navigator.pop(sheetCtx); // Close sheet first
    // Loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text('Importing backup...', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
    final result = await BackupService().importBackup();
    if (mounted) Navigator.of(context, rootNavigator: true).pop(); // Close loading
    if (!mounted) return;
    switch (result) {
      case BackupImportResult.success:
        // Refresh SettingsCubit then go to Dashboard
        context.read<SettingsCubit>().loadSettings();
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardPage()));
        break;
      case BackupImportResult.cancelled:
        _showImportOrCreateSheet(); // Re-show choice
        break;
      case BackupImportResult.versionMismatch:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup version not supported.'), behavior: SnackBarBehavior.floating));
        _showImportOrCreateSheet();
        break;
      case BackupImportResult.error:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import failed. File may be corrupted.'), behavior: SnackBarBehavior.floating));
        _showImportOrCreateSheet();
        break;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _logoPath = pickedFile.path;
      });
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Pick from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SettingsCubit, SettingsState>(
      listener: (context, state) {
        if (state is SettingsLoaded) {
          // Check if profile was actually updated (businessName won't be empty after save)
          if (state.settings.businessName.isNotEmpty) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DashboardPage()),
            );
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.setupProfile, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.businessProfile,
                  style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.setupProfile,
                  style: GoogleFonts.inter(color: AppColors.neutral500),
                ),
                const SizedBox(height: 32),
                // Logo Picker
                Center(
                  child: GestureDetector(
                    onTap: _showImagePickerOptions,
                    child: Column(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: AppColors.border),
                            image: _logoPath != null
                                ? DecorationImage(
                                    image: FileImage(File(_logoPath!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _logoPath == null
                              ? const Icon(Icons.add_a_photo_rounded, color: AppColors.neutral500, size: 36)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _logoPath == null ? AppLocalizations.of(context)!.logo : AppLocalizations.of(context)!.logo,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                _buildTextField(
                  controller: _nameController,
                  label: AppLocalizations.of(context)!.businessName,
                  hint: 'e.g. Softpital Tech',
                  icon: Icons.business_rounded,
                  validator: (value) => value == null || value.isEmpty ? AppLocalizations.of(context)!.customerNameRequired : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _emailController,
                  label: AppLocalizations.of(context)!.businessEmail,
                  hint: 'hello@softpital.com',
                  icon: Icons.email_rounded,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _phoneController,
                  label: AppLocalizations.of(context)!.businessPhone,
                  hint: '+91 98765 43210',
                  icon: Icons.phone_rounded,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _addressController,
                  label: AppLocalizations.of(context)!.businessAddress,
                  hint: '123 Business St, City',
                  icon: Icons.location_on_rounded,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _taxNumberController,
                  label: AppLocalizations.of(context)!.taxNumber,
                  hint: 'e.g. 27AAAAA0000A1Z5',
                  icon: Icons.receipt_long_rounded,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => _saveProfile(context),
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
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ],
    );
  }

  void _saveProfile(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      context.read<SettingsCubit>().updateProfile(
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        address: _addressController.text,
        taxNumber: _taxNumberController.text,
        logoPath: _logoPath,
      );
    }
  }
}
