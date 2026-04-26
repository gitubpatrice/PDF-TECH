import 'dart:io';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class GoogleDriveService {
  final _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/drive.file'],
  );

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<bool> isSignedIn() => _googleSignIn.isSignedIn();

  Future<GoogleSignInAccount?> signIn() => _googleSignIn.signIn();

  Future<void> signOut() => _googleSignIn.signOut();

  Future<drive.DriveApi> _getApi() async {
    GoogleSignInAccount? account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    account ??= await _googleSignIn.signIn();
    if (account == null) throw Exception('Connexion Google annulée');
    final headers = await account.authHeaders;
    final client = _GoogleAuthClient(headers);
    return drive.DriveApi(client);
  }

  /// Uploads a local PDF file to Google Drive. Returns the file ID.
  Future<String> uploadFile(String path) async {
    final api = await _getApi();
    final file = File(path);
    final name = path.split(RegExp(r'[/\\]')).last;
    final driveFile = drive.File()
      ..name = name
      ..mimeType = 'application/pdf';
    final result = await api.files.create(
      driveFile,
      uploadMedia: drive.Media(file.openRead(), file.lengthSync()),
    );
    if (result.id == null) throw Exception('Upload échoué : ID nul');
    return result.id!;
  }

  /// Lists PDF files on Drive (non-trashed).
  Future<List<drive.File>> listPdfFiles() async {
    final api = await _getApi();
    final response = await api.files.list(
      q: "mimeType='application/pdf' and trashed=false",
      $fields: 'files(id,name,size,modifiedTime)',
    );
    return response.files ?? [];
  }

  /// Downloads a Drive file to [localDir] and returns the local path.
  Future<String> downloadFile(drive.File driveFile, String localDir) async {
    final api = await _getApi();
    final media = await api.files.get(
      driveFile.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }

    final name = driveFile.name ?? 'document.pdf';
    final localPath = '$localDir/$name';
    await File(localPath).writeAsBytes(Uint8List.fromList(bytes));
    return localPath;
  }
}

// ── Auth client ───────────────────────────────────────────────────────────────

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}
