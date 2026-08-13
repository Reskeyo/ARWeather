import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ui/ar_view/ar_weather_screen.dart';

/// Entry point for the AR Weather application.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Force landscape or portrait — we keep portrait for AR
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Transparent status bar for immersive AR feel
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: ARWeatherApp()));
}

/// Root application widget.
class ARWeatherApp extends StatelessWidget {
  const ARWeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AR Weather',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        colorSchemeSeed: const Color(0xFF6C63FF),
      ),
      home: const ARWeatherScreen(),
    );
  }
}
