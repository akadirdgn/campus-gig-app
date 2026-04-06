import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Kurumsal ve Minimalist Profesyonel Palet (SaaS / Marketplace standardı)
  static const Color primaryColor = Color(0xFF0F172A); // Deep Slate (Otorite ve Premium hissiyat)
  static const Color secondaryColor = Color(0xFF2563EB); // Royal Blue (Güven ve netlik)
  static const Color accentColor = Color(0xFF10B981); // Emerald Green (Finansal işlemler ve başarı)
  
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color cardColor = Colors.white;

  // Glassmorphism araçları
  static final Color glassBackgroundColor = Colors.white.withOpacity(0.85);
  static final Color glassBorderColor = Colors.white.withOpacity(0.5);

  // Home ekraninda aktif sekmeye gore (marketplace/bounties) temayi paylastirir.
  static final ValueNotifier<String> homeTabNotifier = ValueNotifier<String>('marketplace');

  static bool get isMarketplaceTab => homeTabNotifier.value == 'marketplace';

  static Color get homeAccent => isMarketplaceTab ? const Color(0xFF7CFF6B) : const Color(0xFF4CC9FF);

  static Color get homeAccentSecondary => isMarketplaceTab ? const Color(0xFF1E9D4B) : const Color(0xFF8B5CF6);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: secondaryColor,
      surface: backgroundColor,
    ),
    scaffoldBackgroundColor: backgroundColor,
    textTheme: GoogleFonts.plusJakartaSansTextTheme(),
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        color: const Color(0xFF0F172A), // Slate 900
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
    ),
  );
}
