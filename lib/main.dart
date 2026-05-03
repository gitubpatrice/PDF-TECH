import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';

const _settingsChannel = MethodChannel('com.pdftech.pdf_tech/settings');

Future<void> _openUnknownSources() async {
  await _settingsChannel.invokeMethod('openUnknownSources');
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const PdfTechApp());
}

ThemeData _githubDarkTheme() {
  const bg = Color(0xFF0D1117); // canvas default
  const surface = Color(0xFF161B22); // overlay background (cards, appbar)
  const surface2 = Color(0xFF21262D); // elevated / input fields
  const border = Color(0xFF30363D); // default border
  const textPri = Color(0xFFE6EDF3); // primary text
  const textSec = Color(0xFF8B949E); // muted text
  const blue = Color(0xFF58A6FF); // link / accent
  const blueCont = Color(0xFF1F6FEB); // button fill
  const red = Color(0xFFF85149); // error / danger

  final cs = const ColorScheme(
    brightness: Brightness.dark,
    // Primary
    primary: blue,
    onPrimary: bg,
    primaryContainer: blueCont,
    onPrimaryContainer: textPri,
    // Secondary
    secondary: blue,
    onSecondary: bg,
    secondaryContainer: surface2,
    onSecondaryContainer: textPri,
    // Tertiary
    tertiary: blue,
    onTertiary: bg,
    tertiaryContainer: surface2,
    onTertiaryContainer: textPri,
    // Error
    error: red,
    onError: textPri,
    errorContainer: Color(0xFF8E1A15),
    onErrorContainer: textPri,
    // Surface
    surface: bg,
    onSurface: textPri,
    onSurfaceVariant: textSec,
    surfaceContainerLowest: bg,
    surfaceContainerLow: surface,
    surfaceContainer: surface,
    surfaceContainerHigh: surface2,
    surfaceContainerHighest: surface2,
    // Outline
    outline: border,
    outlineVariant: surface2,
    // Inverse
    inverseSurface: textPri,
    onInverseSurface: bg,
    inversePrimary: blueCont,
    // Scrim / shadow
    scrim: Color(0xFF000000),
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
      bodySmall: TextStyle(color: textSec),
      titleMedium: TextStyle(color: textPri, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: textSec),
      titleLarge: TextStyle(color: textPri, fontWeight: FontWeight.w600),
    ),
  );
}

class PdfTechApp extends StatefulWidget {
  const PdfTechApp({super.key});

  @override
  State<PdfTechApp> createState() => _PdfTechAppState();
}

class _PdfTechAppState extends State<PdfTechApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFirstLaunch());
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('first_launch_done') ?? false;
    if (shown || !mounted) return;
    // Flag écrit AVANT pour ne jamais redemander, même si l'utilisateur
    // tue l'app pendant un dialog.
    await prefs.setBool('first_launch_done', true);
    if (!mounted) return;

    // Étape 1 : welcome + accès aux fichiers
    final wantStorage = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.picture_as_pdf,
          size: 36,
          color: Color(0xFFC62828),
        ),
        title: const Text('Bienvenue dans PDF Tech'),
        content: const Text(
          'Pour parcourir vos PDFs (Téléchargements, Documents, WhatsApp, '
          'recherche globale), PDF Tech a besoin d\'accéder aux fichiers '
          'de votre téléphone.\n\n'
          'Aucun fichier n\'est transmis ailleurs.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Autoriser'),
          ),
        ],
      ),
    );
    if (wantStorage == true) {
      await Permission.manageExternalStorage.request();
    }

    if (!mounted) return;

    // Étape 2 : sources inconnues (pour les mises à jour APK)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.system_update, size: 36),
        title: const Text('Autoriser les mises à jour'),
        content: const Text(
          'Pour installer les futures mises à jour de PDF Tech, '
          'votre téléphone doit autoriser les sources inconnues.\n\n'
          'Appuyez sur "Activer" puis cochez le bouton dans les réglages qui s\'ouvrent.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _openUnknownSources();
            },
            child: const Text('Activer'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme_mode');
    if (saved != null && mounted) {
      setState(
        () => _themeMode = ThemeMode.values.firstWhere(
          (m) => m.name == saved,
          orElse: () => ThemeMode.system,
        ),
      );
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
      title: 'PDF Tech',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      darkTheme: _githubDarkTheme(),
      themeMode: _themeMode,
      home: HomeScreen(themeMode: _themeMode, onThemeChanged: _setTheme),
    );
  }
}
