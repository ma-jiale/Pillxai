import 'package:flutter/material.dart';

/// Authentication is supplied by the application session, never by the page.
/// 控制器随页面销毁，退出后重新进入时不会保留密码。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLogin});
  final Future<void> Function(String username, String password) onLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _account = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  String? _error;
  bool _pending = false;

  @override
  void dispose() {
    _account.dispose();
    _password.dispose();
    super.dispose();
  }

  /// 校验输入，失败显示错误且保留草稿；成功通知父组件，不持久化密码。
  Future<void> _login() async {
    if (_pending) return;
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _pending = true);
    FocusScope.of(context).unfocus();
    try {
      await widget.onLogin(_account.text.trim(), _password.text);
      if (mounted) _password.clear();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff7f7f6),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, bounds) {
          final compact = bounds.maxWidth < 600;
          final padding = compact ? 24.0 : 40.0;
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: bounds.maxHeight),
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Text(
                          'Pillxai',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -.8,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 44 : 64),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 432),
                      child: Container(
                        padding: EdgeInsets.all(compact ? 24 : 36),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xffe7e7e5)),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                '欢迎回来',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '登录 Pillxai，开始今天的工作。',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xff777777),
                                ),
                              ),
                              const SizedBox(height: 32),
                              const Text('账号', style: TextStyle(fontSize: 13)),
                              const SizedBox(height: 8),
                              TextFormField(
                                key: const ValueKey('login-account'),
                                controller: _account,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: const InputDecoration(
                                  hintText: '输入账号',
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? '请输入账号'
                                    : null,
                              ),
                              const SizedBox(height: 20),
                              const Text('密码', style: TextStyle(fontSize: 13)),
                              const SizedBox(height: 8),
                              TextFormField(
                                key: const ValueKey('login-password'),
                                controller: _password,
                                obscureText: _obscurePassword,
                                autocorrect: false,
                                enableSuggestions: false,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _login(),
                                decoration: InputDecoration(
                                  hintText: '输入密码',
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? '请输入密码'
                                    : null,
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 28),
                              FilledButton(
                                key: const ValueKey('login-submit'),
                                onPressed: _pending ? null : _login,
                                child: Text(_pending ? '登录中…' : '登录'),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                '账号由管理员分配',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xff888888),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
