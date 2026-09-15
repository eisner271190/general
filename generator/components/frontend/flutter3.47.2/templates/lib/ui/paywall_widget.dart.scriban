import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/config/monetization_env.dart';
import '../core/interfaces/monetization_provider.dart';
import 'admob_banner_widget.dart';

class PaywallWidget extends StatelessWidget {
  String get privacyUrl => MonetizationEnv.privacyUrl;
  String get termsUrl => MonetizationEnv.termsUrl;
  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  final MonetizationProvider provider;

  const PaywallWidget({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    ValueNotifier<String?> errorNotifier = ValueNotifier(null);
    return StreamBuilder(
      stream: provider.entitlementStream(),
      builder: (context, snapshot) {
        final entitlement = snapshot.data;
        final isSubscribed = entitlement?.isActive ?? false;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            if (!isSubscribed) ...[
              const AdmobBannerWidget(),
              const SizedBox(height: 16),
            ],
            if (isSubscribed)
              Column(
                children: [
                  const Icon(Icons.verified, color: Colors.green, size: 48),
                  Text(
                    '¡Eres suscriptor!',
                    style: TextStyle(fontSize: 18, color: Colors.green),
                  ),
                  const SizedBox(height: 16),
                  Text('Contenido premium desbloqueado.'),
                ],
              )
            else ...[
              ElevatedButton(
                onPressed: () async {
                  try {
                    await provider.restore();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Compras restauradas')),
                      );
                    }
                  } catch (e) {
                    errorNotifier.value = 'Error al restaurar compras: $e';
                  }
                },
                child: const Text('Restaurar compras'),
              ),
              ValueListenableBuilder<String?>(
                valueListenable: errorNotifier,
                builder: (context, error, _) {
                  if (error != null) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        error,
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: provider.getPlans(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error de conexión. Verifica tu internet.'),
                      );
                    }
                    final plans = snapshot.data ?? [];
                    if (plans.isEmpty) {
                      return Center(
                        child: Text(
                          'No hay productos disponibles en este momento.',
                        ),
                      );
                    }
                    return ListView(
                      children: plans.where((plan) => plan != null).map((plan) {
                        final p = plan as dynamic;
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          child: ListTile(
                            title: Text(p.name ?? ''),
                            subtitle: Text(
                              '${p.price ?? ''} / ${p.period ?? ''}',
                            ),
                            trailing: ElevatedButton(
                              onPressed: () async {
                                try {
                                  await provider.purchase(p.id ?? '');
                                } catch (e) {
                                  errorNotifier.value =
                                      'Error al realizar la compra: $e';
                                }
                              },
                              child: const Text('Suscribirse'),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () {
                      _launchUrl(privacyUrl);
                    },
                    child: Text(
                      'Política de Privacidad',
                      style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  InkWell(
                    onTap: () {
                      _launchUrl(termsUrl);
                    },
                    child: Text(
                      'Términos de Uso',
                      style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
