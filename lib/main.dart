import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/preferences_service.dart';
import 'features/presentation/share_intent_manager.dart';
import 'features/presentation/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
