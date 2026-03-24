import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:business_automation/core/theme/app_colors.dart';

class AppBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<Widget> children,
    Widget? action,
    bool isScrollControlled = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white12 : AppColors.neutral100,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 20, 
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (action != null) action else IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? Colors.white12 : AppColors.background,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  static Widget buildOptionTile({
    required BuildContext context,
    required String title,
    bool isSelected = false,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: icon != null ? Icon(icon, color: isSelected ? AppColors.primary : AppColors.neutral500) : null,
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? AppColors.primary : (isDark ? Colors.white : Colors.black),
        ),
      ),
      trailing: isSelected 
          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20) 
          : null,
      tileColor: isSelected ? AppColors.primary.withOpacity(0.05) : null,
    );
  }
}
