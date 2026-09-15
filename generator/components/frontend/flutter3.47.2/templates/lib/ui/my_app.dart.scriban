import 'package:flutter/material.dart';
import '../monetization_module.dart';
import '../core/app_initialization_orchestrator.dart';
import 'paywall_widget.dart';

class MyApp extends StatelessWidget {
  final MonetizationModule monetization;
  final AppInitializationOrchestrator orchestrator;
  const MyApp({
    super.key,
    required this.monetization,
    required this.orchestrator,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('[MyApp] build() called');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[MyApp] addPostFrameCallback: runPostUi');
      orchestrator.runPostUi(context);
    });
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Monetization Example')),
        body: Center(child: PaywallWidget(provider: monetization.provider)),
      ),
    );
  }
}
