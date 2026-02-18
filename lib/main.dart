import 'package:flutter/material.dart';
import 'package:night_walkers_app/screens/homescreen.dart';
import 'package:night_walkers_app/screens/onboarding_screen.dart';
import 'package:night_walkers_app/services/direct_sms_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DirectSmsService.initializeVolumeTriggerListener();
  // Global fallback error screen.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    bool inDebug = false;
    assert(() {
      inDebug = true;
      return true;
    }());
    if (inDebug) {
      return ErrorWidget(details.exception);
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong. Please restart the app.',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  };
  final prefs = await SharedPreferences.getInstance();
  final showOnboarding = prefs.getBool('showOnboarding') ?? true;
  final backgroundModeEnabled = prefs.getBool('background_mode_enabled') ?? false;
  if (backgroundModeEnabled) {
    try {
      await DirectSmsService.setBackgroundVolumeTriggerEnabled(true);
    } catch (_) {
      // Service may fail on unsupported platforms; app can continue.
    }
  }
  runApp(MyApp(showOnboarding: showOnboarding));
}

class MyApp extends StatelessWidget {
  final bool showOnboarding;
  const MyApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    const baseScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF16E6FF),
      onPrimary: Color(0xFF001019),
      secondary: Color(0xFF0A66FF),
      onSecondary: Colors.white,
      error: Color(0xFFFF2A4F),
      onError: Colors.white,
      surface: Color(0xFF0C0F1A),
      onSurface: Color(0xFFEAF8FF),
      tertiary: Color(0xFFFF2A4F),
      onTertiary: Colors.white,
    );

    return MaterialApp(
      title: 'NightWalkers',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: baseScheme,
        scaffoldBackgroundColor: const Color(0xFF0A0D17),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Color(0xFF0A0D17),
          foregroundColor: Color(0xFFEAF8FF),
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFFEAF8FF),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF11172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1F325E)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF121B33),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1F325E)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1F325E)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF16E6FF), width: 1.4),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF0F1426),
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      routes: {
        '/': (context) => Semantics(
              label: 'NightWalkers home screen',
              child: const HomeScreen(),
            ),
        '/onboarding': (context) => const OnboardingScreen(),
      },
      initialRoute: showOnboarding ? '/onboarding' : '/',
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final scale = constraints.maxWidth < 400 ? 0.9 : 1.0;
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            );
          },
        );
      },
    );
  }
}
