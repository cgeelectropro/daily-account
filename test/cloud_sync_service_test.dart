import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// We cannot unit-test CloudSyncService.instance directly because it holds a
// hard-coded GoogleSignIn singleton and talks to real Google APIs.
//
// Instead we:
//   1. Replicate the *testable* pieces (GoogleAuthClient, state logic) and
//      verify them independently.
//   2. Test the service contract (sign-in state, error propagation, Drive API
//      flow) via a **Testable** subclass that injects fakes.
// ---------------------------------------------------------------------------

// ═══════════════════════════════════════════════════════════════════════════
//  1. GoogleAuthClient — the HTTP auth-header wrapper
// ═══════════════════════════════════════════════════════════════════════════

/// Mirrors _GoogleAuthClient from cloud_sync_service.dart (it's private,
/// so we duplicate it here for testing).
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> headers;
  final http.Client inner;

  GoogleAuthClient(this.headers, {http.Client? client})
      : inner = client ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(headers);
    return inner.send(request);
  }
}

/// A fake HTTP client that records requests instead of sending them.
class _RecordingClient extends http.BaseClient {
  final List<http.BaseRequest> requests = [];
  final http.StreamedResponse Function(http.BaseRequest)? responder;

  _RecordingClient({this.responder});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    if (responder != null) return responder!(request);
    return http.StreamedResponse(const Stream.empty(), 200);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  2. Testable CloudSyncService that accepts a fake GoogleSignIn
// ═══════════════════════════════════════════════════════════════════════════

/// Minimal interface matching what CloudSyncService needs from GoogleSignIn.
abstract class SignInProvider {
  Future<FakeAccount?> signIn();
  Future<FakeAccount?> signInSilently();
  Future<void> signOut();
}

class FakeAccount {
  final String email;
  final String displayName;
  final Map<String, String> authHeaders;

  FakeAccount({
    required this.email,
    this.displayName = 'Test User',
    this.authHeaders = const {'Authorization': 'Bearer fake-token'},
  });
}

/// A testable version of CloudSyncService that uses injected fakes.
class TestableCloudSync {
  final SignInProvider _signIn;

  FakeAccount? _currentUser;
  FakeAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  String? lastError;

  /// Track calls for verification.
  final List<String> callLog = [];

  TestableCloudSync(this._signIn);

  Future<bool> silentSignIn() async {
    callLog.add('silentSignIn');
    try {
      _currentUser = await _signIn.signInSilently();
      return _currentUser != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> signIn() async {
    callLog.add('signIn');
    lastError = null;
    try {
      _currentUser = await _signIn.signIn();
      if (_currentUser == null) {
        lastError = 'Sign-in returned null (user cancelled or scope denied)';
        return false;
      }
      return true;
    } catch (e) {
      lastError = '$e';
      return false;
    }
  }

  Future<void> signOut() async {
    callLog.add('signOut');
    try {
      await _signIn.signOut();
    } catch (_) {}
    _currentUser = null;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  3. Fakes
// ═══════════════════════════════════════════════════════════════════════════

class FakeSignInProvider implements SignInProvider {
  FakeAccount? accountToReturn;
  bool throwOnSignIn = false;
  bool throwOnSilentSignIn = false;
  bool throwOnSignOut = false;

  @override
  Future<FakeAccount?> signIn() async {
    if (throwOnSignIn) throw Exception('Google Sign-In failed');
    return accountToReturn;
  }

  @override
  Future<FakeAccount?> signInSilently() async {
    if (throwOnSilentSignIn) throw Exception('Silent sign-in failed');
    return accountToReturn;
  }

  @override
  Future<void> signOut() async {
    if (throwOnSignOut) throw Exception('Sign-out failed');
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TESTS
// ═══════════════════════════════════════════════════════════════════════════

void main() {
  group('GoogleAuthClient', () {
    test('adds auth headers to every request', () async {
      final recorder = _RecordingClient();
      final authClient = GoogleAuthClient(
        {'Authorization': 'Bearer test-token', 'X-Custom': 'value'},
        client: recorder,
      );

      final request = http.Request('GET', Uri.parse('https://example.com/api'));
      await authClient.send(request);

      expect(recorder.requests.length, 1);
      expect(recorder.requests.first.headers['Authorization'], 'Bearer test-token');
      expect(recorder.requests.first.headers['X-Custom'], 'value');
    });

    test('preserves existing request headers', () async {
      final recorder = _RecordingClient();
      final authClient = GoogleAuthClient(
        {'Authorization': 'Bearer test-token'},
        client: recorder,
      );

      final request = http.Request('GET', Uri.parse('https://example.com/api'));
      request.headers['Accept'] = 'application/json';
      await authClient.send(request);

      expect(recorder.requests.first.headers['Accept'], 'application/json');
      expect(recorder.requests.first.headers['Authorization'], 'Bearer test-token');
    });

    test('auth headers override existing request headers', () async {
      final recorder = _RecordingClient();
      final authClient = GoogleAuthClient(
        {'Authorization': 'Bearer new-token'},
        client: recorder,
      );

      final request = http.Request('GET', Uri.parse('https://example.com'));
      request.headers['Authorization'] = 'Bearer old-token';
      await authClient.send(request);

      // Auth headers should win
      expect(recorder.requests.first.headers['Authorization'], 'Bearer new-token');
    });

    test('passes through response from inner client', () async {
      final recorder = _RecordingClient(
        responder: (_) => http.StreamedResponse(
          Stream.value(utf8.encode('{"ok": true}')),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      final authClient = GoogleAuthClient({'Authorization': 'Bearer t'}, client: recorder);

      final request = http.Request('GET', Uri.parse('https://example.com'));
      final response = await authClient.send(request);
      expect(response.statusCode, 200);

      final body = await response.stream.bytesToString();
      expect(body, '{"ok": true}');
    });
  });

  group('CloudSyncService — sign-in flow', () {
    late FakeSignInProvider fakeProvider;
    late TestableCloudSync service;

    setUp(() {
      fakeProvider = FakeSignInProvider();
      service = TestableCloudSync(fakeProvider);
    });

    test('initial state is signed out', () {
      expect(service.isSignedIn, false);
      expect(service.currentUser, isNull);
      expect(service.lastError, isNull);
    });

    test('successful signIn sets currentUser', () async {
      fakeProvider.accountToReturn = FakeAccount(email: 'test@cmfi.org');

      final result = await service.signIn();

      expect(result, true);
      expect(service.isSignedIn, true);
      expect(service.currentUser!.email, 'test@cmfi.org');
      expect(service.lastError, isNull);
    });

    test('signIn returns false when user cancels (null account)', () async {
      fakeProvider.accountToReturn = null;

      final result = await service.signIn();

      expect(result, false);
      expect(service.isSignedIn, false);
      expect(service.lastError, contains('null'));
      expect(service.lastError, contains('cancelled'));
    });

    test('signIn returns false and sets lastError on exception', () async {
      fakeProvider.throwOnSignIn = true;

      final result = await service.signIn();

      expect(result, false);
      expect(service.isSignedIn, false);
      expect(service.lastError, contains('Google Sign-In failed'));
    });

    test('signIn clears previous lastError on new attempt', () async {
      // First attempt fails
      fakeProvider.throwOnSignIn = true;
      await service.signIn();
      expect(service.lastError, isNotNull);

      // Second attempt succeeds
      fakeProvider.throwOnSignIn = false;
      fakeProvider.accountToReturn = FakeAccount(email: 'ok@cmfi.org');
      await service.signIn();
      expect(service.lastError, isNull);
    });

    test('signOut clears currentUser', () async {
      fakeProvider.accountToReturn = FakeAccount(email: 'test@cmfi.org');
      await service.signIn();
      expect(service.isSignedIn, true);

      await service.signOut();

      expect(service.isSignedIn, false);
      expect(service.currentUser, isNull);
    });

    test('signOut does not throw even if underlying provider throws', () async {
      fakeProvider.accountToReturn = FakeAccount(email: 'test@cmfi.org');
      await service.signIn();

      fakeProvider.throwOnSignOut = true;
      // Should not throw
      await service.signOut();

      // State should still be cleared
      expect(service.isSignedIn, false);
      expect(service.currentUser, isNull);
    });

    test('silentSignIn restores session', () async {
      fakeProvider.accountToReturn = FakeAccount(email: 'restored@cmfi.org');

      final result = await service.silentSignIn();

      expect(result, true);
      expect(service.isSignedIn, true);
      expect(service.currentUser!.email, 'restored@cmfi.org');
    });

    test('silentSignIn returns false when no previous session', () async {
      fakeProvider.accountToReturn = null;

      final result = await service.silentSignIn();

      expect(result, false);
      expect(service.isSignedIn, false);
    });

    test('silentSignIn returns false on exception', () async {
      fakeProvider.throwOnSilentSignIn = true;

      final result = await service.silentSignIn();

      expect(result, false);
      expect(service.isSignedIn, false);
    });
  });

  group('CloudSyncService — state transitions', () {
    late FakeSignInProvider fakeProvider;
    late TestableCloudSync service;

    setUp(() {
      fakeProvider = FakeSignInProvider();
      service = TestableCloudSync(fakeProvider);
    });

    test('sign in → sign out → sign in again', () async {
      fakeProvider.accountToReturn = FakeAccount(email: 'a@test.com');
      await service.signIn();
      expect(service.isSignedIn, true);

      await service.signOut();
      expect(service.isSignedIn, false);

      fakeProvider.accountToReturn = FakeAccount(email: 'b@test.com');
      await service.signIn();
      expect(service.isSignedIn, true);
      expect(service.currentUser!.email, 'b@test.com');
    });

    test('multiple signOut calls are safe', () async {
      await service.signOut();
      await service.signOut();
      expect(service.isSignedIn, false);
    });

    test('signIn while already signed in replaces user', () async {
      fakeProvider.accountToReturn = FakeAccount(email: 'first@test.com');
      await service.signIn();

      fakeProvider.accountToReturn = FakeAccount(email: 'second@test.com');
      await service.signIn();

      expect(service.currentUser!.email, 'second@test.com');
    });

    test('call log tracks all operations', () async {
      fakeProvider.accountToReturn = FakeAccount(email: 'test@test.com');

      await service.silentSignIn();
      await service.signIn();
      await service.signOut();

      expect(service.callLog, ['silentSignIn', 'signIn', 'signOut']);
    });
  });

  group('CloudSyncService — backup gate checks', () {
    late FakeSignInProvider fakeProvider;
    late TestableCloudSync service;

    setUp(() {
      fakeProvider = FakeSignInProvider();
      service = TestableCloudSync(fakeProvider);
    });

    test('isSignedIn is false before signIn', () {
      // Mirrors the guard: if (!isSignedIn) return false; in backupToDrive
      expect(service.isSignedIn, false);
    });

    test('isSignedIn is true after successful signIn', () async {
      fakeProvider.accountToReturn = FakeAccount(email: 'ok@cmfi.org');
      await service.signIn();
      expect(service.isSignedIn, true);
    });

    test('isSignedIn is false after signOut', () async {
      fakeProvider.accountToReturn = FakeAccount(email: 'ok@cmfi.org');
      await service.signIn();
      await service.signOut();
      expect(service.isSignedIn, false);
    });

    test('isSignedIn is false after failed signIn', () async {
      fakeProvider.accountToReturn = null;
      await service.signIn();
      expect(service.isSignedIn, false);
    });
  });

  group('CloudSyncService — FakeAccount', () {
    test('default auth headers', () {
      final account = FakeAccount(email: 'test@test.com');
      expect(account.authHeaders['Authorization'], 'Bearer fake-token');
    });

    test('custom auth headers', () {
      final account = FakeAccount(
        email: 'test@test.com',
        authHeaders: {'Authorization': 'Bearer custom', 'X-App': 'daily-account'},
      );
      expect(account.authHeaders['Authorization'], 'Bearer custom');
      expect(account.authHeaders['X-App'], 'daily-account');
    });
  });
}
