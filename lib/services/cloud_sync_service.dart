import 'dart:convert';
import 'dart:developer' as dev;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'backup_service.dart';
import 'storage_service.dart';

/// Syncs app data to/from Google Drive's hidden App Data folder.
///
/// Uses [google_sign_in] for OAuth and [googleapis] for the Drive API.
/// The backup file is stored in the `appDataFolder` space, which is
/// invisible to the user in their Google Drive but tied to their account.
class CloudSyncService {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  static const _backupFileName = 'daily_account_backup.json';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
  );

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  /// Try to restore a previous session without user interaction.
  Future<bool> silentSignIn() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      return _currentUser != null;
    } catch (_) {
      return false;
    }
  }

  /// Last sign-in error detail (for debugging).
  String? lastError;

  /// Prompt the user to sign in with Google.
  Future<bool> signIn() async {
    lastError = null;
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser == null) {
        lastError = 'Sign-in returned null (user cancelled or scope denied)';
        dev.log('CloudSync: signIn returned null', name: 'CloudSync');
        return false;
      }
      // Verify we can get auth headers (this triggers scope consent)
      try {
        await _currentUser!.authHeaders;
      } catch (e) {
        lastError = 'Auth headers failed: $e';
        dev.log('CloudSync: authHeaders failed: $e', name: 'CloudSync');
      }
      await StorageService.instance.setSetting('cloudSignedIn', 'true');
      return true;
    } catch (e, st) {
      lastError = '$e';
      dev.log('CloudSync: signIn error: $e\n$st', name: 'CloudSync');
      return false;
    }
  }

  /// Sign out (does not revoke access).
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    _currentUser = null;
    await StorageService.instance.setSetting('cloudSignedIn', '');
  }

  /// Get an authenticated Drive API client.
  Future<drive.DriveApi?> _getDriveApi() async {
    if (_currentUser == null) {
      lastError = 'Not signed in';
      return null;
    }
    try {
      final headers = await _currentUser!.authHeaders;
      final client = _GoogleAuthClient(headers);
      return drive.DriveApi(client);
    } catch (e) {
      dev.log('CloudSync: auth headers failed, trying silent refresh: $e', name: 'CloudSync');
      // Auth might have expired — try silent refresh
      if (await silentSignIn()) {
        try {
          final headers = await _currentUser!.authHeaders;
          final client = _GoogleAuthClient(headers);
          return drive.DriveApi(client);
        } catch (e2) {
          lastError = 'Auth refresh failed: $e2';
          dev.log('CloudSync: auth refresh also failed: $e2', name: 'CloudSync');
        }
      } else {
        lastError = 'Session expired — please sign in again';
      }
      return null;
    }
  }

  /// Upload a full backup to Google Drive's App Data folder.
  /// Returns true on success.
  Future<bool> backupToDrive() async {
    lastError = null;
    if (!isSignedIn) {
      lastError = 'Not signed in';
      return false;
    }
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false; // lastError already set by _getDriveApi

      // Build comprehensive backup data
      final data = await BackupService.instance.buildFullBackupData();
      if (data == null) {
        lastError = 'No data to back up';
        return false;
      }

      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final bytes = utf8.encode(jsonStr);
      final media = drive.Media(
        Stream.value(bytes),
        bytes.length,
        contentType: 'application/json',
      );

      // Check if backup file already exists
      final existingId = await _findBackupFileId(driveApi);

      if (existingId != null) {
        // Update existing file
        await driveApi.files.update(
          drive.File(),
          existingId,
          uploadMedia: media,
        );
      } else {
        // Create new file in appDataFolder
        final fileMetadata = drive.File()
          ..name = _backupFileName
          ..parents = ['appDataFolder'];
        await driveApi.files.create(
          fileMetadata,
          uploadMedia: media,
        );
      }

      // Persist last backup timestamp
      await StorageService.instance.setSetting(
        'cloudLastBackupDate',
        DateTime.now().toIso8601String(),
      );
      return true;
    } catch (e, st) {
      lastError = 'Backup failed: $e';
      dev.log('CloudSync: backupToDrive error: $e\n$st', name: 'CloudSync');
      return false;
    }
  }

  /// Download backup data from Google Drive.
  /// Returns the parsed JSON map, or null if no backup exists or on error.
  Future<Map<String, dynamic>?> downloadFromDrive() async {
    lastError = null;
    if (!isSignedIn) {
      lastError = 'Not signed in';
      return null;
    }
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return null; // lastError already set

      final fileId = await _findBackupFileId(driveApi);
      if (fileId == null) {
        lastError = 'No backup found on Google Drive';
        return null;
      }

      final response = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final chunks = <List<int>>[];
      await for (final chunk in response.stream) {
        chunks.add(chunk);
      }
      final jsonStr = utf8.decode(chunks.expand((c) => c).toList());
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e, st) {
      lastError = 'Download failed: $e';
      dev.log('CloudSync: downloadFromDrive error: $e\n$st', name: 'CloudSync');
      return null;
    }
  }

  /// Restore all app data from a Google Drive backup.
  /// Replaces local data entirely (not merge).
  Future<bool> restoreFromDrive() async {
    final data = await downloadFromDrive();
    if (data == null) return false;
    return BackupService.instance.importData(data, merge: false);
  }

  /// Get metadata about the remote backup (for display purposes).
  /// Returns the last modified date string, or null if no backup exists.
  Future<String?> getRemoteBackupDate() async {
    if (!isSignedIn) return null;
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return null;

      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName'",
        $fields: 'files(id, modifiedTime)',
      );

      if (fileList.files == null || fileList.files!.isEmpty) return null;
      return fileList.files!.first.modifiedTime?.toIso8601String();
    } catch (e) {
      dev.log('CloudSync: getRemoteBackupDate error: $e', name: 'CloudSync');
      return null;
    }
  }

  /// Find the existing backup file ID in appDataFolder.
  Future<String?> _findBackupFileId(drive.DriveApi driveApi) async {
    try {
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName'",
        $fields: 'files(id)',
      );
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id;
      }
    } catch (e) {
      dev.log('CloudSync: _findBackupFileId error: $e', name: 'CloudSync');
    }
    return null;
  }
}

/// Wraps auth headers from Google Sign-In into an [http.BaseClient]
/// that [googleapis] can use.
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
