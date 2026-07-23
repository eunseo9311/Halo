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
  runApp(const ProviderScope(child: HaloApp()));
}

class HaloApp extends StatelessWidget {
  const HaloApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Halo',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6B48FF)),
      useMaterial3: true,
    ),
    routerConfig: appRouter,
  );
}
