import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:device_preview/device_preview.dart';
import 'providers/auth_provider.dart';
import 'providers/running_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('vi_VN', null);
    await initializeDateFormatting('vi', null);
  } catch (_) {}
  await SupabaseService.initialize();
  runApp(
    DevicePreview(
      enabled: !kReleaseMode, // Bật khung điện thoại ảo khi chạy debug trên Chrome / Windows
      builder: (context) => const RunningTrackerApp(),
    ),
  );
}

class RunningTrackerApp extends StatelessWidget {
  const RunningTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RunningProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            title: 'Nocode Running',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            locale: DevicePreview.locale(context),
            builder: DevicePreview.appBuilder,
            home: auth.isAuthenticated ? const MainShell() : const LoginScreen(),
          );
        },
      ),
    );
  }
}
