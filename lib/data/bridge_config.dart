import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Keys ───────────────────────────────────────────────────────────────────────
const _kBridgeUrl     = 'bridge_url';
const _kBridgeApiKey  = 'bridge_api_key';
const _kPusherAppKey  = 'pusher_app_key';
const _kPusherCluster = 'pusher_cluster';
const _kPusherChannel = 'pusher_channel';
const _kAiMode        = 'ai_mode';
const _kAutonomyJson  = 'ai_autonomy';

// ── Enums ──────────────────────────────────────────────────────────────────────

enum AiMode { mock, bridge }

// ── Config model ───────────────────────────────────────────────────────────────

class BridgeConfig {
  const BridgeConfig({
    this.bridgeUrl = '',
    this.bridgeApiKey = '',
    this.pusherAppKey = '',
    this.pusherCluster = 'mt1',
    this.pusherChannel = '',
    this.aiMode = AiMode.mock,
    this.autonomy = const {
      'alertas':    true,
      'cercas':     false,
      'despacho':   false,
      'whatsapp':   true,
      'relatorios': true,
    },
  });

  final String bridgeUrl;
  final String bridgeApiKey;
  final String pusherAppKey;
  final String pusherCluster;
  final String pusherChannel;
  final AiMode aiMode;
  final Map<String, bool> autonomy;

  bool get isConfigured =>
      bridgeUrl.isNotEmpty && bridgeApiKey.isNotEmpty && pusherChannel.isNotEmpty;

  BridgeConfig copyWith({
    String? bridgeUrl,
    String? bridgeApiKey,
    String? pusherAppKey,
    String? pusherCluster,
    String? pusherChannel,
    AiMode? aiMode,
    Map<String, bool>? autonomy,
  }) =>
      BridgeConfig(
        bridgeUrl:     bridgeUrl     ?? this.bridgeUrl,
        bridgeApiKey:  bridgeApiKey  ?? this.bridgeApiKey,
        pusherAppKey:  pusherAppKey  ?? this.pusherAppKey,
        pusherCluster: pusherCluster ?? this.pusherCluster,
        pusherChannel: pusherChannel ?? this.pusherChannel,
        aiMode:        aiMode        ?? this.aiMode,
        autonomy:      autonomy      ?? this.autonomy,
      );

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kBridgeUrl,     bridgeUrl);
    await p.setString(_kBridgeApiKey,  bridgeApiKey);
    await p.setString(_kPusherAppKey,  pusherAppKey);
    await p.setString(_kPusherCluster, pusherCluster);
    await p.setString(_kPusherChannel, pusherChannel);
    await p.setString(_kAiMode,        aiMode.name);
    final rows = autonomy.entries.map((e) => '${e.key}=${e.value ? '1' : '0'}').join(',');
    await p.setString(_kAutonomyJson, rows);
  }

  static Future<BridgeConfig> load() async {
    final p = await SharedPreferences.getInstance();
    final modeStr = p.getString(_kAiMode) ?? 'mock';
    final mode = AiMode.values.firstWhere((e) => e.name == modeStr, orElse: () => AiMode.mock);
    final autonomyStr = p.getString(_kAutonomyJson) ?? '';
    final autonomy = <String, bool>{
      'alertas':    true,
      'cercas':     false,
      'despacho':   false,
      'whatsapp':   true,
      'relatorios': true,
    };
    if (autonomyStr.isNotEmpty) {
      for (final pair in autonomyStr.split(',')) {
        final parts = pair.split('=');
        if (parts.length == 2) autonomy[parts[0]] = parts[1] == '1';
      }
    }
    return BridgeConfig(
      bridgeUrl:     p.getString(_kBridgeUrl)     ?? '',
      bridgeApiKey:  p.getString(_kBridgeApiKey)  ?? '',
      pusherAppKey:  p.getString(_kPusherAppKey)  ?? '',
      pusherCluster: p.getString(_kPusherCluster) ?? 'mt1',
      pusherChannel: p.getString(_kPusherChannel) ?? '',
      aiMode:        mode,
      autonomy:      autonomy,
    );
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────

final bridgeConfigProvider =
    StateNotifierProvider<BridgeConfigNotifier, BridgeConfig>(
  (ref) => BridgeConfigNotifier(),
);

class BridgeConfigNotifier extends StateNotifier<BridgeConfig> {
  BridgeConfigNotifier() : super(const BridgeConfig()) {
    _load();
  }

  Future<void> _load() async => state = await BridgeConfig.load();

  Future<void> save(BridgeConfig config) async {
    await config.save();
    state = config;
  }

  void setAutonomy(String key, bool value) {
    final updated = Map<String, bool>.from(state.autonomy);
    updated[key] = value;
    state = state.copyWith(autonomy: updated);
  }
}
