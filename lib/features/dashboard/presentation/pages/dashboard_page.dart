import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:business_automation/core/theme/app_colors.dart';
import 'package:business_automation/features/crm/presentation/pages/leads_page.dart';
import 'package:business_automation/features/invoicing/presentation/pages/invoices_page.dart';
import 'package:business_automation/features/crm/presentation/pages/growth_engine_page.dart';
import 'package:business_automation/features/crm/presentation/cubit/lead_cubit.dart';
import 'package:business_automation/features/invoicing/presentation/cubit/invoice_cubit.dart';
import 'package:business_automation/features/crm/data/models/lead_model.dart';
import 'package:business_automation/features/invoicing/data/models/invoice_model.dart';
import 'package:business_automation/injection_container.dart';
import 'package:business_automation/features/dashboard/presentation/pages/reports_page.dart';
import 'package:business_automation/features/dashboard/presentation/pages/settings_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:business_automation/features/dashboard/presentation/cubit/settings_cubit.dart';
import 'package:business_automation/features/dashboard/data/models/settings_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:business_automation/l10n/app_localizations.dart';
import 'dart:io';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => sl<LeadCubit>()..loadLeads()),
        BlocProvider(create: (context) => sl<InvoiceCubit>()..loadInvoices()),
      ],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settingsState) {
          final settings = settingsState is SettingsLoaded ? settingsState.settings : SettingsModel();
          final symbol = settings.currencySymbol;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF0F0F1A) : AppColors.background,
            appBar: AppBar(
              backgroundColor: isDark ? const Color(0xFF161625) : Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)!.appTitle, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 22, color: isDark ? Colors.white : Colors.black)),
                  if (settings.businessName.isNotEmpty)
                    Text(settings.businessName, style: GoogleFonts.inter(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: () {
                    context.read<LeadCubit>().loadLeads();
                    context.read<InvoiceCubit>().loadInvoices();
                  },
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                  tooltip: 'Refresh Data',
                ),
                IconButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
                  icon: const Icon(Icons.settings_suggest_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: () async {
                context.read<LeadCubit>().loadLeads();
                context.read<InvoiceCubit>().loadInvoices();
              },
              child: BlocBuilder<LeadCubit, LeadState>(
                builder: (context, leadState) {
                  return BlocBuilder<InvoiceCubit, InvoiceState>(
                    builder: (context, invoiceState) {
                      if (leadState is LeadLoading || invoiceState is InvoiceLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      List<Lead> leads = [];
                      List<Invoice> invoices = [];

                      if (leadState is LeadLoaded) leads = leadState.allLeads;
                      if (invoiceState is InvoiceLoaded) invoices = invoiceState.invoices;

                      return _buildDashboardContent(context, leads, invoices, symbol, settings);
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, List<Lead> leads, List<Invoice> invoices, String currencySymbol, SettingsModel settings) {
    final double totalRevenue = invoices
        .where((i) => i.status == InvoiceStatus.paid)
        .fold(0, (sum, i) => sum + i.total);
    
    final double pendingPayments = invoices
        .where((i) => i.status == InvoiceStatus.sent || i.status == InvoiceStatus.overdue)
        .fold(0, (sum, i) => sum + i.total);

    final double pipelineValue = leads
        .where((l) => l.status != LeadStatus.won && l.status != LeadStatus.lost)
        .fold(0, (sum, l) => sum + (l.estimatedValue ?? 0));

    final recentLeads = leads.take(5).toList();
    final recentInvoices = invoices.take(5).toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeHeader(context, settings),
          const SizedBox(height: 24),
          
          // Primary Metric Card
          _buildMainMetric(context, totalRevenue, currencySymbol),
          const SizedBox(height: 20),
          
          // Revenue Chart Section
          _buildRevenueChart(context, invoices, currencySymbol),
          const SizedBox(height: 24),

          // Secondary metrics row
          Row(
            children: [
              _buildSmallMetric(
                context: context,
                label: AppLocalizations.of(context)!.pipeline, 
                value: '$currencySymbol${NumberFormat.compact().format(pipelineValue)}',
                icon: Icons.auto_graph_rounded,
                color: const Color(0xFF6366F1),
              ),
              const SizedBox(width: 16),
              _buildSmallMetric(
                context: context,
                label: AppLocalizations.of(context)!.pending, 
                value: '$currencySymbol${NumberFormat.compact().format(pendingPayments)}',
                icon: Icons.schedule_rounded,
                color: Colors.orange,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          _buildSectionHeader(context, AppLocalizations.of(context)!.quickActions, null),
          const SizedBox(height: 16),
          _buildQuickActions(context),
          
          const SizedBox(height: 24),
          _buildSectionHeader(context, AppLocalizations.of(context)!.recentActivity, () {
             Navigator.push(context, MaterialPageRoute(builder: (_) => const LeadsPage()));
          }),
          const SizedBox(height: 12),
          _buildRecentLeads(recentLeads, currencySymbol),

          const SizedBox(height: 24),
          _buildSectionHeader(context, AppLocalizations.of(context)!.latestInvoices, () {
             Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoicesPage()));
          }),
          const SizedBox(height: 12),
          _buildRecentInvoices(context, recentInvoices, currencySymbol),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context, SettingsModel settings) {
    return Row(
      children: [
        if (settings.businessLogoPath.isNotEmpty)
          Container(
            width: 50,
            height: 50,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              image: DecorationImage(
                image: FileImage(File(settings.businessLogoPath)),
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.welcomeBack,
              style: GoogleFonts.inter(color: AppColors.neutral500, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              settings.businessName.isNotEmpty ? settings.businessName : 'Growth Mindset',
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainMetric(BuildContext context, double amount, String currencySymbol) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF2D31FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context)!.netRevenue, style: GoogleFonts.inter(color: Colors.white.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_outward_rounded, color: Colors.white, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$currencySymbol${NumberFormat('#,##,##0').format(amount)}',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Text('Updates in real-time', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart(BuildContext context, List<Invoice> invoices, String symbol) {
    // Basic aggregation for last 5 days
    final now = DateTime.now();
    final dataPoints = List.generate(5, (index) {
      final date = now.subtract(Duration(days: 4 - index));
      final dayTotal = invoices
          .where((i) => 
            i.status == InvoiceStatus.paid && 
            i.date.day == date.day && 
            i.date.month == date.month)
          .fold(0.0, (sum, i) => sum + i.total);
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: dayTotal == 0 ? 0.5 : dayTotal,
            color: index == 4 ? AppColors.primary : AppColors.primary.withOpacity(0.3),
            width: 18,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.border.withOpacity(0.1) : AppColors.border),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity Analysis', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 2.2,
            child: BarChart(
              BarChartData(
                barGroups: dataPoints,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(days[value.toInt() % 5], style: const TextStyle(fontSize: 10, color: AppColors.neutral500)),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallMetric({required BuildContext context, required String label, required String value, required IconData icon, required Color color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? AppColors.border.withOpacity(0.1) : AppColors.border),
          boxShadow: [
            if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 16),
            Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.inter(color: AppColors.neutral500, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, VoidCallback? onSeeAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900)),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: Row(
              children: [
                Text(AppLocalizations.of(context)!.viewAll, style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 10,
      mainAxisSpacing: 12,
      childAspectRatio: 0.8,
      children: [
        _buildActionItem(
          label: AppLocalizations.of(context)!.leads, 
          icon: Icons.hub_rounded, 
          color: AppColors.primary,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeadsPage())),
        ),
        _buildActionItem(
          label: AppLocalizations.of(context)!.invoices, 
          icon: Icons.history_edu_rounded, 
          color: AppColors.success,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoicesPage())),
        ),
        _buildActionItem(
          label: AppLocalizations.of(context)!.automation, 
          icon: Icons.rocket_launch_rounded, 
          color: const Color(0xFF6366F1),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _buildGrowthEngine(context))),
        ),
        _buildActionItem(
          label: AppLocalizations.of(context)!.reports, 
          icon: Icons.query_stats_rounded, 
          color: Colors.orange,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _buildReports(context))),
        ),
      ],
    );
  }

  Widget _buildGrowthEngine(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<LeadCubit>()),
        BlocProvider.value(value: context.read<InvoiceCubit>()),
      ],
      child: const GrowthEnginePage(),
    );
  }

  Widget _buildReports(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<LeadCubit>()),
        BlocProvider.value(value: context.read<InvoiceCubit>()),
      ],
      child: const ReportsPage(),
    );
  }

  Widget _buildActionItem({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentLeads(List<Lead> leads, String currencySymbol) {
    if (leads.isEmpty) return _buildNoData('No recent leads');
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: leads.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final lead = leads[index];
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            width: 150,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(lead.name[0], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
                const Spacer(),
                Text(lead.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 2),
                Text('$currencySymbol${NumberFormat.compact().format(lead.estimatedValue ?? 0)}', style: GoogleFonts.inter(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentInvoices(BuildContext context, List<Invoice> invoices, String currencySymbol) {
    if (invoices.isEmpty) return _buildNoData('No invoices generated');
    return Column(
      children: invoices.map((invoice) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: isDark ? Colors.white10 : AppColors.background, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.receipt_rounded, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(invoice.customerName, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14)),
                    Text(invoice.invoiceNumber, style: GoogleFonts.inter(color: AppColors.neutral500, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$currencySymbol${invoice.total.toStringAsFixed(0)}', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.primary)),
                  const SizedBox(height: 4),
                  _StatusChipSmall(status: invoice.status),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNoData(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AppColors.neutral100.withOpacity(0.05), borderRadius: BorderRadius.circular(24)),
      child: Center(child: Text(message, style: GoogleFonts.inter(color: AppColors.neutral500, fontSize: 13, fontWeight: FontWeight.w600))),
    );
  }
}

class _StatusChipSmall extends StatelessWidget {
  final InvoiceStatus status;
  const _StatusChipSmall({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case InvoiceStatus.paid: color = AppColors.success; break;
      case InvoiceStatus.overdue: color = AppColors.error; break;
      case InvoiceStatus.sent: color = Colors.blue; break;
      default: color = AppColors.neutral500;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(status.name.toUpperCase(), style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }
}
