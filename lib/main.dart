import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'core/logging/app_logger.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/preferences_service.dart';
import 'features/presentation/share_intent_manager.dart';
import 'features/presentation/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch Flutter framework errors
  FlutterError.onError = (details) {
    talker.handle(details.exception, details.stack, 'Uncaught Flutter Error');
  };

  // Catch unhandled async / platform errors
  PlatformDispatcher.instance.onError = (error, stack) {
    talker.handle(error, stack, 'Uncaught Platform Error');
    return true;
  };

  talker.info('🚀 PulseShare 2.0 started');

  ShareIntentManager.initialize();
  runApp(const PulseShareApp());
}

class PulseShareApp extends StatelessWidget {
  const PulseShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PreferencesService(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: ShareIntentManager.navigatorKey,
        navigatorObservers: [
          TalkerRouteObserver(talker),
        ],
        title: 'PulseShare',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
