import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'models/demo_model.dart';
import 'models/device_preview_model.dart';
import 'screens/devices_page.dart';
import 'screens/preparation_page.dart';
import 'screens/login_page.dart';
import 'screens/prescriptions_page.dart';
import 'screens/settings_page.dart';
import 'theme/app_theme.dart';
import 'theme/app_page.dart';
import 'widgets/profile_avatar.dart';
import 'widgets/app_menu.dart';

/// 程序入口。=> 是单表达式函数的简写，等价于 { runApp(...); }。
/// const 创建不可变配置；运行中的可变数据由下面的 State 保存。
void main() => runApp(const PillxaiApp());

/// 应用的根配置。model 可由测试注入；日常启动时由 State 创建并持有。
/// Widget 描述“应显示什么”，不等同于 Unity GameObject 或可变的 Qt 控件。
class PillxaiApp extends StatefulWidget {
  const PillxaiApp({super.key, this.model, this.initiallySignedIn = false});
  final DemoModel? model;
  final bool initiallySignedIn;
  @override
  State<PillxaiApp> createState() => _PillxaiAppState();
}

/// 应用会话的拥有者：登录状态、当前页面、强调色及共享模型。
/// 下划线使名称在本 Dart library 内私有；State 在多次 build 之间保留。
/// setState 的闭包立即修改局部状态，Flutter 随后安排重建界面配置。
class _PillxaiAppState extends State<PillxaiApp> {
  // late final 首次读取时求值，此后保持同一引用；不会每次 build 都创建模型。
  late final DemoModel model = widget.model ?? DemoModel();
  late final devices = DevicePreviewModel(canConnect: () => !model.busy);
  Color accent = const Color(0xff191919);
  int page = 1; // IndexedStack 的顺序：0处方、1摆药、2设置。
  late bool _signedIn = widget.initiallySignedIn;

  // 谁创建资源，谁释放。外部传入的模型仍归调用者负责，避免重复 dispose。
  @override
  void dispose() {
    devices.dispose();
    if (widget.model == null) model.dispose();
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
    home: LayoutBuilder(builder: _buildHome),
  );

  /// 决定显示登录页还是工作区；工作区按“左侧导航、右侧内容”排列。
  /// context 来自 MaterialApp 内部，弹窗、提示和主题都要用这个上下文。
  /// 下面的 _build... 是普通方法：返回界面配置，不创建另一份 State。
  Widget _buildHome(BuildContext context, BoxConstraints bounds) {
    if (!_signedIn) {
      return LoginPage(
        onDemoLogin: () => setState(() {
          _signedIn = true;
          page = 1;
        }),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _Sidebar(
              selected: page,
              compact: bounds.maxWidth < 600,
              onSignOut: () => _signOut(context),
              onSelect: (value) => setState(() => page = value),
            ),
            Expanded(
              child: Column(
                children: [
                  if (page != 2) _buildHeader(context, bounds.maxWidth),
                  Expanded(child: _buildPages()),
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
  Widget _buildPages() {
    return IndexedStack(
      index: page,
      children: [
        PrescriptionsPage(model: model),
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

/// 侧栏只把选择事件传给父组件，不直接拥有或修改任务。
/// 与 PyQt 信号/槽相似：onSelect 是回调；实际状态更新发生在调用者。
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.onSelect,
    required this.compact,
    required this.onSignOut,
  });
  final int selected;
  final ValueChanged<int> onSelect;
  final bool compact;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Container(
    width: compact ? 76 : 232,
    decoration: BoxDecoration(
      color: selected == 2 ? AppPage.navigationBackground : Colors.white,
      border: const Border(right: BorderSide(color: Color(0xffe5e5e5))),
    ),
    // 正常高度保留底部账户区；短屏/软键盘/大字体时允许整条侧栏滚动。
    // 子项很少，IntrinsicHeight 用于让 Spacer 在最小视口高度内分配余量。
    child: LayoutBuilder(
      builder: (context, bounds) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: bounds.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: compact ? 24 : 32,
                    horizontal: compact ? 10 : 32,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      'Pillxai',
                      textAlign: compact ? TextAlign.center : TextAlign.left,
                      style: TextStyle(
                        fontSize: compact ? 14 : 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                _item(1, Icons.medication_outlined, '摆药'),
                const SizedBox(height: 12),
                _item(0, Icons.article_outlined, '处方管理'),
                const Spacer(),
                _item(2, Icons.settings_outlined, '设置'),
                _accountMenu(),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _accountMenu() => Padding(
    padding: EdgeInsets.fromLTRB(compact ? 8 : 16, 12, compact ? 8 : 16, 20),
    child: AppActionMenu(
      key: const ValueKey('account-menu'),
      tooltip: '管理员 · 账户菜单',
      header: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProfileAvatar(
            asset: 'assets/images/avatars/account.png',
            label: '当前账户头像',
            size: 32,
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '管理员',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 3),
              Text(
                '院内管理员',
                style: TextStyle(fontSize: 11, color: Color(0xff858585)),
              ),
            ],
          ),
        ],
      ),
      actions: [AppMenuAction('退出当前用户', onSignOut, icon: Icons.logout_rounded)],
      child: Padding(
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: compact
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            const ProfileAvatar(
              asset: 'assets/images/avatars/account.png',
              label: '管理员头像',
            ),
            if (!compact) ...[
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '管理员',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '院内管理员',
                      style: TextStyle(fontSize: 11, color: Color(0xff858585)),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.unfold_more_rounded,
                size: 17,
                color: Color(0xff858585),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _item(int index, IconData icon, String label) {
    final active = selected == index;
    final color = active ? const Color(0xff242424) : const Color(0xff777777);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 12),
      child: Semantics(
        selected: active,
        child: Material(
          color: active ? const Color(0xffefeff1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: ValueKey('nav-$index'),
            borderRadius: BorderRadius.circular(16),
            overlayColor: const WidgetStatePropertyAll(Color(0x08000000)),
            onTap: () => onSelect(index),
            child: Container(
              constraints: BoxConstraints(minHeight: compact ? 72 : 56),
              width: double.infinity,
              padding: compact
                  ? const EdgeInsets.symmetric(vertical: 8)
                  : const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Flex(
                mainAxisSize: MainAxisSize.min,
                direction: compact ? Axis.vertical : Axis.horizontal,
                mainAxisAlignment: compact
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  if (index == 1)
                    SvgPicture.asset(
                      'assets/icons/capsule.svg',
                      width: 22,
                      height: 22,
                      excludeFromSemantics: true,
                    )
                  else
                    Icon(icon, size: 22, color: color),
                  SizedBox(height: compact ? 9 : 0, width: compact ? 0 : 14),
                  if (compact)
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: compact ? 11 : 14,
                        color: color,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    )
                  else
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          color: color,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
