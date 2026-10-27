import 'package:flutter/material.dart';

import 'data/android_runtime_stub.dart'
    if (dart.library.io) 'data/android_runtime.dart'
    as android;

import 'package:flutter_localizations/flutter_localizations.dart';

import 'models/demo_model.dart';
import 'models/device_preview_model.dart';
import 'screens/devices_page.dart';
import 'screens/preparation_page.dart';
import 'screens/login_page.dart';
import 'screens/prescriptions_page.dart';
import 'screens/settings_page.dart';
import 'screens/history_page.dart';
import 'screens/connected_workspace.dart';
import 'models/prescription_store.dart';
import 'theme/app_theme.dart';
import 'theme/app_page.dart';
import 'widgets/workspace_sidebar.dart';

/// 程序入口。=> 是单表达式函数的简写，等价于 { runApp(...); }。
/// const 创建不可变配置；运行中的可变数据由下面的 State 保存。
void main() =>
    runApp(const PillxaiApp(demo: bool.fromEnvironment('PILLXAI_DEMO')));

@pragma('vm:entry-point')
void terminalServiceMain() => android.runTerminalService();

/// 应用的根配置。model 可由测试注入；日常启动时由 State 创建并持有。
/// Widget 描述“应显示什么”，不等同于 Unity GameObject 或可变的 Qt 控件。
class PillxaiApp extends StatefulWidget {
  const PillxaiApp({
    super.key,
    this.model,
    this.initiallySignedIn = false,
    this.demo = false,
  });
  final DemoModel? model;
  final bool demo;
  final bool initiallySignedIn;
  @override
  State<PillxaiApp> createState() => _PillxaiAppState();
}

/// 持有主题和运行模式；真实会话由 ConnectedWorkspace 持有，演示模型按需创建。
/// 下划线使名称在本 Dart library 内私有；State 在多次 build 之间保留。
/// setState 的闭包立即修改局部状态，Flutter 随后安排重建界面配置。
class _PillxaiAppState extends State<PillxaiApp> {
  // late final 首次读取时求值，此后保持同一引用；不会每次 build 都创建模型。
  late final bool _previewMode = widget.demo || widget.model != null;
  late final DemoModel? _preview = _previewMode
      ? widget.model ?? DemoModel()
      : null;
  DemoModel get model => _preview!;
  late final devices = DevicePreviewModel(canConnect: () => !model.busy);
  Color accent = const Color(0xff191919);
  int page = 1; // IndexedStack 的顺序：0处方、1摆药、2设置。
  late bool _signedIn = widget.initiallySignedIn;

  // 谁创建资源，谁释放。外部传入的模型仍归调用者负责，避免重复 dispose。
  @override
  void dispose() {
    if (_previewMode) {
      devices.dispose();
      if (widget.model == null) model.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pillxai',
    debugShowCheckedModeBanner: false,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: createTheme(accent: accent),
    home: _previewMode
        ? LayoutBuilder(builder: _buildHome)
        : ConnectedWorkspace(
            accent: accent,
            onAccentChanged: (value) => setState(() => accent = value),
          ),
  );

  /// 决定显示登录页还是工作区；工作区按“左侧导航、右侧内容”排列。
  /// context 来自 MaterialApp 内部，弹窗、提示和主题都要用这个上下文。
  /// 下面的 _build... 是普通方法：返回界面配置，不创建另一份 State。
  Widget _buildHome(BuildContext context, BoxConstraints bounds) {
    if (!_signedIn) {
      return LoginPage(
        onLogin: (username, password) async {
          if (username != 'admin' || password != 'admin123') {
            throw const SaveFailure('账号或密码不正确，请重新输入。');
          }
          setState(() {
            _signedIn = true;
            page = 1;
          });
        },
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            WorkspaceSidebar(
              selected: page,
              compact: bounds.maxWidth < 600,
              onSignOut: () => _signOut(context),
              onSelect: (value) => setState(() => page = value),
            ),
            Expanded(
              child: Column(
                children: [
                  if (page != 2) _buildHeader(context, bounds.maxWidth),
                  Expanded(child: _buildPages(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶栏显示当前页标题，摆药页额外显示设备入口；设置页有自己的标题。
  /// 只有标题订阅任务模型，计数变化不需要重新构建整个工作区。
  Widget _buildHeader(BuildContext context, double windowWidth) {
    return Container(
      key: const ValueKey('workspace-header'),
      color: Theme.of(context).scaffoldBackgroundColor,
      constraints: const BoxConstraints(minHeight: 88),
      padding: EdgeInsets.symmetric(
        horizontal: windowWidth < 900 ? 20 : 32,
        vertical: 16,
      ),
      child: Row(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: model,
              builder: (context, _) {
                final String title;
                if (page == 0) {
                  title = '处方管理';
                } else {
                  title = model.active ? '正在分药' : '摆药';
                }
                return PageTitle(
                  title,
                  key: ValueKey(
                    'page-title-${page == 0 ? 'prescriptions' : 'dispensing'}',
                  ),
                );
              },
            ),
          ),
          if (page == 1) ...[
            const SizedBox(width: 16),
            DeviceStatusButton(
              devices: devices,
              onPressed: () => _openDevices(context),
            ),
          ],
        ],
      ),
    );
  }

  /// page 对应 children 的下标。IndexedStack 保留三个页面，只显示选中页。
  /// 方法重新执行会生成新配置；同位置、同类型的页面仍保留输入与滚动状态。
  /// 任务由根模型持有，因此切页不会重启计时或清零。
  Widget _buildPages(BuildContext context) {
    return IndexedStack(
      index: page,
      children: [
        PrescriptionsPage(
          model: model,
          onHistory: (resident) => showDialog<void>(
            context: context,
            builder: (context) => Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: SizedBox(
                width: 1000,
                child: HistoryPage(
                  model: model,
                  residentId: resident.id,
                  onClose: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ),
        PreparationPage(model: model),
        SettingsPage(
          model: model,
          accent: accent,
          onAccentChanged: (value) => setState(() => accent = value),
        ),
      ],
    );
  }

  void _openDevices(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => DevicesPage(devices: devices, taskModel: model),
  );

  /// 退出只在无执行/取盒占用时发生；失败给出原因并保持当前会话。
  void _signOut(BuildContext context) {
    if (model.busy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            model.awaitingCollection ? '请先完成取盒，再退出账户。' : '请先完成或结束当前摆药，再退出账户。',
          ),
        ),
      );
      return;
    }
    setState(() => _signedIn = false);
  }
}
