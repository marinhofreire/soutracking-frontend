import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WhiteLabelConfig {
  const WhiteLabelConfig({
    required this.appName,
    required this.tagline,
    required this.primaryColor,
    required this.secondaryColor,
    this.logoAsset,
  });

  final String appName;
  final String tagline;
  final Color primaryColor;
  final Color secondaryColor;
  final String? logoAsset;

  static const WhiteLabelConfig fallback = WhiteLabelConfig(
    appName: 'SouTracking',
    tagline: 'Gestão inteligente de frotas e ativos',
    primaryColor: Color(0xFF1F6FEB),
    secondaryColor: Color(0xFF1F6FEB),
  );

  factory WhiteLabelConfig.fromJson(Map<String, dynamic> json) {
    return WhiteLabelConfig(
      appName: (json['appName'] ?? fallback.appName) as String,
      tagline: (json['tagline'] ?? fallback.tagline) as String,
      primaryColor: _parseColor(json['primaryColor']) ?? fallback.primaryColor,
      secondaryColor:
          _parseColor(json['secondaryColor']) ?? fallback.secondaryColor,
      logoAsset: json['logoAsset'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appName': appName,
      'tagline': tagline,
      'primaryColor': _colorToHex(primaryColor),
      'secondaryColor': _colorToHex(secondaryColor),
      'logoAsset': logoAsset,
    };
  }

  WhiteLabelConfig copyWith({
    String? appName,
    String? tagline,
    Color? primaryColor,
    Color? secondaryColor,
    String? logoAsset,
  }) {
    return WhiteLabelConfig(
      appName: appName ?? this.appName,
      tagline: tagline ?? this.tagline,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      logoAsset: logoAsset ?? this.logoAsset,
    );
  }

  static Color? _parseColor(dynamic value) {
    if (value is int) return Color(value);
    if (value is String) {
      var hex = value.replaceAll('#', '').toUpperCase();
      if (hex.length == 6) hex = 'FF$hex';
      if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    }
    return null;
  }

  static String _colorToHex(Color color) {
    final hex =
        color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#$hex';
  }
}

class WhiteLabelController extends StateNotifier<AsyncValue<WhiteLabelConfig>> {
  WhiteLabelController() : super(const AsyncValue.loading()) {
    _load();
  }

  static const _prefsKey = 'whiteLabelConfig';

  bool _isLegacyPurple(Color color) {
    final value = color.toARGB32();
    return value == const Color(0xFF7C5CFF).toARGB32() ||
        value == const Color(0xFF6D4DFF).toARGB32();
  }

  WhiteLabelConfig _normalizeLegacyPalette(WhiteLabelConfig config) {
    final shouldUpgradePrimary = _isLegacyPurple(config.primaryColor);
    final shouldUpgradeSecondary = _isLegacyPurple(config.secondaryColor);
    final currentName = config.appName.trim().toLowerCase();
    final shouldUpgradeName =
        currentName == 'sou fleet' || currentName == 'soufind';
    final normalizedName = shouldUpgradeName ? 'SouTracking' : config.appName;

    final currentLogo = config.logoAsset?.trim() ?? '';
    final shouldSetDefaultLogo =
        currentLogo.isEmpty && normalizedName == 'SouTracking';
    final normalizedLogo = shouldSetDefaultLogo
        ? 'assets/branding/soutracking_logo_horizontal.png'
        : config.logoAsset;

    if (!shouldUpgradePrimary &&
        !shouldUpgradeSecondary &&
        !shouldUpgradeName &&
        !shouldSetDefaultLogo) {
      return config;
    }

    return config.copyWith(
      appName: normalizedName,
      primaryColor:
          shouldUpgradePrimary ? const Color(0xFF1F6FEB) : config.primaryColor,
      secondaryColor: shouldUpgradeSecondary
          ? const Color(0xFF1F6FEB)
          : config.secondaryColor,
      logoAsset: normalizedLogo,
    );
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      if (stored != null && stored.isNotEmpty) {
        final data = jsonDecode(stored) as Map<String, dynamic>;
        final original = WhiteLabelConfig.fromJson(data);
        final loaded = _normalizeLegacyPalette(original);
        state = AsyncValue.data(loaded);
        final migrated = loaded.primaryColor.toARGB32() !=
                original.primaryColor.toARGB32() ||
            loaded.secondaryColor.toARGB32() !=
                original.secondaryColor.toARGB32();
        if (migrated) {
          await prefs.setString(_prefsKey, jsonEncode(loaded.toJson()));
        }
        return;
      }
    } catch (_) {}

    try {
      final raw = await rootBundle.loadString('assets/white_label.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      state = AsyncValue.data(WhiteLabelConfig.fromJson(data));
    } catch (_) {
      state = const AsyncValue.data(WhiteLabelConfig.fallback);
    }
  }

  Future<void> save(WhiteLabelConfig config) async {
    state = AsyncValue.data(config);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(config.toJson()));
    } catch (_) {}
  }

  Future<void> applyBranding(Map<String, dynamic> branding) async {
    final current = state.value ?? WhiteLabelConfig.fallback;
    final merged = current.copyWith(
      appName: branding['appName']?.toString() ??
          branding['name']?.toString() ??
          current.appName,
      tagline: branding['tagline']?.toString() ?? current.tagline,
      primaryColor: WhiteLabelConfig._parseColor(branding['primaryColor']) ??
          WhiteLabelConfig._parseColor(branding['primary']) ??
          current.primaryColor,
      secondaryColor:
          WhiteLabelConfig._parseColor(branding['secondaryColor']) ??
              WhiteLabelConfig._parseColor(branding['secondary']) ??
              current.secondaryColor,
      logoAsset: branding['logoAsset']?.toString() ??
          branding['logoUrl']?.toString() ??
          current.logoAsset,
    );
    await save(merged);
  }

  Future<void> reset() async {
    await save(WhiteLabelConfig.fallback);
  }
}

final whiteLabelProvider =
    StateNotifierProvider<WhiteLabelController, AsyncValue<WhiteLabelConfig>>(
  (ref) => WhiteLabelController(),
);
