import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAsaasApiKey  = 'asaas_api_key';
const _kAsaasSandbox = 'asaas_sandbox';

class AsaasConfig {
  const AsaasConfig({
    this.apiKey  = '',
    this.sandbox = true,
  });

  final String apiKey;
  final bool sandbox;

  bool get isConfigured => apiKey.isNotEmpty;

  String get baseUrl => sandbox
      ? 'https://api-sandbox.asaas.com/v3'
      : 'https://api.asaas.com/v3';

  AsaasConfig copyWith({String? apiKey, bool? sandbox}) => AsaasConfig(
        apiKey:  apiKey  ?? this.apiKey,
        sandbox: sandbox ?? this.sandbox,
      );

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAsaasApiKey, apiKey);
    await p.setBool(_kAsaasSandbox, sandbox);
  }

  static Future<AsaasConfig> load() async {
    final p = await SharedPreferences.getInstance();
    return AsaasConfig(
      apiKey:  p.getString(_kAsaasApiKey) ?? '',
      sandbox: p.getBool(_kAsaasSandbox)  ?? true,
    );
  }
}

final asaasConfigProvider =
    StateNotifierProvider<AsaasConfigNotifier, AsaasConfig>(
  (ref) => AsaasConfigNotifier(),
);

class AsaasConfigNotifier extends StateNotifier<AsaasConfig> {
  AsaasConfigNotifier() : super(const AsaasConfig()) {
    _load();
  }

  Future<void> _load() async => state = await AsaasConfig.load();

  Future<void> save(AsaasConfig config) async {
    await config.save();
    state = config;
  }
}
