import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/bar_provider.dart';
import 'theme/app_theme.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(
    ChangeNotifierProvider(
      create: (_) => BarProvider()..init(),
      child: const SumrTimeApp(),
    ),
  );
}

class SumrTimeApp extends StatelessWidget {
  const SumrTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SumrTime',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme, // ← was AppTheme.dark (removed in new theme)
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    return Consumer<BarProvider>(
      builder: (context, prov, _) {
        return switch (prov.authState) {
          AuthState.unknown => const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppTheme.ocean),
              ),
            ),
          AuthState.authenticated  => const DashboardScreen(),
          AuthState.unauthenticated => const AuthScreen(),
        };
      },
    );
  }
}