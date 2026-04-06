import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class SecurityResult {
  final bool hasWarning;
  final List<String> matchedPatterns;
  final String? warningMessage;

  const SecurityResult({
    required this.hasWarning,
    this.matchedPatterns = const [],
    this.warningMessage,
  });
}

class ChatSecurityUtil {
  // Regex for Turkish Phone Numbers (e.g., 0555 555 55 55, +905555555555, 5555555555)
  static final RegExp _phoneRegex = RegExp(
    r'(\+90|0)?\s*5\d{2}\s*\d{3}\s*\d{2}\s*\d{2}',
    caseSensitive: false,
  );

  // Regex for IBAN (TR followed by 24 digits, with optional spaces)
  static final RegExp _ibanRegex = RegExp(
    r'TR\d{2}\s*(\d{4}\s*){5}\d{2}',
    caseSensitive: false,
  );

  // High-risk keywords for off-platform communication / payments
  static const List<String> _restrictedKeywords = [
    'havale',
    'eft',
    'elden',
    'nakit',
    'iban',
    'papara',
    'hesap no',
    'hesap numarası',
    'numaram',
    'whatsapp',
    'wp',
    'insta',
    'instagram',
    'telegram'
  ];

  /// Analyzes the message content for any security risks (phone numbers, IBANs, restricted keywords).
  static SecurityResult analyzeMessage(String text) {
    if (text.isEmpty) return const SecurityResult(hasWarning: false);

    final String lowerText = text.toLowerCase();
    final List<String> matches = [];

    // Check Phone Numbers
    if (_phoneRegex.hasMatch(text)) {
      matches.add('Telefon Numarası');
    }

    // Check IBAN
    if (_ibanRegex.hasMatch(text)) {
      matches.add('IBAN');
    }

    // Check Keywords
    for (final keyword in _restrictedKeywords) {
      // Using word boundary check to avoid matching parts of words (custom logic for Turkish)
      final RegExp wordRegex = RegExp(r'\b' + RegExp.escape(keyword) + r'\b', caseSensitive: false);
      if (wordRegex.hasMatch(lowerText)) {
        matches.add(keyword);
      }
    }

    if (matches.isNotEmpty) {
      return SecurityResult(
        hasWarning: true,
        matchedPatterns: matches,
        warningMessage: 'Güvenliğiniz için ödemeleri sadece platform üzerinden yapın. Platform dışı işlemlerde escrow (güvenli ödeme) korumasından faydalanamazsınız!',
      );
    }

    return const SecurityResult(hasWarning: false);
  }

  /// Shows a standard warning dialog if a security risk is detected before sending a message.
  static Future<bool> showSecurityWarning(BuildContext context, SecurityResult result) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Güvenlik Uyarısı', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.warningMessage ?? '',
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Tespit Edilen İfadeler: ${result.matchedPatterns.join(", ")}',
              style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Yine de Gönder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;
  }
}
