import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'services/portfolio_service.dart';
import 'services/update_service.dart';
import 'ui/dashboard_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => PortfolioService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode =
        context.select<AppProvider, ThemeMode>((p) => p.themeMode);

    return MaterialApp(
      title: 'TechAna',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue, brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
      ),
      home: const UpdateWrapper(child: DashboardScreen()),
    );
  }
}

class UpdateWrapper extends StatefulWidget {
  final Widget child;
  const UpdateWrapper({super.key, required this.child});

  @override
  State<UpdateWrapper> createState() => _UpdateWrapperState();
}

class _UpdateWrapperState extends State<UpdateWrapper> {
  @override
  void initState() {
    super.initState();
    // Nach dem ersten Frame prüfen, damit der Context bereit ist
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService().checkForUpdate(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
