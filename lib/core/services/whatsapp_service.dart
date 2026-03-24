import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  static Future<void> sendMessage({required String phone, required String message}) async {
    // Sanitize phone number (remove +, spaces, etc.)
    final sanitizedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final url = 'https://wa.me/$sanitizedPhone?text=${Uri.encodeComponent(message)}';
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  static String getLeadGreetingTemplate(String name, String businessName) {
    return 'Hi $name, thank you for reaching out! This is $businessName. How can we help you today?';
  }

  static String getInvoiceReminderTemplate(String invoiceNo, double amount, String businessName) {
    return 'Hi, this is a friendly reminder from $businessName regarding Invoice #$invoiceNo for ₹${amount.toStringAsFixed(2)}. You can pay via the link provided. Thank you!';
  }
}
