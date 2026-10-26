import 'package:flutter/material.dart';

/// Main-page origins are shared even when their content layouts differ.
/// 页面共享的留白与背景常量；abstract final 表示只提供静态成员，不创建实例。
abstract final class AppPage {
  static const navigationBackground = Color(0xfff6f6f6);
  static EdgeInsets insets(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 900
      ? const EdgeInsets.fromLTRB(20, 20, 20, 28)
      : const EdgeInsets.fromLTRB(32, 24, 32, 28);
}

/// 共用标题样式，让三个入口和执行页保持一致的阅读起点。
class PageTitle extends StatelessWidget {
  const PageTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.headlineMedium);
}
