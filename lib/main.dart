import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart' show pdfrxFlutterInitialize;
import 'screens/home_screen.dart';
import 'services/pdf_tools_service.dart';
import 'services/root_detection_service.dart';
import 'services/secure_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // P0 v1.13.2 — initialisation de PDFium avant tout rendu via pdfrx_engine
  // (OCR, comparaison, export images, réorganisation). Sans ça, l'ouverture
  // d'un PdfDocument dans un isolate ou en dehors d'un PdfViewer widget
  // peut échouer avec « PDFium not initialized ».
  await pdfrxFlutterInitialize();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // F2 v1.12.2 — purge des PDFs déchiffrés résiduels (cas où le process
  // a été tué entre la sortie déchiffrement et son partage/delete user).
  // Best-effort, fire-and-forget.
  unawaited(PdfToolsService.purgeDecryptedCache());
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

class _PdfTechAppState extends State<PdfTechApp> with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;

  // Clé du Navigator du MaterialApp : les dialogs de premier lancement sont
  // déclenchés depuis le context de _PdfTechAppState, qui est AU-DESSUS du
  // Navigator → `showDialog(context: context)` levait « Null check operator
  // used on a null value » (Navigator.of introuvable) et le dialog de
  // bienvenue ne s'affichait jamais. On passe par le context du Navigator.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTheme();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFirstLaunch());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // F2 v1.12.2 — purge defensive du cache de PDFs déchiffrés à chaque
    // pause / hidden / detached. Couvre le scénario "device volé après
    // déchiffrement". Le boot purge déjà au cas où le kill évite ce
    // chemin.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(PdfToolsService.purgeDecryptedCache());
    }
  }

  Future<void> _checkFirstLaunch() async {
    final shown = await SecureStorageService.readBool('first_launch_done');
    if (shown || !mounted) return;
    // Flag ecrit AVANT pour ne jamais redemander, meme si l'utilisateur
    // tue l'app pendant un dialog.
    await SecureStorageService.writeBool('first_launch_done', true);
    if (!mounted) return;

    // Context du Navigator (et non celui de _PdfTechAppState, au-dessus du
    // Navigator) — sans quoi showDialog/Navigator.of throw sur un null.
    final navContext = _navigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;

    // P0 v1.13.2+ — Dialog de bienvenue simplifie : plus de demande de
    // MANAGE_EXTERNAL_STORAGE. L'utilisateur selectionne explicitement ses
    // PDFs/dossiers via le Storage Access Framework a la demande.
    await showDialog(
      context: navContext,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.picture_as_pdf,
          size: 36,
          color: Color(0xFFC62828),
        ),
        title: const Text('Bienvenue dans PDF Tech'),
        content: const Text(
          'Ouvrez, modifiez et partagez vos PDFs en toute confidentialite.\n\n'
          'Selectionnez simplement les fichiers ou dossiers que vous souhaitez '
          'utiliser ; aucun acces global a vos fichiers n\'est requis.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Commencer'),
          ),
        ],
      ),
    );
    // Ex-etape 2 « Autoriser les mises a jour » retiree : l'app ne s'auto-
    // installe pas d'APK (UpdateService = check-only, « pas d'auto-download »),
    // et sans REQUEST_INSTALL_PACKAGES le toggle systeme « sources inconnues »
    // est grise -> cul-de-sac pour l'utilisateur.

    if (!mounted) return;
    await _showRootWarningIfNeeded();
  }

  Future<void> _showRootWarningIfNeeded() async {
    final navContext = _navigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;
    try {
      final rooted = await RootDetectionService.isRooted();
      if (!rooted || !navContext.mounted) return;
      await showDialog(
        context: navContext,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.security, color: Colors.orange),
          title: const Text('Appareil modifie detecte'),
          content: const Text(
            'Cet appareil semble etre root ou jailbreak. PDF Tech continue de '
            'fonctionner, mais la confidentialite de vos documents peut etre '
            'reduite sur un systeme modifie.',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('J\'ai compris'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[main] root detection error: $e');
    }
  }

  Future<void> _loadTheme() async {
    final saved = await SecureStorageService.readString('theme_mode');
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
    await SecureStorageService.writeString('theme_mode', mode.name);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Tech',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: _lightTheme,
      darkTheme: _githubDarkTheme(),
      themeMode: _themeMode,
      home: HomeScreen(themeMode: _themeMode, onThemeChanged: _setTheme),
    );
  }
}

/// U2 v1.12.4 — Light theme désormais cohérent avec le dark theme :
/// `snackBarTheme.behavior = floating` (sans ça, `snack_utils` mentait
/// en light mode), `cardTheme`/`inputDecorationTheme` Material 3
/// uniformes. Calculé 1 fois au démarrage (static final).
final ThemeData _lightTheme = (() {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0));
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(),
    ),
  );
})();
