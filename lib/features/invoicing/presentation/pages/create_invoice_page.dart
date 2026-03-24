import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:business_automation/core/theme/app_colors.dart';
import 'package:business_automation/features/invoicing/data/models/invoice_model.dart';
import 'package:business_automation/features/invoicing/presentation/cubit/invoice_cubit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:business_automation/features/dashboard/presentation/cubit/settings_cubit.dart';
import 'package:business_automation/features/dashboard/data/models/settings_model.dart';

class ItemControllerGroup {
  final TextEditingController desc;
  final TextEditingController qty;
  final TextEditingController price;
  final TextEditingController tax;

  ItemControllerGroup({
    required String initialDesc,
    required int initialQty,
    required double initialPrice,
    required double initialTax,
  })  : desc = TextEditingController(text: initialDesc),
        qty = TextEditingController(text: initialQty == 0 ? '' : initialQty.toString()),
        price = TextEditingController(text: initialPrice == 0 ? '' : initialPrice.toString()),
        tax = TextEditingController(text: initialTax == 0 ? '' : initialTax.toString());

  void dispose() {
    desc.dispose();
    qty.dispose();
    price.dispose();
    tax.dispose();
  }
}

class CreateInvoicePage extends StatefulWidget {
  final Invoice? invoice;

  const CreateInvoicePage({super.key, this.invoice});

  @override
  State<CreateInvoicePage> createState() => _CreateInvoicePageState();
}

class _CreateInvoicePageState extends State<CreateInvoicePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  late TextEditingController _overallTaxRateController;

  DateTime _date = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  final List<ItemControllerGroup> _itemControllers = [];
  String _invoiceNumber = '';

  @override
  void initState() {
    super.initState();
    
    // Initialize overall tax rate from settings or existing invoice
    double initialTax = 0;
    if (widget.invoice != null) {
      initialTax = widget.invoice!.taxRate;
    } else {
      final settingsState = context.read<SettingsCubit>().state;
      if (settingsState is SettingsLoaded) {
        initialTax = settingsState.settings.defaultTaxRate;
      }
    }
    _overallTaxRateController = TextEditingController(text: initialTax.toString());

    if (widget.invoice != null) {
      _nameController.text = widget.invoice!.customerName;
      _emailController.text = widget.invoice!.customerEmail ?? '';
      _phoneController.text = widget.invoice!.customerPhone ?? '';
      _addressController.text = widget.invoice!.customerAddress ?? '';
      _notesController.text = widget.invoice!.notes ?? '';
      _date = widget.invoice!.date;
      _dueDate = widget.invoice!.dueDate;
      _invoiceNumber = widget.invoice!.invoiceNumber;

      for (var item in widget.invoice!.items) {
        _itemControllers.add(ItemControllerGroup(
          initialDesc: item.description ?? '',
          initialQty: item.quantity,
          initialPrice: item.unitPrice,
          initialTax: item.taxRate,
        ));
      }
    } else {
      _loadNextInvoiceNumber();
      _addNewItem();
    }
  }

  void _addNewItem() {
    setState(() {
      _itemControllers.add(ItemControllerGroup(
        initialDesc: '',
        initialQty: 1,
        initialPrice: 0,
        initialTax: 0,
      ));
    });
  }

  @override
  void dispose() {
    for (var controller in _itemControllers) {
      controller.dispose();
    }
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _overallTaxRateController.dispose();
    super.dispose();
  }

  Future<void> _loadNextInvoiceNumber() async {
    final num = await context.read<InvoiceCubit>().getNextInvoiceNumber();
    setState(() => _invoiceNumber = num);
  }

  double get _subtotal {
    double total = 0;
    for (var group in _itemControllers) {
      final qty = int.tryParse(group.qty.text) ?? 0;
      final price = double.tryParse(group.price.text) ?? 0;
      total += qty * price;
    }
    return total;
  }

  double get _itemTaxTotal {
    double totalTax = 0;
    for (var group in _itemControllers) {
      final qty = int.tryParse(group.qty.text) ?? 0;
      final price = double.tryParse(group.price.text) ?? 0;
      final taxRate = double.tryParse(group.tax.text) ?? 0;
      totalTax += (qty * price) * (taxRate / 100);
    }
    return totalTax;
  }

  double get _overallTaxAmount {
    final rate = double.tryParse(_overallTaxRateController.text) ?? 0;
    return (_subtotal + _itemTaxTotal) * (rate / 100);
  }

  double get _total {
    return _subtotal + _itemTaxTotal + _overallTaxAmount;
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
            leading: BackButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                Future.delayed(const Duration(milliseconds: 50), () {
                  if (context.mounted) Navigator.pop(context);
                });
              },
            ),
            title: Text(widget.invoice == null ? 'Generate Invoice' : 'Edit Invoice', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ElevatedButton(
                  onPressed: _saveInvoice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Info Card
                  _buildHeaderCard(),
                  const SizedBox(height: 32),
                  
                  // Customer Section
                  _buildSectionTitle('CLIENT DETAILS'),
                  const SizedBox(height: 12),
                  _buildCustomerCard(),
                  const SizedBox(height: 32),
                  
                  // Items Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('LINE ITEMS'),
                      TextButton.icon(
                        onPressed: _addNewItem,
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                        label: const Text('Add Item'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._buildItemRows(symbol),
                  const SizedBox(height: 32),

                  // Summary Section
                  _buildSectionTitle('BILLING SUMMARY'),
                  const SizedBox(height: 12),
                  _buildSummaryCard(symbol),
                  const SizedBox(height: 32),
                  
                  // Notes
                  _buildSectionTitle('NOTES & TERMS'),
                  const SizedBox(height: 12),
                  _buildNotesSection(),
                  const SizedBox(height: 40),

                  // Primary Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _saveInvoice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                        shadowColor: AppColors.primary.withOpacity(0.3),
                      ),
                      child: Text('Generate & Save Invoice', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: GoogleFonts.inter(letterSpacing: 1.2, fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.neutral500));
  }

  Widget _buildHeaderCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildMiniField('Invoice No.', value: _invoiceNumber, enabled: false),
              const SizedBox(width: 16),
              _buildMiniField('Status', value: 'DRAFT', enabled: false, color: Colors.blue),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildDatePicker('Bill Date', _date, (d) => setState(() => _date = d))),
              const SizedBox(width: 16),
              Expanded(child: _buildDatePicker('Due Date', _dueDate, (d) => setState(() => _dueDate = d), isOverdue: _dueDate.isBefore(DateTime.now()))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniField(String label, {required String value, bool enabled = true, Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.neutral500, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
            ),
            child: Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime date, Function(DateTime) onSelect, {bool isOverdue = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (d != null) onSelect(d);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.neutral500, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isOverdue ? AppColors.error.withOpacity(0.5) : (isDark ? Colors.white10 : AppColors.border)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: isOverdue ? AppColors.error : AppColors.primary),
                const SizedBox(width: 10),
                Text(DateFormat('dd-MM-yyyy').format(date), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
      ),
      child: Column(
        children: [
          _buildPremiumTextField(_nameController, 'Customer Name *', Icons.person_outline_rounded, validator: (v) => v?.isEmpty ?? true ? 'Enter customer name' : null),
          const SizedBox(height: 16),
          _buildPremiumTextField(_phoneController, 'Phone Number', Icons.phone_outlined, keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          _buildPremiumTextField(_emailController, 'Email Address', Icons.alternate_email_rounded, keyboardType: TextInputType.emailAddress),
        ],
      ),
    );
  }

  List<Widget> _buildItemRows(String symbol) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return List.generate(_itemControllers.length, (index) {
      final group = _itemControllers[index];
      final qty = int.tryParse(group.qty.text) ?? 0;
      final price = double.tryParse(group.price.text) ?? 0;
      final taxRate = double.tryParse(group.tax.text) ?? 0;
      
      final netTotal = qty * price;
      final lineTax = netTotal * (taxRate / 100);
      final grossTotal = netTotal + lineTax;

      return Container(
        key: ValueKey(group.hashCode),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: group.desc,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                    decoration: const InputDecoration(hintText: 'Work description...', border: InputBorder.none),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    setState(() {
                      if (_itemControllers.length > 1) {
                        _itemControllers[index].dispose();
                        _itemControllers.removeAt(index);
                      }
                    });
                  },
                  icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.error, size: 20),
                ),
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildItemInput('Qty', group.qty, isInteger: true),
                const SizedBox(width: 12),
                _buildItemInput('Price', group.price, prefix: symbol),
                const SizedBox(width: 12),
                _buildItemInput('Tax %', group.tax, suffix: '%'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tax Amount', style: GoogleFonts.inter(fontSize: 10, color: AppColors.neutral500, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('$symbol${lineTax.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Line Total (Inc. Tax)', style: GoogleFonts.inter(fontSize: 10, color: AppColors.neutral500, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('$symbol${grossTotal.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildItemInput(String label, TextEditingController controller, {String? prefix, String? suffix, bool isInteger = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.neutral500)),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                prefixText: prefix,
                suffixText: suffix,
                prefixStyle: GoogleFonts.inter(),
                suffixStyle: GoogleFonts.inter(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String symbol) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildSummaryLine('Subtotal', '$symbol${_subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 12),
          _buildSummaryLine('Item-wise Tax total', '$symbol${_itemTaxTotal.toStringAsFixed(2)}'),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Overall Tax (%)', style: GoogleFonts.inter(fontSize: 13, color: AppColors.neutral500, fontWeight: FontWeight.w500)),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _overallTaxRateController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none, suffixText: '%'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryLine('Overall Tax Amount', '$symbol${_overallTaxAmount.toStringAsFixed(2)}', color: Colors.blueGrey),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, thickness: 1.5),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('GRAND TOTAL', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900)),
              Text('$symbol${_total.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppColors.neutral500, fontWeight: FontWeight.w500)),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _buildNotesSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.sticky_note_2_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Invoice Notes', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          _buildPremiumTextField(_notesController, 'Add any payment terms or notes...', null, maxLines: 4, isFrameless: true),
        ],
      ),
    );
  }

  Widget _buildPremiumTextField(TextEditingController controller, String hint, IconData? icon, {TextInputType keyboardType = TextInputType.text, int maxLines = 1, String? Function(String?)? validator, bool isFrameless = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: AppColors.neutral500, fontSize: 13, fontWeight: FontWeight.w400),
        prefixIcon: icon != null ? Icon(icon, size: 20, color: AppColors.primary.withOpacity(0.7)) : null,
        filled: !isFrameless,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : AppColors.background,
        border: isFrameless ? InputBorder.none : OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _saveInvoice() async {
    if (_formKey.currentState!.validate()) {
      final isUpdate = widget.invoice != null;
      final invoice = widget.invoice ?? Invoice();
      
      invoice.invoiceNumber = _invoiceNumber;
      invoice.customerName = _nameController.text;
      invoice.customerPhone = _phoneController.text;
      invoice.customerEmail = _emailController.text;
      invoice.customerAddress = _addressController.text;
      invoice.notes = _notesController.text;
      invoice.date = _date;
      invoice.dueDate = _dueDate;
      
      invoice.items = _itemControllers.map((group) {
        final item = InvoiceItem();
        item.description = group.desc.text;
        item.quantity = int.tryParse(group.qty.text) ?? 0;
        item.unitPrice = double.tryParse(group.price.text) ?? 0;
        item.taxRate = double.tryParse(group.tax.text) ?? 0;
        item.taxAmount = (item.quantity * item.unitPrice) * (item.taxRate / 100);
        item.total = (item.quantity * item.unitPrice) + item.taxAmount;
        return item;
      }).toList();

      invoice.subtotal = _subtotal;
      invoice.taxRate = double.tryParse(_overallTaxRateController.text) ?? 0;
      invoice.taxAmount = _overallTaxAmount;
      invoice.total = _total;
      
      if (!isUpdate) {
        invoice.status = InvoiceStatus.draft;
      }

      final cubit = context.read<InvoiceCubit>();
      if (isUpdate) {
        await cubit.updateInvoice(invoice);
      } else {
        await cubit.addInvoice(invoice);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
}
