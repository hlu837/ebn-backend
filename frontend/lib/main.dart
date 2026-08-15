import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/loop_controller.dart';
import 'providers/sell_request_controller.dart';
import 'providers/order_request_controller.dart';
import 'providers/favorites_controller.dart';
import 'providers/pending_form_store.dart';
import 'screens/role_gate_screen.dart';
import 'theme/app_theme.dart';

/// TEMPORARY DEBUG AID — makes crashes visible as red text on-screen
/// instead of a blank box, even in release builds. Remove once the
/// investor-tab blank-screen bug is found and fixed.
void main() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFFFFF0F0),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text(
            'CRASH:\n${details.exceptionAsString()}\n\n${details.stack}',
            style: const TextStyle(color: Colors.black, fontSize: 11, fontFamily: 'monospace'),
          ),
        ),
      ),
    );
  };

  runZonedGuarded(() {
    runApp(const EbnDemoApp());
  }, (error, stack) {
    debugPrint('UNCAUGHT ASYNC ERROR: $error\n$stack');
  });
}

/// Root of the demo. [LoopController], [SellRequestController],
/// [OrderRequestController], and [FavoritesController] are provided once
/// here, above the Navigator, so they stay the single shared source of
/// truth no matter which side (Customer / Admin / Agent) is currently
/// pushed on the stack.
class EbnDemoApp extends StatelessWidget {
  const EbnDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoopController()),
        ChangeNotifierProvider(create: (_) => SellRequestController()),
        ChangeNotifierProvider(create: (_) => OrderRequestController()),
        ChangeNotifierProvider(create: (_) => FavoritesController()),
        ChangeNotifierProvider(create: (_) => PendingFormStore()),
      ],
      child: MaterialApp(
        title: 'EBN — Verify Any Asset',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const RoleGateScreen(),
      ),
    );
  }
}
