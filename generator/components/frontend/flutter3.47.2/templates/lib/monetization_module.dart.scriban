import 'core/interfaces/monetization_provider.dart';
import 'core/interfaces/ads_provider.dart';

import 'package:flutter/foundation.dart';

class MonetizationModule {
  final MonetizationProvider provider;
  final AdsProvider adsProvider;

  MonetizationModule({required this.provider, required this.adsProvider});

  Future<void> init() async {
    debugPrint('[MonetizationModule] init() called');
    debugPrint('[MonetizationModule] Inicializando módulo de monetización');
    await provider.initialize();
    debugPrint('[MonetizationModule] provider.initialize() finished');
    await adsProvider.initialize();
    debugPrint('[MonetizationModule] adsProvider.initialize() finished');
    debugPrint('[MonetizationModule] init() finished');
  }
}
