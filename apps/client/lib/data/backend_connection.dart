import 'dart:async';
import 'dart:convert';

import 'package:pillxai_api_client/api.dart' as api;

import '../models/prescription_store.dart';
import 'session_store.dart';

class SessionExpired extends SaveFailure {
  const SessionExpired() : super('登录已失效，请重新登录。');
}

/// Owns the validated login; optional secure storage restores it across launches.
class BackendConnection {
  BackendConnection({api.ApiClient? client, this.sessionStore})
    : client =
          client ??
          api.ApiClient(
            basePath: const String.fromEnvironment(
              'PILLXAI_API_URL',
              defaultValue: 'https://ixd.sjtu.edu.cn/pillxai',
            ),
          );

  final api.ApiClient client;
  final SessionStore? sessionStore;
  late final identity = api.IdentityApi(client);
  late final settingsApi = api.SettingsApi(client);
  late final residents = api.ResidentsApi(client);
  late final prescriptions = api.PrescriptionsApi(client);
  api.AccountView? account;
  api.AppSettings? settings;

  void _setToken(String token) {
    if (token.isEmpty) {
      client.defaultHeaderMap.remove('Authorization');
    } else {
      client.addDefaultHeader('Authorization', 'Bearer $token');
    }
  }

  Future<T> request<T>(Future<T> operation) async {
    try {
      return await operation.timeout(const Duration(seconds: 15));
    } on api.ApiException catch (error) {
      try {
        final body = jsonDecode(error.message ?? '');
        if (error.code == 401 &&
            (body is! Map || body['code'] != 'invalid_credentials')) {
          throw const SessionExpired();
        }
        final message = body is Map<String, dynamic>
            ? api.ApiError.fromJson(body)?.message
            : null;
        if (message != null) throw SaveFailure(message);
      } on FormatException {
        // A proxy or disconnected service can return a non-JSON response.
        if (error.code == 401) throw const SessionExpired();
      }
      throw const SaveFailure('服务暂时不可用，请稍后重试。');
    } on TimeoutException {
      throw const SaveFailure('请求超时，保存结果尚未确认。请保留草稿并刷新核对，避免重复新增。');
    } on SaveFailure {
      rethrow;
    } catch (_) {
      throw const SaveFailure('无法连接服务器。保存结果尚未确认，请检查连接后刷新核对。');
    }
  }

  Future<void> login(String username, String password) async {
    final result = await request(
      identity.login(api.Login(username: username, password: password)),
    );
    if (result == null) throw const SaveFailure('登录响应不完整，请重试。');
    _setToken(result.accessToken);
    try {
      settings = await request(settingsApi.getSettings());
      if (settings == null) throw const SaveFailure('设置响应不完整，请重试。');
      await sessionStore?.write(client.basePath, result.accessToken);
      account = result.account;
    } catch (_) {
      _setToken('');
      account = null;
      settings = null;
      rethrow;
    }
  }

  Future<bool> restoreLogin() async {
    if (account != null && settings != null) return true;
    final token = await sessionStore?.read(client.basePath);
    if (token == null || token.isEmpty) return false;
    _setToken(token);
    try {
      final restored = await request(identity.getAccount());
      final restoredSettings = await request(settingsApi.getSettings());
      if (restored == null || restoredSettings == null) {
        throw const SaveFailure('登录状态读取不完整，请重试。');
      }
      account = restored;
      settings = restoredSettings;
      return true;
    } on SessionExpired {
      await sessionStore?.delete(client.basePath);
      return false;
    } finally {
      // Temporary network failure retains the saved token for a later retry.
      if (account == null) _setToken('');
    }
  }

  Future<void> logout() async {
    // Do not report logout success before the server has revoked the session.
    try {
      await request(identity.logout());
    } on SessionExpired {
      // Expired/disabled tokens already have no authority; other failures remain visible.
    }
    await sessionStore?.delete(client.basePath);
    _setToken('');
    account = null;
    settings = null;
  }

  void dispose() => client.client.close();
}
