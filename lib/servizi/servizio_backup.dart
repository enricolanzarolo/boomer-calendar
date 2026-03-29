import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../database/gestore_database.dart';

class BackupService {
  static final BackupService instance = BackupService._();
  BackupService._();

  static const _backupFileName = 'mamma_calendar_backup.json';
  static const _backupFolder   = 'MammaCalendar';
  static const _lastBackupKey  = 'last_backup_timestamp';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  GoogleSignInAccount? _currentUser;

  bool get isSignedIn => _currentUser != null;
  String? get userEmail => _currentUser?.email;

  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  Future<drive.DriveApi?> _getApi() async {
    final user = _currentUser ?? await _googleSignIn.signInSilently();
    if (user == null) return null;
    _currentUser = user;
    final auth = await user.authentication;
    return drive.DriveApi(_AuthClient(auth.accessToken!));
  }

  Future<String> _getOrCreateFolder(drive.DriveApi api) async {
    final q = "name = '$_backupFolder' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
    final list = await api.files.list(q: q, spaces: 'drive');
    if (list.files != null && list.files!.isNotEmpty) {
      return list.files!.first.id!;
    }
    final folder = drive.File()
      ..name = _backupFolder
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await api.files.create(folder);
    return created.id!;
  }

  Future<BackupResult> backup() async {
    try {
      final api = await _getApi();
      if (api == null) return BackupResult.notSignedIn;

      final data  = await DatabaseHelper.instance.exportAll();
      final bytes = utf8.encode(jsonEncode(data));
      final folderId = await _getOrCreateFolder(api);

      final q = "name = '$_backupFileName' and '$folderId' in parents and trashed = false";
      final existing = await api.files.list(q: q);
      final media = drive.Media(Stream.value(bytes), bytes.length, contentType: 'application/json');

      if (existing.files != null && existing.files!.isNotEmpty) {
        await api.files.update(
          drive.File()..name = _backupFileName,
          existing.files!.first.id!,
          uploadMedia: media,
        );
      } else {
        final file = drive.File()..name = _backupFileName..parents = [folderId];
        await api.files.create(file, uploadMedia: media);
      }

      // Salva timestamp ultimo backup
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastBackupKey, DateTime.now().millisecondsSinceEpoch);

      return BackupResult.success;
    } catch (_) {
      return BackupResult.error;
    }
  }

  /// Controlla se è passato un mese dall'ultimo backup e lo fa automaticamente
  Future<void> checkAutoBackup() async {
    if (!isSignedIn) {
      // Prova login silenzioso
      final user = await _googleSignIn.signInSilently();
      if (user == null) return;
      _currentUser = user;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastTs = prefs.getInt(_lastBackupKey) ?? 0;
    final lastBackup = DateTime.fromMillisecondsSinceEpoch(lastTs);
    final now = DateTime.now();

    // Se è passato più di 30 giorni, fai backup automatico
    if (now.difference(lastBackup).inDays >= 30) {
      await backup();
    }
  }

  Future<RestoreResult> restore() async {
    try {
      final api = await _getApi();
      if (api == null) return RestoreResult.notSignedIn;

      final folderId = await _getOrCreateFolder(api);
      final q = "name = '$_backupFileName' and '$folderId' in parents and trashed = false";
      final list = await api.files.list(q: q);
      if (list.files == null || list.files!.isEmpty) return RestoreResult.noBackupFound;

      final media = await api.files.get(
        list.files!.first.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final chunks = <int>[];
      await for (final chunk in media.stream) chunks.addAll(chunk);

      final data = jsonDecode(utf8.decode(chunks)) as Map<String, dynamic>;
      await DatabaseHelper.instance.importAll(data);
      return RestoreResult.success;
    } catch (_) {
      return RestoreResult.error;
    }
  }

  Future<DateTime?> getLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_lastBackupKey);
    return ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null;
  }
}

enum BackupResult  { success, error, notSignedIn }
enum RestoreResult { success, error, notSignedIn, noBackupFound }

class _AuthClient extends http.BaseClient {
  final String _token;
  final _inner = http.Client();
  _AuthClient(this._token);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }
}
