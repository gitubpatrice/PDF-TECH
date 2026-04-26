import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const PdfStudioApp());
}

ThemeData _githubDarkTheme() {
  const bg       = Color(0xFF0D1117); // canvas default
  const surface  = Color(0xFF161B22); // overlay background (cards, appbar)
  const surface2 = Color(0xFF21262D); // elevated / input fields
  const border   = Color(0xFF30363D); // default border
  const textPri  = Color(0xFFE6EDF3); // primary text
  const textSec  = Color(0xFF8B949E); // muted text
  const blue     = Color(0xFF58A6FF); // link / accent
  const blueCont = Color(0xFF1F6FEB); // button fill
  const red      = Color(0xFFF85149); // error / danger

  final cs = const ColorScheme(
    brightness: Brightness.dark,
    // Primary
    primary:            blue,
    onPrimary:          bg,
    primaryContainer:   blueCont,
    onPrimaryContainer: textPri,
    // Secondary
    secondary:            blue,
    onSecondary:          bg,
    secondaryContainer:   surface2,
    onSecondaryContainer: textPri,
    // Tertiary
    tertiary:            blue,
    onTertiary:          bg,
    tertiaryContainer:   surface2,
    onTertiaryContainer: textPri,
    // Error
    error:        red,
    onError:      textPri,
    errorContainer:   Color(0xFF8E1A15),
    onErrorContainer: textPri,
    // Surface
    surface:                  bg,
    onSurface:                textPri,
    onSurfaceVariant:         textSec,
    surfaceContainerLowest:   bg,
    surfaceContainerLow:      surface,
    surfaceContainer:         surface,
    surfaceContainerHigh:     surface2,
    surfaceContainerHighest:  surface2,
    // Outline
    outline:        border,
    outlineVariant: surface2,
    // Inverse
    inverseSurface:   textPri,
    onInverseSurface: bg,
    inversePrimary:   blueCont,
    // Scrim / shadow
    scrim:  Color(0xFF000000),
    shadow: Color(0xFF000000),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      foregroundColor: textPri,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: border)),
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: border),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: blueCont,
      elevation: 0,
    ),
    bottomAppBarTheme: const BottomAppBarThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(color: border, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: blue, width: 2),
      ),
      hintStyle: const TextStyle(color: textSec),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: surface2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        side: BorderSide(color: border),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: surface2,
      contentTextStyle: TextStyle(color: textPri),
      actionTextColor: blue,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: border),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        side: BorderSide(color: border),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: textSec,
      textColor: textPri,
    ),
    iconTheme: const IconThemeData(color: textSec),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: textPri),
      bodySmall:  TextStyle(color: textSec),
      titleMedium: TextStyle(color: textPri, fontWeight: FontWeight.w600),
      titleSmall:  TextStyle(color: textSec),
      titleLarge:  TextStyle(color: textPri, fontWeight: FontWeight.w600),
    ),
  );
}

class PdfStudioApp extends StatefulWidget {
  const PdfStudioApp({super.key});

  @override
  State<PdfStudioApp> createState() => _PdfStudioAppState();
}

class _PdfStudioAppState extends State<PdfStudioApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme_mode');
    if (saved != null && mounted) {
      setState(() => _themeMode = ThemeMode.values.firstWhere(
            (m) => m.name == saved,
            orElse: () => ThemeMode.system,
          ));
    }
  }

  Future<void> _setTheme(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
        ),
        useMaterial3: true,
      ),
      darkTheme: _githubDarkTheme(),
      themeMode: _themeMode,
      home: HomeScreen(
        themeMode: _themeMode,
        onThemeChanged: _setTheme,
      ),
    );
  }
}
