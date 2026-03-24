import 'package:flutter/material.dart';
import 'package:business_automation/core/theme/app_colors.dart';
import 'package:business_automation/features/crm/data/models/lead_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:business_automation/features/crm/presentation/cubit/lead_cubit.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:business_automation/core/services/whatsapp_service.dart';
import 'package:business_automation/core/services/notification_service.dart';
import 'package:business_automation/injection_container.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:business_automation/features/dashboard/presentation/cubit/settings_cubit.dart';
import 'package:business_automation/features/dashboard/data/models/settings_model.dart';
import 'package:business_automation/core/widgets/app_bottom_sheet.dart';

class LeadDetailPage extends StatelessWidget {
  final Lead lead;

  const LeadDetailPage({super.key, required this.lead});

  Future<void> _launchWhatsApp(String phone, String name, String businessName) async {
    final message = WhatsAppService.getLeadGreetingTemplate(name, businessName);
    await WhatsAppService.sendMessage(phone: phone, message: message);
  }

  Future<void> _launchCall(String phone) async {
    final url = 'tel:$phone';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settingsState) {
        final symbol = settingsState is SettingsLoaded ? settingsState.settings.currencySymbol : '₹';
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text('Lead Detail', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
            actions: [
              IconButton(
                onPressed: () => _showEditLeadDialog(context),
                icon: const Icon(Icons.edit_rounded, size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            lead.name[0].toUpperCase(),
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 32),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(lead.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _showStatusPicker(context),
                        child: _StatusChip(status: lead.status),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                
                // Detail Cards
                _buildDetailCard(
                  context,
                  title: 'Contact Information',
                  children: [
                    _buildDetailItem(context, Icons.phone_rounded, 'Phone', lead.phone ?? 'Not provided', onTap: () => lead.phone != null ? _launchCall(lead.phone!) : null),
                    Divider(height: 24, color: isDark ? Colors.white10 : AppColors.border),
                    _buildDetailItem(context, Icons.email_rounded, 'Email', lead.email ?? 'Not provided', onTap: () {}),
                  ],
                ),
                const SizedBox(height: 24),
                
                _buildDetailCard(
                  context,
                  title: 'Business Value',
                  children: [
                    _buildDetailItem(context, Icons.currency_rupee_rounded, 'Estimated Value', '$symbol${lead.estimatedValue?.toStringAsFixed(2) ?? '0.00'}'),
                    Divider(height: 24, color: isDark ? Colors.white10 : AppColors.border),
                    _buildDetailItem(context, Icons.calendar_today_rounded, 'Date Added', DateFormat('MMMM d, yyyy').format(lead.createdAt)),
                  ],
                ),
                const SizedBox(height: 24),
            
                _buildDetailCard(
                  context,
                  title: 'Internal Notes',
                  children: [
                    Text(
                      lead.notes?.isNotEmpty == true ? lead.notes! : 'No notes added for this lead.',
                      style: const TextStyle(color: AppColors.neutral500, height: 1.5),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Automation Section
                _buildDetailCard(
                  context,
                  title: 'Automation & Growth',
                  children: [
                    _buildDetailItem(
                      context,
                      Icons.alarm_add_rounded, 
                      'Follow-up Reminder', 
                      lead.nextFollowUp != null 
                        ? 'Scheduled: ${DateFormat('dd MMM, hh:mm a').format(lead.nextFollowUp!)}'
                        : 'Not scheduled',
                      onTap: () => _scheduleFollowUp(context),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (lead.phone != null) {
                            final state = context.read<SettingsCubit>().state;
                            final businessName = state is SettingsLoaded && state.settings.businessName.isNotEmpty 
                                ? state.settings.businessName 
                                : 'Our Team';
                            _launchWhatsApp(lead.phone!, lead.name, businessName);
                          }
                        },
                        icon: const Icon(Icons.message_rounded),
                        label: const Text('WhatsApp'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => lead.phone != null ? _launchCall(lead.phone!) : null,
                        icon: const Icon(Icons.phone_rounded),
                        label: const Text('Call Now'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailCard(BuildContext context, {required String title, required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailItem(BuildContext context, IconData icon, String label, String value, {VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : AppColors.background, 
              borderRadius: BorderRadius.circular(8)
            ),
            child: Icon(icon, size: 20, color: AppColors.neutral500),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.neutral500, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
          if (onTap != null) const Icon(Icons.chevron_right_rounded, color: AppColors.neutral500),
        ],
      ),
    );
  }

  Future<void> _scheduleFollowUp(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && context.mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null && context.mounted) {
        final scheduledDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        
        // Schedule notification
        await sl<NotificationService>().scheduleNotification(
          id: lead.id,
          title: 'Follow-up with ${lead.name}',
          body: 'Time to reach out to ${lead.name} regarding your proposal!',
          scheduledDate: scheduledDateTime,
        );

        // Update lead in DB
        if (context.mounted) {
          final updatedLead = lead..nextFollowUp = scheduledDateTime;
          context.read<LeadCubit>().updateLead(updatedLead);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Follow-up scheduled for ${DateFormat('dd MMM, hh:mm a').format(scheduledDateTime)}'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    }
  }

  void _showEditLeadDialog(BuildContext context) {
    final nameController = TextEditingController(text: lead.name);
    final valueController = TextEditingController(text: lead.estimatedValue?.toString());
    final phoneController = TextEditingController(text: lead.phone);
    final emailController = TextEditingController(text: lead.email);
    final notesController = TextEditingController(text: lead.notes);
    final leadCubit = context.read<LeadCubit>();
    final formKey = GlobalKey<FormState>();

    AppBottomSheet.show(
      context: context,
      title: 'Update Lead',
      children: [
        Form(
          key: formKey,
          child: Column(
            children: [
              _buildDialogField(context, nameController, 'Customer Name *', Icons.person_rounded, validator: (v) => v == null || v.trim().isEmpty ? 'Customer name is required' : null),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildDialogField(context, phoneController, 'Phone', Icons.phone_rounded, keyboardType: TextInputType.phone)),
                  const SizedBox(width: 16),
                  Builder(builder: (context) {
                    final symbol = context.read<SettingsCubit>().state is SettingsLoaded 
                        ? (context.read<SettingsCubit>().state as SettingsLoaded).settings.currencySymbol 
                        : '₹';
                    return Expanded(child: _buildDialogField(context, valueController, 'Value ($symbol)', Icons.currency_rupee_rounded, keyboardType: TextInputType.number));
                  }),
                ],
              ),
              const SizedBox(height: 16),
              _buildDialogField(context, emailController, 'Email Address', Icons.email_rounded, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildDialogField(context, notesController, 'Internal Notes', Icons.notes_rounded, maxLines: 3),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final updatedLead = lead
                        ..name = nameController.text
                        ..phone = phoneController.text
                        ..email = emailController.text
                        ..notes = notesController.text
                        ..estimatedValue = double.tryParse(valueController.text);
                      
                      await leadCubit.updateLead(updatedLead);
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lead updated successfully!')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    shadowColor: AppColors.primary.withOpacity(0.3),
                  ),
                  child: Text('Save Changes', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showStatusPicker(BuildContext context) {
    final leadCubit = context.read<LeadCubit>();
    AppBottomSheet.show(
      context: context,
      title: 'Update Status',
      children: LeadStatus.values.map((status) => AppBottomSheet.buildOptionTile(
        context: context,
        title: _getStatusLabel(status),
        isSelected: lead.status == status,
        onTap: () {
          leadCubit.updateLeadStatus(lead, status);
          Navigator.pop(context);
        },
      )).toList(),
    );
  }

  String _getStatusLabel(LeadStatus status) {
    switch (status) {
      case LeadStatus.newLead: return 'New';
      case LeadStatus.contacted: return 'Interested';
      case LeadStatus.proposal: return 'Proposal';
      case LeadStatus.won: return 'Won';
      case LeadStatus.lost: return 'Lost';
    }
  }

  Widget _buildDialogField(
    BuildContext context,
    TextEditingController controller, 
    String label, 
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
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
}

class _StatusChip extends StatelessWidget {
  final LeadStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case LeadStatus.newLead:
        color = Colors.blue;
        label = 'New';
        break;
      case LeadStatus.contacted:
        color = Colors.orange;
        label = 'Interested';
        break;
      case LeadStatus.proposal:
        color = Colors.purple;
        label = 'Proposal';
        break;
      case LeadStatus.won:
        color = AppColors.success;
        label = 'Won';
        break;
      case LeadStatus.lost:
        color = AppColors.error;
        label = 'Lost';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
