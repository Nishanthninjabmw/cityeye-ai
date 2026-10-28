import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'screens/gate_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  final api = ApiService();
  await api.init();

  runApp(const CityEyeApp());
}

class CityEyeApp extends StatelessWidget {
  const CityEyeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiService();

    Widget initialScreen;
    if (!api.isGateUnlocked) {
      initialScreen = const GateScreen();
    } else if (api.currentOfficer != null) {
      initialScreen = const MainShell();
    } else {
      initialScreen = const LandingScreen();
    }

    return MaterialApp(
      title: 'CityEye AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: initialScreen,
    );
  }
}
