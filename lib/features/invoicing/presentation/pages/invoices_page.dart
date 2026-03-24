import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:business_automation/core/theme/app_colors.dart';
import 'package:business_automation/features/invoicing/data/models/invoice_model.dart';
import 'package:business_automation/features/invoicing/presentation/cubit/invoice_cubit.dart';
import 'package:business_automation/injection_container.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:business_automation/features/invoicing/presentation/pages/create_invoice_page.dart';
import 'package:business_automation/features/invoicing/presentation/pages/invoice_detail_page.dart';
import 'package:business_automation/features/dashboard/presentation/cubit/settings_cubit.dart';
import 'package:business_automation/features/dashboard/data/models/settings_model.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<InvoiceCubit>()..loadInvoices(),
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settingsState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: _isSearching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Search invoices...',
                        hintStyle: GoogleFonts.inter(color: AppColors.neutral500),
                        border: InputBorder.none,
                      ),
                      onChanged: (query) {
                        context.read<InvoiceCubit>().searchInvoices(query);
                      },
                    )
                  : Text('Invoices', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
              actions: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) {
                        _searchController.clear();
                        context.read<InvoiceCubit>().searchInvoices('');
                      }
                    });
                  },
                  icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, size: 22, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: false,
                    dividerColor: Colors.transparent,
                    indicatorColor: AppColors.primary,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelPadding: EdgeInsets.zero,
                    labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                    unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.neutral500,
                    tabs: const [
                      Tab(text: 'All'),
                      Tab(text: 'Pending'),
                      Tab(text: 'Paid'),
                      Tab(text: 'Overdue'),
                    ],
                  ),
                ),
              ),
            ),
            body: BlocBuilder<InvoiceCubit, InvoiceState>(
              builder: (context, state) {
                if (state is InvoiceLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is InvoiceLoaded) {
                  final invoices = state.filteredInvoices;
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _InvoiceList(invoices: invoices),
                      _InvoiceList(invoices: invoices.where((i) => i.status == InvoiceStatus.sent || i.status == InvoiceStatus.draft).toList()),
                      _InvoiceList(invoices: invoices.where((i) => i.status == InvoiceStatus.paid).toList()),
                      _InvoiceList(invoices: invoices.where((i) => i.status == InvoiceStatus.overdue).toList()),
                    ],
                  );
                }
                return const SizedBox();
              },
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: context.read<InvoiceCubit>(),
                      child: const CreateInvoicePage(),
                    ),
                  ),
                );
              },
              backgroundColor: AppColors.primary,
              elevation: 4,
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            ),
          );
        },
      ),
    );
  }
}

class _InvoiceList extends StatelessWidget {
  final List<Invoice> invoices;

  const _InvoiceList({required this.invoices});

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.neutral500.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text('No invoices found', style: TextStyle(color: AppColors.neutral500, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: invoices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        return _InvoiceCard(invoice: invoice);
      },
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;

  const _InvoiceCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<InvoiceCubit>(),
              child: InvoiceDetailPage(invoiceId: invoice.id),
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.receipt_rounded, color: AppColors.primary, size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(invoice.invoiceNumber, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        invoice.customerName,
                        style: GoogleFonts.inter(color: AppColors.neutral500, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Builder(builder: (context) {
                      final symbol = context.read<SettingsCubit>().state is SettingsLoaded 
                          ? (context.read<SettingsCubit>().state as SettingsLoaded).settings.currencySymbol 
                          : '₹';
                      return Text(
                        '$symbol${invoice.total.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14),
                      );
                    }),
                    const SizedBox(height: 4),
                    _StatusChip(status: invoice.status),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Due: ${DateFormat('dd MMM yyyy').format(invoice.dueDate)}',
                  style: GoogleFonts.inter(color: AppColors.neutral500, fontSize: 11, fontWeight: FontWeight.w500),
                ),
                Row(
                  children: [
                    Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.neutral500.withOpacity(0.5)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final InvoiceStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case InvoiceStatus.draft:
        color = AppColors.neutral500;
        label = 'Draft';
        break;
      case InvoiceStatus.sent:
        color = Colors.blue;
        label = 'Pending';
        break;
      case InvoiceStatus.paid:
        color = AppColors.success;
        label = 'Paid';
        break;
      case InvoiceStatus.overdue:
        color = AppColors.error;
        label = 'Overdue';
        break;
      case InvoiceStatus.cancelled:
        color = AppColors.neutral500;
        label = 'Cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}
