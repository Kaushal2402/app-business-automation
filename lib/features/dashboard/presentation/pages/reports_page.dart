import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:business_automation/core/theme/app_colors.dart';
import 'package:business_automation/features/crm/presentation/cubit/lead_cubit.dart';
import 'package:business_automation/features/invoicing/presentation/cubit/invoice_cubit.dart';
import 'package:business_automation/features/crm/data/models/lead_model.dart';
import 'package:business_automation/features/invoicing/data/models/invoice_model.dart';
import 'package:business_automation/features/dashboard/presentation/cubit/settings_cubit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:business_automation/features/dashboard/presentation/cubit/settings_cubit.dart';
import 'package:business_automation/features/dashboard/data/models/settings_model.dart';
import 'dart:io';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settingsState) {
        final symbol = settingsState is SettingsLoaded ? settingsState.settings.currencySymbol : '₹';
        
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text('Business Insights', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
          ),
          body: BlocBuilder<LeadCubit, LeadState>(
            builder: (context, leadState) {
              return BlocBuilder<InvoiceCubit, InvoiceState>(
                builder: (context, invoiceState) {
                  if (leadState is LeadLoading || invoiceState is InvoiceLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final leads = leadState is LeadLoaded ? leadState.allLeads : <Lead>[];
                  final invoices = invoiceState is InvoiceLoaded ? invoiceState.invoices : <Invoice>[];

                  return _buildReportsContent(leads, invoices, symbol, settingsState);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildReportsContent(List<Lead> leads, List<Invoice> invoices, String symbol, SettingsState settingsState) {
    final double revenue = invoices.where((i) => i.status == InvoiceStatus.paid).fold(0, (sum, i) => sum + i.total);
    final double pipeline = leads.where((l) => l.status != LeadStatus.won && l.status != LeadStatus.lost).fold(0, (sum, l) => sum + (l.estimatedValue ?? 0));
    final int wonCount = leads.where((l) => l.status == LeadStatus.won).length;
    final int lostCount = leads.where((l) => l.status == LeadStatus.lost).length;
    final double recoveryRate = revenue > 0 ? (revenue / (revenue + invoices.where((i) => i.status == InvoiceStatus.overdue).fold(0, (sum, i) => sum + i.total))) * 100 : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (settingsState is SettingsLoaded && settingsState.settings.businessName.isNotEmpty) ...[
            Row(
              children: [
                if (settingsState.settings.businessLogoPath.isNotEmpty)
                  Container(
                    width: 48,
                    height: 48,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: FileImage(File(settingsState.settings.businessLogoPath)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Executive Summary', style: GoogleFonts.inter(color: AppColors.neutral500, fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(settingsState.settings.businessName, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
          _buildSummaryGrid(revenue, pipeline, wonCount, lostCount, symbol),
          const SizedBox(height: 32),
          Text('FINANCIAL HEALTH', style: GoogleFonts.inter(letterSpacing: 1.2, fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.neutral500)),
          const SizedBox(height: 16),
          _buildChartSimulation('Revenue vs Overdue', recoveryRate / 100),
          const SizedBox(height: 32),
          Text('CONVERSION RATIO', style: GoogleFonts.inter(letterSpacing: 1.2, fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.neutral500)),
          const SizedBox(height: 16),
          _buildConversionBreakdown(wonCount, lostCount, leads.length),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(double revenue, double pipeline, int won, int lost, String symbol) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard('Revenue', '$symbol${NumberFormat.compact().format(revenue)}', AppColors.success, Icons.payments_rounded),
        _buildStatCard('Pipeline', '$symbol${NumberFormat.compact().format(pipeline)}', AppColors.primary, Icons.insights_rounded),
        _buildStatCard('Won Leads', won.toString(), Colors.orange, Icons.emoji_events_rounded),
        _buildStatCard('Goals Met', '84%', Colors.blue, Icons.track_changes_rounded),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color, 
            borderRadius: BorderRadius.circular(20), 
            border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
              Text(label, style: GoogleFonts.inter(color: AppColors.neutral500, fontSize: 11)),
            ],
          ),
        );
      }
    );
  }

  Widget _buildChartSimulation(String title, double p) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color, 
            borderRadius: BorderRadius.circular(24), 
            border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('${(p * 100).toStringAsFixed(1)}%', style: GoogleFonts.inter(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: p,
                  minHeight: 12,
                  backgroundColor: isDark ? Colors.white10 : AppColors.neutral100,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 8),
              Text('Recovery rate based on current overdue invoices.', style: GoogleFonts.inter(color: AppColors.neutral500, fontSize: 11)),
            ],
          ),
        );
      }
    );
  }

  Widget _buildConversionBreakdown(int won, int lost, int total) {
    final double wonP = total > 0 ? (won / total) : 0;
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color, 
            borderRadius: BorderRadius.circular(24), 
            border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
          ),
          child: Column(
            children: [
              _buildConversionItem('Won Leads', won, wonP, AppColors.success),
              Divider(height: 32, color: isDark ? Colors.white10 : AppColors.border),
              _buildConversionItem('Lost Leads', lost, total > 0 ? lost / total : 0, AppColors.error),
              Divider(height: 32, color: isDark ? Colors.white10 : AppColors.border),
              _buildConversionItem('In-Progress', total - won - lost, total > 0 ? (total - won - lost) / total : 0, AppColors.primary),
            ],
          ),
        );
      }
    );
  }

  Widget _buildConversionItem(String label, int count, double percentage, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14))),
        Text('$count', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(width: 8),
        Text('(${(percentage * 100).toStringAsFixed(0)}%)', style: GoogleFonts.inter(color: AppColors.neutral500, fontSize: 12)),
      ],
    );
  }
}
