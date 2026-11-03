import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_client/data/backend_connection.dart';
import 'package:pillxai_client/data/session_store.dart';
import 'package:pillxai_client/main.dart';

import 'connected_prescriptions_test.dart' show jsonResponse, actorId;
import 'server_planning_test.dart' show settingsJson;
import 'support/production_fixture.dart';

class MemorySessions implements SessionStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String server) async => values[server];
  @override
  Future<void> write(String server, String token) async {
    values[server] = token;
  }

  @override
  Future<void> delete(String server) async {
    values.remove(server);
  }
}

final account = {
  'id': actorId,
  'username': 'fixture',
  'display_name': '管理员',
  'role': 'admin',
  'can_maintain': true,
  'active': true,
  'revision': 1,
};

BackendConnection backend(
  MemorySessions sessions,
  Future<http.Response> Function(http.Request) respond,
) {
  final client = api.ApiClient(basePath: 'http://localhost');
  client.client.close();
  client.client = MockClient(respond);
  return BackendConnection(client: client, sessionStore: sessions);
}

void main() {
  test('login stores only token, next connection restores latest account and logout clears it', () async {
    final sessions = MemorySessions();
    var logins = 0;
    Future<http.Response> respond(http.Request request) async {
      switch (request.url.path) {
        case '/auth/login':
          logins++;
          return jsonResponse({
            'access_token': 'fake-token',
            'expires_at': '2030-01-01T00:00:00Z',
            'account': account,
          });
        case '/auth/me':
          expect(request.headers['Authorization'], 'Bearer fake-token');
          return jsonResponse({...account, 'display_name': '最新姓名'});
        case '/settings':
          return jsonResponse(settingsJson);
        case '/auth/logout':
          return jsonResponse({'ok': true});
      }
      throw StateError(request.url.path);
    }

    final first = backend(sessions, respond);
    await first.login('fixture', 'fixture-only-password');
    first.dispose();
    expect(sessions.values, {'http://localhost': 'fake-token'});
    final reopened = backend(sessions, respond);
    addTearDown(reopened.dispose);
    expect(await reopened.restoreLogin(), isTrue);
    expect(reopened.account!.displayName, '最新姓名');
    expect(logins, 1);
    await reopened.logout();
    expect(sessions.values, isEmpty);
    expect(await reopened.restoreLogin(), isFalse);
  });

  for (final status in [401, 503]) {
    test('restore status $status clears only invalid sessions', () async {
      final sessions = MemorySessions()
        ..values['http://localhost'] = 'saved-token';
      var online = false;
      final connection = backend(sessions, (request) async {
        if (online) {
          return jsonResponse(
            request.url.path == '/auth/me' ? account : settingsJson,
          );
        }
        return jsonResponse({
          'code': status == 401 ? 'session_expired' : 'offline',
          'message': 'fixture error',
        }, status);
      });
      addTearDown(connection.dispose);
      if (status == 401) {
        expect(await connection.restoreLogin(), isFalse);
        expect(sessions.values, isEmpty);
      } else {
        await expectLater(connection.restoreLogin(), throwsException);
        expect(sessions.values['http://localhost'], 'saved-token');
        expect(connection.account, isNull);
        online = true;
        expect(await connection.restoreLogin(), isTrue);
      }
    });
  }

  testWidgets('saved login opens workspace without password form', (
    tester,
  ) async {
    final fixture = ProductionFixture();
    addTearDown(fixture.dispose);
    final sessions = MemorySessions()
      ..values['http://localhost'] = 'saved-token';
    final connection = backend(
      sessions,
      (request) async => request.url.path == '/auth/me'
          ? jsonResponse(account)
          : fixture.respond(request),
    );
    addTearDown(connection.dispose);
    await tester.pumpWidget(
      PillxaiApp(backend: connection, terminalHost: fixture.host),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('login-password')), findsNothing);
    expect(find.byKey(const ValueKey('scan-resident')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
