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

  static const dark = OffloadPalette(
    page: Color(0xFF050507),
    background: Color(0xFF0C0D10),
    card: Color(0xFF1B1D22),
    graph: Color(0xFF181A1F),
    border: Color(0x24FFFFFF),
    text: Color(0xFFF3F4F6),
    muted: Color(0xFF9CA3AF),
    accent: Color(0xFF4ADE80),
    accentSoft: Color(0x334ADE80),
    navIndicator: Color(0xFFFFFFFF),
    navInk: Color(0xFF0C0D10),
    danger: Color(0xFFF87171),
    warning: Color(0xFFF59E0B),
    graphLine: Color(0xA6D4D4D8),
    graphGrid: Color(0x0DFFFFFF),
  );

  static const light = OffloadPalette(
    page: Color(0xFF050507),
    background: Color(0xFFF1F5F9),
    card: Color(0xFFFFFFFF),
    graph: Color(0xFFF8FAFC),
    border: Color(0x1F0F172A),
    text: Color(0xFF0F172A),
    muted: Color(0xFF64748B),
    accent: Color(0xFF22C55E),
    accentSoft: Color(0x3322C55E),
    navIndicator: Color(0xFF0F172A),
    navInk: Color(0xFFFFFFFF),
    danger: Color(0xFFDC2626),
    warning: Color(0xFFD97706),
    graphLine: Color(0x80475569),
    graphGrid: Color(0x0D0F172A),
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
    );
  }
}

ThemeData buildOffloadTheme({required bool dark}) {
  final palette = dark ? OffloadPalette.dark : OffloadPalette.light;
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
    surface: palette.card,
    onSurface: palette.text,
    outline: palette.border,
    error: palette.danger,
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
        borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(18),
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
