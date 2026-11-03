import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores only the revocable session token, isolated by deployment address.
abstract interface class SessionStore {
  Future<String?> read(String server);
  Future<void> write(String server, String token);
  Future<void> delete(String server);
}

class SecureSessionStore implements SessionStore {
  const SecureSessionStore();
  static const _storage = FlutterSecureStorage();
  String _key(String server) =>
      'pillxai_session_${base64Url.encode(utf8.encode(server))}';

  @override
  Future<String?> read(String server) => _storage.read(key: _key(server));
  @override
  Future<void> write(String server, String token) =>
      _storage.write(key: _key(server), value: token);
  @override
  Future<void> delete(String server) => _storage.delete(key: _key(server));
}
