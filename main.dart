import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/bar_provider.dart';
import 'theme/app_theme.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

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

class SumrTimeApp extends StatefulWidget {
  const SumrTimeApp({super.key});

  @override
  State<SumrTimeApp> createState() => _SumrTimeAppState();
}

class _SumrTimeAppState extends State<SumrTimeApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App came back to the foreground (e.g. after a phone call) — the socket
    // may think it's connected while the connection went stale, so refetch.
    if (state == AppLifecycleState.resumed) {
      context.read<BarProvider>().resyncOnResume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'SumrTime',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
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