import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/loop_controller.dart';
import 'providers/sell_request_controller.dart';
import 'providers/order_request_controller.dart';
import 'providers/favorites_controller.dart';
import 'providers/pending_form_store.dart';
import 'screens/role_gate_screen.dart';
import 'theme/app_theme.dart';

void main() => runApp(const EbnDemoApp());

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
