import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum VisualBalloonSize { small, medium, large }

enum VisualLogoMode { normal, compact, hideOnFullMap }

enum VisualCardDensity { compact, comfortable }

enum VisualTransparency { low, medium, high }

enum VisualFontSize { normal, large }

enum VisualMapMode { normal, premium, dark }

@immutable
class VisualSettings {
  const VisualSettings({
    required this.balloonSize,
    required this.logoMode,
    required this.cardDensity,
    required this.transparency,
    required this.fontSize,
    required this.mapMode,
  });

  final VisualBalloonSize balloonSize;
  final VisualLogoMode logoMode;
  final VisualCardDensity cardDensity;
  final VisualTransparency transparency;
  final VisualFontSize fontSize;
  final VisualMapMode mapMode;

  static const defaults = VisualSettings(
    balloonSize: VisualBalloonSize.medium,
    logoMode: VisualLogoMode.normal,
    cardDensity: VisualCardDensity.comfortable,
    transparency: VisualTransparency.medium,
    fontSize: VisualFontSize.normal,
    mapMode: VisualMapMode.premium,
  );

  VisualSettings copyWith({
    VisualBalloonSize? balloonSize,
    VisualLogoMode? logoMode,
    VisualCardDensity? cardDensity,
    VisualTransparency? transparency,
    VisualFontSize? fontSize,
    VisualMapMode? mapMode,
  }) {
    return VisualSettings(
      balloonSize: balloonSize ?? this.balloonSize,
      logoMode: logoMode ?? this.logoMode,
      cardDensity: cardDensity ?? this.cardDensity,
      transparency: transparency ?? this.transparency,
      fontSize: fontSize ?? this.fontSize,
      mapMode: mapMode ?? this.mapMode,
    );
  }

  double get balloonScale {
    switch (balloonSize) {
      case VisualBalloonSize.small:
        return 0.9;
      case VisualBalloonSize.medium:
        return 1.0;
      case VisualBalloonSize.large:
        return 1.1;
    }
  }

  double get textScale {
    switch (fontSize) {
      case VisualFontSize.normal:
        return 1.0;
      case VisualFontSize.large:
        return 1.08;
    }
  }

  double get glassOpacity {
    switch (transparency) {
      case VisualTransparency.low:
        return 0.96;
      case VisualTransparency.medium:
        return 0.9;
      case VisualTransparency.high:
        return 0.82;
    }
  }

  double get backdropOverlayAlpha {
    switch (transparency) {
      case VisualTransparency.low:
        return 0.4;
      case VisualTransparency.medium:
        return 0.3;
      case VisualTransparency.high:
        return 0.2;
    }
  }

  double get glassBlur {
    switch (transparency) {
      case VisualTransparency.low:
        return 4;
      case VisualTransparency.medium:
        return 6;
      case VisualTransparency.high:
        return 9;
    }
  }

  double get panelScale {
    switch (cardDensity) {
      case VisualCardDensity.compact:
        return 0.94;
      case VisualCardDensity.comfortable:
        return 1.0;
    }
  }

  double get horizontalInset {
    switch (cardDensity) {
      case VisualCardDensity.compact:
        return 10;
      case VisualCardDensity.comfortable:
        return 16;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VisualSettings &&
        other.balloonSize == balloonSize &&
        other.logoMode == logoMode &&
        other.cardDensity == cardDensity &&
        other.transparency == transparency &&
        other.fontSize == fontSize &&
        other.mapMode == mapMode;
  }

  @override
  int get hashCode => Object.hash(
        balloonSize,
        logoMode,
        cardDensity,
        transparency,
        fontSize,
        mapMode,
      );
}

class VisualSettingsController extends StateNotifier<VisualSettings> {
  VisualSettingsController() : super(VisualSettings.defaults);

  void setBalloonSize(VisualBalloonSize value) {
    state = state.copyWith(balloonSize: value);
  }

  void setLogoMode(VisualLogoMode value) {
    state = state.copyWith(logoMode: value);
  }

  void setCardDensity(VisualCardDensity value) {
    state = state.copyWith(cardDensity: value);
  }

  void setTransparency(VisualTransparency value) {
    state = state.copyWith(transparency: value);
  }

  void setFontSize(VisualFontSize value) {
    state = state.copyWith(fontSize: value);
  }

  void setMapMode(VisualMapMode value) {
    state = state.copyWith(mapMode: value);
  }

  void reset() {
    state = VisualSettings.defaults;
  }
}

final visualSettingsProvider =
    StateNotifierProvider<VisualSettingsController, VisualSettings>(
  (ref) => VisualSettingsController(),
);

class VisualSettingsScope extends InheritedWidget {
  const VisualSettingsScope({
    super.key,
    required this.settings,
    required super.child,
  });

  final VisualSettings settings;

  static VisualSettings of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<VisualSettingsScope>()
            ?.settings ??
        VisualSettings.defaults;
  }

  @override
  bool updateShouldNotify(VisualSettingsScope oldWidget) {
    return oldWidget.settings != settings;
  }
}
