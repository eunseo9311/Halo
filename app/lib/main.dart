import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    // ignore: avoid_print
    print('[FLUTTER ERROR] ${details.exceptionAsString()}');
    // ignore: avoid_print
    print('[FLUTTER ERROR STACK] ${details.stack}');
    FlutterError.presentError(details);
  };
  await dotenv.load(fileName: '.env');
  runApp(
    DevicePreview(
      enabled: kDebugMode,
      defaultDevice: Devices.ios.iPhone15Pro,
      builder: (context) => const ProviderScope(child: HaloApp()),
    ),
  );
}

class HaloApp extends StatelessWidget {
  const HaloApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Halo',
        locale: DevicePreview.locale(context),
        builder: DevicePreview.appBuilder,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6B48FF)),
          useMaterial3: true,
        ),
        routerConfig: appRouter,
      );
}
