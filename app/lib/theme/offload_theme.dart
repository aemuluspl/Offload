import 'package:flutter/material.dart';

@immutable
class OffloadPalette extends ThemeExtension<OffloadPalette> {
  const OffloadPalette({
    required this.page,
    required this.background,
    required this.card,
    required this.graph,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
    required this.accentSoft,
    required this.navIndicator,
    required this.navInk,
    required this.danger,
    required this.warning,
    required this.graphLine,
    required this.graphGrid,
    required this.radius,
  });

  final Color page;
  final Color background;
  final Color card;
  final Color graph;
  final Color border;
  final Color text;
  final Color muted;
  final Color accent;
  final Color accentSoft;
  final Color navIndicator;
  final Color navInk;
  final Color danger;
  final Color warning;
  final Color graphLine;
  final Color graphGrid;

  /// Глобальный радиус скруглений. Управляется из настроек.
  final double radius;

  static const dark = OffloadPalette(
    page: Color(0xFF000000),
    background: Color(0xFF0A0A0A),
    card: Color(0xFF151515),
    graph: Color(0xFF0E0E0E),
    border: Color(0x24FFFFFF),
    text: Color(0xFFF7F7F7),
    muted: Color(0xFFA3A3A3),
    accent: Color(0xFFFFFFFF),
    accentSoft: Color(0x1FFFFFFF),
    navIndicator: Color(0xFFFFFFFF),
    navInk: Color(0xFF0A0A0A),
    danger: Color(0xFFE5E5E5),
    warning: Color(0xFFBDBDBD),
    graphLine: Color(0x8CFFFFFF),
    graphGrid: Color(0x0DFFFFFF),
    radius: 24,
  );

  static const light = OffloadPalette(
    page: Color(0xFFE8E8E8),
    background: Color(0xFFF7F7F7),
    card: Color(0xFFFFFFFF),
    graph: Color(0xFFFFFFFF),
    border: Color(0x1F000000),
    text: Color(0xFF0A0A0A),
    muted: Color(0xFF6B6B6B),
    accent: Color(0xFF000000),
    accentSoft: Color(0x14000000),
    navIndicator: Color(0xFF000000),
    navInk: Color(0xFFFFFFFF),
    danger: Color(0xFF1A1A1A),
    warning: Color(0xFF444444),
    graphLine: Color(0x73000000),
    graphGrid: Color(0x0D000000),
    radius: 24,
  );

  @override
  OffloadPalette copyWith({
    Color? page,
    Color? background,
    Color? card,
    Color? graph,
    Color? border,
    Color? text,
    Color? muted,
    Color? accent,
    Color? accentSoft,
    Color? navIndicator,
    Color? navInk,
    Color? danger,
    Color? warning,
    Color? graphLine,
    Color? graphGrid,
    double? radius,
  }) {
    return OffloadPalette(
      page: page ?? this.page,
      background: background ?? this.background,
      card: card ?? this.card,
      graph: graph ?? this.graph,
      border: border ?? this.border,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      navIndicator: navIndicator ?? this.navIndicator,
      navInk: navInk ?? this.navInk,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      graphLine: graphLine ?? this.graphLine,
      graphGrid: graphGrid ?? this.graphGrid,
      radius: radius ?? this.radius,
    );
  }

  @override
  OffloadPalette lerp(ThemeExtension<OffloadPalette>? other, double t) {
    if (other is! OffloadPalette) {
      return this;
    }
    return OffloadPalette(
      page: Color.lerp(page, other.page, t)!,
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      graph: Color.lerp(graph, other.graph, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      navIndicator: Color.lerp(navIndicator, other.navIndicator, t)!,
      navInk: Color.lerp(navInk, other.navInk, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      graphLine: Color.lerp(graphLine, other.graphLine, t)!,
      graphGrid: Color.lerp(graphGrid, other.graphGrid, t)!,
      radius: radius + (other.radius - radius) * t,
    );
  }
}

ThemeData buildOffloadTheme({
  required bool dark,
  double cornerRadius = 24,
  bool deepBlack = false,
}) {
  var palette = (dark ? OffloadPalette.dark : OffloadPalette.light).copyWith(
    radius: cornerRadius.clamp(4.0, 40.0).toDouble(),
  );
  if (dark && deepBlack) {
    palette = palette.copyWith(
      page: const Color(0xFF000000),
      background: const Color(0xFF000000),
      graph: const Color(0xFF000000),
    );
  }

  final brightness = dark ? Brightness.dark : Brightness.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Inter',
  );
  final scheme = ColorScheme.fromSeed(
    seedColor: palette.accent,
    brightness: brightness,
    surface: palette.card,
    primary: palette.accent,
  ).copyWith(
    primary: palette.accent,
    onPrimary: palette.navInk,
    secondary: palette.accent,
    onSecondary: palette.navInk,
    surface: palette.card,
    onSurface: palette.text,
    outline: palette.border,
    error: palette.danger,
    onError: palette.navInk,
  );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.background,
    canvasColor: palette.card,
    dividerColor: palette.border,
    splashFactory: InkSparkle.splashFactory,
    textTheme: base.textTheme
        .apply(
          fontFamily: 'Inter',
          bodyColor: palette.text,
          displayColor: palette.text,
        )
        .copyWith(
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            fontFamily: 'Inter',
            color: palette.text,
          ),
        ),
    iconTheme: IconThemeData(color: palette.text),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(palette.radius),
        border: Border.all(color: palette.border),
      ),
      textStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        color: palette.text,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.card,
      contentTextStyle: TextStyle(
        fontFamily: 'Inter',
        color: palette.text,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(palette.radius),
        side: BorderSide(color: palette.border),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    extensions: [palette],
  );
}

extension OffloadThemeContext on BuildContext {
  OffloadPalette get palette =>
      Theme.of(this).extension<OffloadPalette>() ?? OffloadPalette.dark;
}
