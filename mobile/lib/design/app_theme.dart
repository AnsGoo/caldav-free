import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Central visual tokens for the Android client.
///
/// The palette stays deliberately small: a cool canvas, white sheets, one
/// electric blue accent and a muted gray text ramp. Screens should read as
/// layers of paper rather than a collection of outlined boxes.
abstract final class AppColors {
  static const primary = Color(0xFF3563F0);
  static const primaryPressed = Color(0xFF2B53D2);
  static const primarySoft = Color(0xFFEAF0FF);
  static const canvas = Color(0xFFF5F6F8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF1F3F7);
  static const ink = Color(0xFF1B1F2A);
  static const inkSecondary = Color(0xFF656D7E);
  static const inkTertiary = Color(0xFFA6ADBA);
  static const line = Color(0xFFEDF0F5);
  static const green = Color(0xFF2DCB8A);
  static const orange = Color(0xFFFF9F43);
  static const red = Color(0xFFFF5C5C);
  static const darkCanvas = Color(0xFF0E1015);
  static const darkSurface = Color(0xFF171A22);
  static const darkSurfaceMuted = Color(0xFF20242E);
  static const darkInk = Color(0xFFF2F4F8);
  static const darkInkSecondary = Color(0xFF9AA3B2);
  static const darkLine = Color(0xFF2A2F3A);
}

ThemeData buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final canvas = dark ? AppColors.darkCanvas : AppColors.canvas;
  final surface = dark ? AppColors.darkSurface : AppColors.surface;
  final surfaceMuted = dark
      ? AppColors.darkSurfaceMuted
      : AppColors.surfaceMuted;
  final ink = dark ? AppColors.darkInk : AppColors.ink;
  final inkSecondary = dark
      ? AppColors.darkInkSecondary
      : AppColors.inkSecondary;
  final line = dark ? AppColors.darkLine : AppColors.line;
  final primary = dark ? const Color(0xFF7F9BFF) : AppColors.primary;

  final base = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: brightness,
  );
  final scheme = base.copyWith(
    primary: primary,
    onPrimary: dark ? const Color(0xFF07122F) : Colors.white,
    primaryContainer: dark ? const Color(0xFF23335F) : AppColors.primarySoft,
    onPrimaryContainer: dark
        ? const Color(0xFFDCE5FF)
        : const Color(0xFF17357F),
    secondary: dark ? const Color(0xFF9BA8C2) : const Color(0xFF5C6B8A),
    onSecondary: dark ? const Color(0xFF11151E) : Colors.white,
    surface: surface,
    onSurface: ink,
    onSurfaceVariant: inkSecondary,
    surfaceContainerLowest: dark ? const Color(0xFF10131A) : Colors.white,
    surfaceContainerLow: dark
        ? const Color(0xFF191D26)
        : const Color(0xFFF9FAFC),
    surfaceContainer: dark ? const Color(0xFF1D222C) : const Color(0xFFF3F5F9),
    surfaceContainerHigh: dark
        ? const Color(0xFF252B37)
        : const Color(0xFFEEF1F6),
    surfaceContainerHighest: dark
        ? const Color(0xFF2C3340)
        : const Color(0xFFE8ECF2),
    outline: dark ? const Color(0xFF3B4250) : const Color(0xFFDDE2EA),
    outlineVariant: line,
    error: AppColors.red,
    onError: Colors.white,
    errorContainer: dark ? const Color(0xFF4A2024) : const Color(0xFFFFECEC),
    onErrorContainer: dark ? const Color(0xFFFFD9DC) : const Color(0xFF8A1F24),
    shadow: dark ? Colors.black : const Color(0xFF26324A),
  );

  final textTheme = TextTheme(
    displayLarge: TextStyle(
      color: ink,
      fontSize: 48,
      height: 1.05,
      fontWeight: FontWeight.w300,
      letterSpacing: -1.4,
    ),
    displayMedium: TextStyle(
      color: ink,
      fontSize: 36,
      height: 1.08,
      fontWeight: FontWeight.w800,
      letterSpacing: -1,
    ),
    displaySmall: TextStyle(
      color: ink,
      fontSize: 32,
      height: 1.1,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
    ),
    headlineLarge: TextStyle(
      color: ink,
      fontSize: 30,
      height: 1.12,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.7,
    ),
    headlineMedium: TextStyle(
      color: ink,
      fontSize: 28,
      height: 1.14,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
    ),
    headlineSmall: TextStyle(
      color: ink,
      fontSize: 26,
      height: 1.16,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    ),
    titleLarge: TextStyle(
      color: ink,
      fontSize: 20,
      height: 1.25,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    titleMedium: TextStyle(
      color: ink,
      fontSize: 17,
      height: 1.3,
      fontWeight: FontWeight.w700,
    ),
    titleSmall: TextStyle(
      color: ink,
      fontSize: 15,
      height: 1.3,
      fontWeight: FontWeight.w700,
    ),
    bodyLarge: TextStyle(
      color: ink,
      fontSize: 16,
      height: 1.4,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.1,
    ),
    bodyMedium: TextStyle(
      color: ink,
      fontSize: 14,
      height: 1.42,
      fontWeight: FontWeight.w500,
    ),
    bodySmall: TextStyle(
      color: inkSecondary,
      fontSize: 12.5,
      height: 1.35,
      fontWeight: FontWeight.w500,
    ),
    labelLarge: TextStyle(
      color: ink,
      fontSize: 14,
      height: 1.2,
      fontWeight: FontWeight.w600,
    ),
    labelMedium: TextStyle(
      color: inkSecondary,
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: TextStyle(
      color: inkSecondary,
      fontSize: 11,
      height: 1.2,
      fontWeight: FontWeight.w500,
    ),
  );

  final appBarText = textTheme.headlineSmall!.copyWith(
    color: ink,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.7,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    canvasColor: canvas,
    textTheme: textTheme,
    fontFamilyFallback: const [
      'PingFang SC',
      'Noto Sans CJK SC',
      'Noto Sans SC',
      'Microsoft YaHei',
    ],
    visualDensity: VisualDensity.standard,
    splashFactory: InkRipple.splashFactory,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: canvas,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ink,
      centerTitle: false,
      toolbarHeight: 76,
      titleSpacing: 20,
      titleTextStyle: appBarText,
      iconTheme: IconThemeData(color: ink, size: 23),
      actionsIconTheme: IconThemeData(color: ink, size: 23),
      systemOverlayStyle: dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: dark ? const Color(0xFF07122F) : Colors.white,
        disabledBackgroundColor: surfaceMuted,
        disabledForegroundColor: inkSecondary,
        elevation: 0,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: textTheme.labelLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: textTheme.labelLarge?.copyWith(
          color: primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        side: BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        foregroundColor: WidgetStatePropertyAll(ink),
        iconSize: const WidgetStatePropertyAll(22),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceMuted,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: textTheme.bodyLarge?.copyWith(color: inkSecondary),
      labelStyle: textTheme.bodyMedium?.copyWith(color: inkSecondary),
      floatingLabelStyle: textTheme.labelLarge?.copyWith(color: primary),
      prefixIconColor: inkSecondary,
      suffixIconColor: inkSecondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: primary.withValues(alpha: 0.65),
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.red, width: 1.4),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceMuted,
      selectedColor: dark ? const Color(0xFF26365F) : AppColors.primarySoft,
      disabledColor: surfaceMuted,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelStyle: textTheme.labelLarge?.copyWith(
        color: inkSecondary,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: textTheme.labelLarge?.copyWith(
        color: primary,
        fontWeight: FontWeight.w700,
      ),
      elevation: 0,
      pressElevation: 0,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      modalBackgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: dark ? const Color(0xFF454C5A) : const Color(0xFFD5DAE2),
      dragHandleSize: const Size(38, 4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: inkSecondary),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF2A303C) : const Color(0xFF202531),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      elevation: 6,
      insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: dark ? const Color(0xFF07122F) : Colors.white,
      elevation: 5,
      focusElevation: 5,
      hoverElevation: 5,
      highlightElevation: 3,
      shape: const CircleBorder(),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: textTheme.bodyMedium?.copyWith(color: ink),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      iconColor: inkSecondary,
      textColor: ink,
      titleTextStyle: textTheme.titleSmall,
      subtitleTextStyle: textTheme.bodySmall,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : (dark ? const Color(0xFF9AA3B2) : Colors.white),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? primary
            : (dark ? const Color(0xFF3A414E) : const Color(0xFFD9DEE7)),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primary,
      linearMinHeight: 2,
      linearTrackColor: surfaceMuted,
      circularTrackColor: surfaceMuted,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: primary,
      selectionColor: primary.withValues(alpha: 0.22),
      selectionHandleColor: primary,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2B303B) : const Color(0xFF252A35),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
    ),
  );
}
