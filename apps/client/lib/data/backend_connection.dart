import 'dart:async';
import 'dart:convert';

import 'package:pillxai_api_client/api.dart' as api;

import '../models/prescription_store.dart';

/// Owns one in-memory login token. No password/token is written to preferences.
class BackendConnection {
  BackendConnection({api.ApiClient? client})
    : client =
          client ??
          api.ApiClient(
            basePath: const String.fromEnvironment(
              'PILLXAI_API_URL',
              defaultValue: 'http://127.0.0.1:8000',
            ),
          );

  final api.ApiClient client;
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
        final message = body is Map<String, dynamic>
            ? api.ApiError.fromJson(body)?.message
            : null;
        if (message != null) throw SaveFailure(message);
      } on FormatException {
        // A proxy or disconnected service can return a non-JSON response.
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
      account = result.account;
    } catch (_) {
      _setToken('');
      rethrow;
    }
  }

  Future<void> logout() async {
    // Do not report logout success before the server has revoked the session.
    try {
      await request(identity.logout());
    } on SaveFailure catch (error) {
      // Expired/disabled tokens already have no authority; other failures remain visible.
      if (!error.message.contains('登录已失效')) rethrow;
    }
    _setToken('');
    account = null;
    settings = null;
  }

  void dispose() => client.client.close();
}
