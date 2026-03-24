import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:business_automation/core/theme/app_colors.dart';
import 'package:business_automation/features/crm/data/models/lead_model.dart';
import 'package:business_automation/features/crm/presentation/cubit/lead_cubit.dart';
import 'package:business_automation/features/invoicing/data/models/invoice_model.dart';
import 'package:business_automation/features/invoicing/presentation/cubit/invoice_cubit.dart';
import 'package:business_automation/features/dashboard/presentation/cubit/settings_cubit.dart';
import 'package:business_automation/core/services/whatsapp_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class GrowthEnginePage extends StatelessWidget {
  const GrowthEnginePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Growth Engine', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: MultiBlocBuilder(
        builders: [
          BlocBuilder<LeadCubit, LeadState>(builder: (context, state) => const SizedBox.shrink()),
          BlocBuilder<InvoiceCubit, InvoiceState>(builder: (context, state) => const SizedBox.shrink()),
        ],
        builder: (context, states) {
          final leadState = states[0] as LeadState;
          final invoiceState = states[1] as InvoiceState;

          List<dynamic> followUps = [];
          if (leadState is LeadLoaded) {
            followUps.addAll(leadState.allLeads.where((l) => l.nextFollowUp != null));
          }
          if (invoiceState is InvoiceLoaded) {
            followUps.addAll(invoiceState.invoices.where((i) => i.nextReminder != null));
          }

          // Sort by date
          followUps.sort((a, b) {
            final dateA = (a is Lead) ? a.nextFollowUp! : a.nextReminder!;
            final dateB = (b is Lead) ? b.nextFollowUp! : b.nextReminder!;
            return dateA.compareTo(dateB);
          });

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInsightCard(followUps.length),
                const SizedBox(height: 32),
                Text('UPCOMING ACTIONS', style: GoogleFonts.inter(letterSpacing: 1.2, fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.neutral500)),
                const SizedBox(height: 16),
                if (followUps.isEmpty)
                  _buildEmptyState()
                else
                  ...followUps.map((item) => _buildFollowUpCard(context, item)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInsightCard(int count) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 32),
          const SizedBox(height: 16),
          Text(
            'Ready for Growth?',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'You have $count scheduled actions to convert leads and collect payments.',
            style: GoogleFonts.inter(color: Colors.white.withOpacity(0.8), fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 48),
          Icon(Icons.auto_awesome_rounded, size: 64, color: AppColors.neutral100),
          const SizedBox(height: 16),
          Text('All caught up!', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Schedule follow-ups from Lead or Invoice details to see them here.', 
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.neutral500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpCard(BuildContext context, dynamic item) {
    final bool isLead = item is Lead;
    final String title = isLead ? item.name : item.invoiceNumber;
    final String subtitle = isLead ? 'Lead Follow-up' : 'Payment Reminder';
    final DateTime date = isLead ? item.nextFollowUp! : item.nextReminder!;
    final Color color = isLead ? AppColors.primary : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(isLead ? Icons.person_rounded : Icons.description_rounded, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.inter(color: AppColors.neutral500, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(DateFormat('hh:mm a').format(date), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(DateFormat('dd MMM').format(date), style: GoogleFonts.inter(color: AppColors.neutral500, fontSize: 11)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  final phone = isLead ? item.phone : (item as Invoice).customerPhone;
                  if (phone != null) {
                    final state = context.read<SettingsCubit>().state;
                    final businessName = state is SettingsLoaded && state.settings.businessName.isNotEmpty 
                        ? state.settings.businessName 
                        : 'Our Team';

                    final message = isLead 
                      ? WhatsAppService.getLeadGreetingTemplate(item.name, businessName)
                      : WhatsAppService.getInvoiceReminderTemplate((item as Invoice).invoiceNumber, item.total, businessName);
                    WhatsAppService.sendMessage(phone: phone, message: message);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: Text('WhatsApp', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MultiBlocBuilder extends StatelessWidget {
  final List<Widget> builders;
  final Widget Function(BuildContext, List<dynamic>) builder;

  const MultiBlocBuilder({super.key, required this.builders, required this.builder});

  @override
  Widget build(BuildContext context) {
    // This is a simplified version of a MultiBlocBuilder
    // In a real app, you might use nested BlocBuilders or a combined State
    return BlocBuilder<LeadCubit, LeadState>(
      builder: (context, leadState) {
        return BlocBuilder<InvoiceCubit, InvoiceState>(
          builder: (context, invoiceState) {
            return builder(context, [leadState, invoiceState]);
          },
        );
      },
    );
  }
}
