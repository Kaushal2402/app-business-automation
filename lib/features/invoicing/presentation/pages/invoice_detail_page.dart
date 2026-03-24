import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:business_automation/core/theme/app_colors.dart';
import 'package:business_automation/features/invoicing/data/models/invoice_model.dart';
import 'package:business_automation/features/invoicing/presentation/cubit/invoice_cubit.dart';
import 'package:business_automation/features/invoicing/presentation/pages/create_invoice_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:business_automation/core/services/whatsapp_service.dart';
import 'package:business_automation/core/services/notification_service.dart';
import 'package:business_automation/injection_container.dart';
import 'package:business_automation/features/dashboard/presentation/cubit/settings_cubit.dart';
import 'package:business_automation/core/widgets/app_bottom_sheet.dart';
import 'package:business_automation/core/services/pdf_invoice_service.dart';
import 'package:printing/printing.dart';
import 'dart:io';

class InvoiceDetailPage extends StatelessWidget {
  final int invoiceId;

  const InvoiceDetailPage({super.key, required this.invoiceId});

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
            leading: BackButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                Navigator.pop(context);
              },
            ),
            title: BlocBuilder<InvoiceCubit, InvoiceState>(
              buildWhen: (p, c) => c is InvoiceLoaded,
              builder: (context, state) {
                if (state is InvoiceLoaded) {
                  final invoice = state.invoices.firstWhere((i) => i.id == invoiceId, orElse: () => Invoice());
                  return Text(invoice.invoiceNumber.isEmpty ? 'Invoice Detail' : invoice.invoiceNumber, 
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18));
                }
                return Text('Invoice Detail', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18));
              },
            ),
            actions: [
              BlocBuilder<InvoiceCubit, InvoiceState>(
                buildWhen: (p, c) => c is InvoiceLoaded,
                builder: (context, state) {
                  if (state is InvoiceLoaded) {
                    final invoice = state.invoices.firstWhere((i) => i.id == invoiceId, orElse: () => Invoice());
                    if (invoice.id != 0) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () async {
                              final st = settingsState;
                              if (st is SettingsLoaded) {
                                final pdfBytes = await PdfInvoiceService.generate(invoice, st.settings);
                                await Printing.layoutPdf(onLayout: (format) => pdfBytes);
                              }
                            },
                            icon: const Icon(Icons.print_rounded, color: AppColors.neutral900),
                          ),
                          IconButton(
                            onPressed: () async {
                              final st = settingsState;
                              if (st is SettingsLoaded) {
                                final pdfBytes = await PdfInvoiceService.generate(invoice, st.settings);
                                await Printing.sharePdf(bytes: pdfBytes, filename: 'invoice_${invoice.invoiceNumber}.pdf');
                              }
                            },
                            icon: const Icon(Icons.share_rounded, color: AppColors.primary),
                          ),
                          IconButton(
                            onPressed: () => _showDeleteDialog(context, invoice),
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                          ),
                        ],
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: BlocBuilder<InvoiceCubit, InvoiceState>(
            builder: (context, state) {
              if (state is InvoiceLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is! InvoiceLoaded) {
                return const Center(child: Text('Error loading invoice'));
              }

              final invoice = state.invoices.firstWhere((i) => i.id == invoiceId, orElse: () => Invoice());
              if (invoice.id == 0) {
                return const Center(child: Text('Invoice not found or deleted'));
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Header
                    _buildStatusHeader(invoice),
                    const SizedBox(height: 24),

                    // Business Info (FROM)
                    if (settingsState is SettingsLoaded && settingsState.settings.businessName.isNotEmpty) ...[
                      _buildInfoSection(context, 'FROM', [
                        Row(
                          children: [
                            if (settingsState.settings.businessLogoPath.isNotEmpty) ...[
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: FileImage(File(settingsState.settings.businessLogoPath)),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(settingsState.settings.businessName, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15)),
                                  if (settingsState.settings.businessTaxNumber.isNotEmpty)
                                    Text('Tax No: ${settingsState.settings.businessTaxNumber}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.neutral500)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (settingsState.settings.businessAddress.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          _buildInfoRow('Address', settingsState.settings.businessAddress),
                        ],
                        if (settingsState.settings.businessPhone.isNotEmpty)
                          _buildInfoRow('Phone', settingsState.settings.businessPhone),
                        if (settingsState.settings.businessEmail.isNotEmpty)
                          _buildInfoRow('Email', settingsState.settings.businessEmail),
                      ]),
                      const SizedBox(height: 24),
                    ],

                    // Billing Info
                    _buildInfoSection(context, 'BILLED TO', [
                      _buildInfoRow('Name', invoice.customerName),
                      if (invoice.customerPhone != null && invoice.customerPhone!.isNotEmpty)
                        _buildInfoRow('Phone', invoice.customerPhone!),
                      if (invoice.customerEmail != null && invoice.customerEmail!.isNotEmpty)
                        _buildInfoRow('Email', invoice.customerEmail!),
                    ]),
                    const SizedBox(height: 24),

                    _buildInfoSection(context, 'DATES', [
                      _buildInfoRow('Invoice Date', DateFormat('dd MMM yyyy').format(invoice.date)),
                      _buildInfoRow('Due Date', DateFormat('dd MMM yyyy').format(invoice.dueDate)),
                    ]),
                    const SizedBox(height: 32),

                    // Item List
                    _buildSectionTitle('ITEMS'),
                    const SizedBox(height: 12),
                    ...invoice.items.map((item) => _buildItemTile(context, item, symbol)),
                    const Divider(height: 32),

                    // Summary
                    _buildSummaryRow(context, 'Subtotal', '$symbol${invoice.subtotal.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    _buildSummaryRow(context, 'Item Tax Total', '$symbol${(invoice.items.fold(0.0, (sum, i) => sum + i.taxAmount)).toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    _buildSummaryRow(context, 'Overall Tax (${invoice.taxRate}%)', '$symbol${invoice.taxAmount.toStringAsFixed(2)}'),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1, thickness: 1.5, color: isDark ? Colors.white10 : AppColors.border),
                    ),
                    _buildSummaryRow(context, 'TOTAL AMOUNT', '$symbol${invoice.total.toStringAsFixed(2)}', isGrandTotal: true),
                    
                    if (invoice.nextReminder != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.alarm_on_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Next Reminder: ${DateFormat('dd MMM, hh:mm a').format(invoice.nextReminder!)}',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      _buildSectionTitle('NOTES'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(invoice.notes!, style: GoogleFonts.inter(height: 1.5, fontSize: 13, color: AppColors.neutral500)),
                      ),
                    ],
                    const SizedBox(height: 48),
                    
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider.value(
                                    value: context.read<InvoiceCubit>(),
                                    child: CreateInvoicePage(invoice: invoice),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: const Text('Edit Invoice'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: AppColors.primary),
                              foregroundColor: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showStatusBottomSheet(context, invoice),
                            icon: const Icon(Icons.sync_rounded, size: 18),
                            label: const Text('Update Status'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _shareInvoice(invoice, symbol),
                            icon: const Icon(Icons.share_rounded, size: 18),
                            label: const Text('Share'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _scheduleReminder(context, invoice, symbol),
                            icon: const Icon(Icons.alarm_add_rounded, size: 18),
                            label: const Text('Remind'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: AppColors.neutral500),
                              foregroundColor: AppColors.neutral500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatusHeader(Invoice invoice) {
    Color color;
    String label;
    IconData icon;

    switch (invoice.status) {
      case InvoiceStatus.paid:
        color = AppColors.success;
        label = 'Paid';
        icon = Icons.check_circle_rounded;
        break;
      case InvoiceStatus.overdue:
        color = AppColors.error;
        label = 'Overdue';
        icon = Icons.warning_rounded;
        break;
      case InvoiceStatus.sent:
        color = Colors.blue;
        label = 'Sent';
        icon = Icons.send_rounded;
        break;
      case InvoiceStatus.cancelled:
        color = AppColors.neutral500;
        label = 'Cancelled';
        icon = Icons.cancel_rounded;
        break;
      default:
        color = AppColors.neutral500;
        label = 'Draft';
        icon = Icons.edit_document;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: GoogleFonts.inter(letterSpacing: 1.2, fontSize: 11, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 4),
              Text('Invoice Status', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: GoogleFonts.inter(letterSpacing: 1.2, fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.neutral500));
  }

  Widget _buildInfoSection(BuildContext context, String title, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.neutral500, fontWeight: FontWeight.w500)),
          Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildItemTile(BuildContext context, InvoiceItem item, String symbol) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.description_outlined, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.description ?? 'Untitled', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text('${item.quantity} x $symbol${item.unitPrice}', style: GoogleFonts.inter(color: AppColors.neutral500, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$symbol${item.total.toStringAsFixed(2)}', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
              if (item.taxAmount > 0)
                Text('Tax Incl.', style: GoogleFonts.inter(color: Colors.blueGrey, fontSize: 9, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value, {bool isGrandTotal = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: isGrandTotal ? (isDark ? Colors.white : Colors.black) : AppColors.neutral500, fontSize: isGrandTotal ? 14 : 12, fontWeight: isGrandTotal ? FontWeight.w800 : FontWeight.w500)),
        Text(value, style: GoogleFonts.inter(color: isGrandTotal ? AppColors.primary : (isDark ? Colors.white : Colors.black), fontSize: isGrandTotal ? 20 : 13, fontWeight: isGrandTotal ? FontWeight.w900 : FontWeight.w700)),
      ],
    );
  }

  void _showStatusBottomSheet(BuildContext context, Invoice invoice) {
    final cubit = context.read<InvoiceCubit>();
    AppBottomSheet.show(
      context: context,
      title: 'Update Status',
      children: [
        AppBottomSheet.buildOptionTile(
          context: context,
          title: 'Draft',
          icon: Icons.edit_document,
          isSelected: invoice.status == InvoiceStatus.draft,
          onTap: () => _updateStatus(context, cubit, invoice, InvoiceStatus.draft),
        ),
        AppBottomSheet.buildOptionTile(
          context: context,
          title: 'Sent',
          icon: Icons.send_rounded,
          isSelected: invoice.status == InvoiceStatus.sent,
          onTap: () => _updateStatus(context, cubit, invoice, InvoiceStatus.sent),
        ),
        AppBottomSheet.buildOptionTile(
          context: context,
          title: 'Paid',
          icon: Icons.check_circle_outline_rounded,
          isSelected: invoice.status == InvoiceStatus.paid,
          onTap: () => _updateStatus(context, cubit, invoice, InvoiceStatus.paid),
        ),
        AppBottomSheet.buildOptionTile(
          context: context,
          title: 'Overdue',
          icon: Icons.warning_amber_rounded,
          isSelected: invoice.status == InvoiceStatus.overdue,
          onTap: () => _updateStatus(context, cubit, invoice, InvoiceStatus.overdue),
        ),
        AppBottomSheet.buildOptionTile(
          context: context,
          title: 'Cancelled',
          icon: Icons.cancel_outlined,
          isSelected: invoice.status == InvoiceStatus.cancelled,
          onTap: () => _updateStatus(context, cubit, invoice, InvoiceStatus.cancelled),
        ),
      ],
    );
  }

  void _updateStatus(BuildContext context, InvoiceCubit cubit, Invoice invoice, InvoiceStatus newStatus) async {
    final updated = invoice..status = newStatus;
    await cubit.updateInvoice(updated);
    if (context.mounted) {
       Navigator.pop(context); // Close bottom sheet
    }
  }

  void _shareInvoice(Invoice invoice, String symbol) {
    String itemsText = invoice.items.map((i) => '- ${i.description}: $symbol${i.total.toStringAsFixed(2)}').join('\n');
    String shareText = '''
📄 *Invoice: ${invoice.invoiceNumber}*
📅 Date: ${DateFormat('dd MMM yyyy').format(invoice.date)}
👤 Client: ${invoice.customerName}

*Items:*
$itemsText

*Summary:*
Subtotal: $symbol${invoice.subtotal.toStringAsFixed(2)}
Total Tax: $symbol${(invoice.taxAmount + invoice.items.fold(0.0, (sum, i) => sum + i.taxAmount)).toStringAsFixed(2)}
*Grand Total: $symbol${invoice.total.toStringAsFixed(2)}*

Thank you for your business!
''';
    Share.share(shareText);
  }

  void _showDeleteDialog(BuildContext context, Invoice invoice) {
    final cubit = context.read<InvoiceCubit>();
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 32),
              ),
              const SizedBox(height: 20),
              Text('Delete Invoice?', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete invoice ${invoice.invoiceNumber}?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppColors.neutral500, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.neutral500)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await cubit.deleteInvoice(invoice.id);
                        if (context.mounted) {
                          Navigator.pop(dialogContext); // Close dialog
                          Navigator.pop(context); // Close detail page
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scheduleReminder(BuildContext context, Invoice invoice, String symbol) async {
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
          id: -invoice.id, // Use negative ID to avoid conflicts with leads
          title: 'Payment Reminder: ${invoice.invoiceNumber}',
          body: 'Time to follow up with ${invoice.customerName} for $symbol${invoice.total.toStringAsFixed(2)}',
          scheduledDate: scheduledDateTime,
        );

        // Update invoice in DB
        if (context.mounted) {
          final updatedInvoice = invoice..nextReminder = scheduledDateTime;
          context.read<InvoiceCubit>().updateInvoice(updatedInvoice);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment reminder scheduled for ${DateFormat('dd MMM, hh:mm a').format(scheduledDateTime)}'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    }
  }
}

class _StatusOption extends StatelessWidget {
  final InvoiceStatus status;
  final InvoiceStatus current;
  final VoidCallback onSelect;

  const _StatusOption({required this.status, required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isSelected = status == current;
    String label;
    IconData icon;
    Color color;

    switch (status) {
      case InvoiceStatus.paid:
        label = 'Mark as Paid';
        icon = Icons.check_circle_outline_rounded;
        color = AppColors.success;
        break;
      case InvoiceStatus.sent:
        label = 'Mark as Sent';
        icon = Icons.send_rounded;
        color = Colors.blue;
        break;
      case InvoiceStatus.overdue:
        label = 'Mark as Overdue';
        icon = Icons.warning_amber_rounded;
        color = AppColors.error;
        break;
      case InvoiceStatus.cancelled:
        label = 'Mark as Cancelled';
        icon = Icons.cancel_outlined;
        color = AppColors.neutral500;
        break;
      default:
        label = 'Reset to Draft';
        icon = Icons.edit_document;
        color = AppColors.neutral500;
    }

    return InkWell(
      onTap: onSelect,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : AppColors.neutral500, size: 22),
            const SizedBox(width: 16),
            Text(label, style: GoogleFonts.inter(fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, color: isSelected ? color : Colors.black87)),
            const Spacer(),
            if (isSelected) Icon(Icons.check_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
