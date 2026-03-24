import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:business_automation/core/theme/app_colors.dart';
import 'package:business_automation/features/crm/data/models/lead_model.dart';
import 'package:business_automation/features/crm/presentation/cubit/lead_cubit.dart';
import 'package:business_automation/features/crm/presentation/pages/lead_detail_page.dart';
import 'package:business_automation/injection_container.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:business_automation/features/dashboard/presentation/cubit/settings_cubit.dart';
import 'package:business_automation/features/dashboard/data/models/settings_model.dart';
import 'package:business_automation/core/widgets/app_bottom_sheet.dart';
import 'package:business_automation/l10n/app_localizations.dart';

class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> with SingleTickerProviderStateMixin {
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
      create: (context) => sl<LeadCubit>()..loadLeads(),
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settingsState) {
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
                        hintText: AppLocalizations.of(context)!.searchLeads,
                        hintStyle: GoogleFonts.inter(color: AppColors.neutral500),
                        border: InputBorder.none,
                      ),
                      onChanged: (query) {
                        context.read<LeadCubit>().searchLeads(query);
                      },
                    )
                  : Text(AppLocalizations.of(context)!.leadsAndClients, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
              actions: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) {
                        _searchController.clear();
                        context.read<LeadCubit>().searchLeads('');
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
                    tabs: [
                      Tab(text: AppLocalizations.of(context)!.active),
                      Tab(text: AppLocalizations.of(context)!.won),
                      Tab(text: AppLocalizations.of(context)!.lost),
                      Tab(text: AppLocalizations.of(context)!.highValue),
                    ],
                  ),
                ),
              ),
            ),
            body: BlocBuilder<LeadCubit, LeadState>(
              builder: (context, state) {
                if (state is LeadLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is LeadLoaded) {
                  final leads = state.filteredLeads;
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _LeadList(
                        leads: leads.where((l) => 
                          l.status == LeadStatus.newLead || 
                          l.status == LeadStatus.contacted || 
                          l.status == LeadStatus.proposal
                        ).toList(),
                      ),
                      _LeadList(leads: leads.where((l) => l.status == LeadStatus.won).toList()),
                      _LeadList(leads: leads.where((l) => l.status == LeadStatus.lost).toList()),
                      _LeadList(leads: leads.where((l) => (l.estimatedValue ?? 0) >= 50000).toList()),
                    ],
                  );
                }
                return const SizedBox();
              },
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => showLeadDialog(context),
              backgroundColor: AppColors.primary,
              elevation: 4,
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            ),
          );
        },
      ),
    );
  }

  void showLeadDialog(BuildContext context, {Lead? lead}) {
    final nameController = TextEditingController(text: lead?.name);
    final valueController = TextEditingController(text: lead?.estimatedValue?.toString());
    final phoneController = TextEditingController(text: lead?.phone);
    final emailController = TextEditingController(text: lead?.email);
    final notesController = TextEditingController(text: lead?.notes);
    final leadCubit = context.read<LeadCubit>();
    final formKey = GlobalKey<FormState>();

    AppBottomSheet.show(
      context: context,
      title: lead == null ? AppLocalizations.of(context)!.newBusinessLead : AppLocalizations.of(context)!.updateLead,
      children: [
        Form(
          key: formKey,
          child: Column(
            children: [
              _buildDialogField(context, nameController, AppLocalizations.of(context)!.customerName, Icons.person_rounded, validator: (v) => v == null || v.trim().isEmpty ? AppLocalizations.of(context)!.customerNameRequired : null),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildDialogField(context, phoneController, AppLocalizations.of(context)!.phone, Icons.phone_rounded, keyboardType: TextInputType.phone)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final symbol = context.read<SettingsCubit>().state is SettingsLoaded 
                            ? (context.read<SettingsCubit>().state as SettingsLoaded).settings.currencySymbol 
                            : '₹';
                        return _buildDialogField(context, valueController, '${AppLocalizations.of(context)!.value} ($symbol)', Icons.currency_rupee_rounded, keyboardType: TextInputType.number);
                      }
                    )
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDialogField(context, emailController, AppLocalizations.of(context)!.email, Icons.email_rounded, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildDialogField(context, notesController, AppLocalizations.of(context)!.notes, Icons.notes_rounded, maxLines: 3),
              const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        final updatedLead = lead ?? Lead();
                        updatedLead.name = nameController.text;
                        updatedLead.phone = phoneController.text;
                        updatedLead.email = emailController.text;
                        updatedLead.notes = notesController.text;
                        updatedLead.estimatedValue = double.tryParse(valueController.text);
                        
                        if (lead == null) {
                          updatedLead.status = LeadStatus.newLead;
                          updatedLead.createdAt = DateTime.now();
                          await leadCubit.addLead(updatedLead);
                        } else {
                          await leadCubit.updateLead(updatedLead);
                        }
                        
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(lead == null ? AppLocalizations.of(context)!.leadCaptured : AppLocalizations.of(context)!.leadUpdated)),
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
                    child: Text(
                      lead == null ? AppLocalizations.of(context)!.captureLead : AppLocalizations.of(context)!.saveChanges,
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
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

class _LeadList extends StatelessWidget {
  final List<Lead> leads;

  const _LeadList({required this.leads});

  @override
  Widget build(BuildContext context) {
    if (leads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded, size: 48, color: AppColors.neutral500.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.noLeadsFound, style: const TextStyle(color: AppColors.neutral500, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: leads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final lead = leads[index];
        return _LeadCard(lead: lead);
      },
    );
  }
}

class _LeadCard extends StatelessWidget {
  final Lead lead;

  const _LeadCard({required this.lead});

  Future<void> _launchWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final url = 'https://wa.me/$cleanPhone';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchCall(String phone) async {
    final url = 'tel:$phone';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _showStatusBottomSheet(BuildContext context) {
    final leadCubit = context.read<LeadCubit>();
    AppBottomSheet.show(
      context: context,
      title: AppLocalizations.of(context)!.updateStatus,
      children: LeadStatus.values.map((status) => AppBottomSheet.buildOptionTile(
        context: context,
        title: _getStatusLabel(context, status),
        isSelected: lead.status == status,
        onTap: () {
          leadCubit.updateLeadStatus(lead, status);
          Navigator.pop(context);
        },
      )).toList(),
    );
  }

  String _getStatusLabel(BuildContext context, LeadStatus status) {
    switch (status) {
      case LeadStatus.newLead: return AppLocalizations.of(context)!.newStatus;
      case LeadStatus.contacted: return AppLocalizations.of(context)!.interestedStatus;
      case LeadStatus.proposal: return AppLocalizations.of(context)!.proposalStatus;
      case LeadStatus.won: return AppLocalizations.of(context)!.won;
      case LeadStatus.lost: return AppLocalizations.of(context)!.lost;
    }
  }

  void showDeleteConfirm(BuildContext context, Lead lead) {
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
              Text(AppLocalizations.of(context)!.removeLead, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.areYouSureDeleteLead(lead.name),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppColors.neutral500, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(AppLocalizations.of(context)!.cancel, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.neutral500)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        context.read<LeadCubit>().deleteLead(lead.id);
                        Navigator.pop(dialogContext);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(AppLocalizations.of(context)!.delete, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<LeadCubit>(),
              child: LeadDetailPage(lead: lead),
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
                  child: Center(
                    child: Text(
                      lead.name[0].toUpperCase(),
                      style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lead.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        lead.phone ?? 'No phone',
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
                      return Text('$symbol${lead.estimatedValue?.toStringAsFixed(0) ?? '0'}', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14));
                    }),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _showStatusBottomSheet(context),
                      child: _StatusChip(status: lead.status),
                    ),
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
                Row(
                  children: [
                    _QuickAction(
                      icon: Icons.phone_rounded,
                      color: AppColors.primary,
                      onTap: () => lead.phone != null ? _launchCall(lead.phone!) : null,
                    ),
                    const SizedBox(width: 12),
                    _QuickAction(
                      icon: Icons.message_rounded,
                      color: const Color(0xFF25D366),
                      onTap: () => lead.phone != null ? _launchWhatsApp(lead.phone!) : null,
                    ),
                  ],
                ),
                Row(
                  children: [
                   IconButton(
                      icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                      onPressed: () => _editLead(context),
                    ),
                   IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                      onPressed: () => showDeleteConfirm(context, lead),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _editLead(BuildContext context) {
    final state = context.findAncestorStateOfType<_LeadsPageState>();
    state?.showLeadDialog(context, lead: lead);
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
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
