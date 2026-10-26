import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_page.dart';
import 'profile_avatar.dart';
import 'app_menu.dart';

/// 侧栏只把选择事件传给父组件，不直接拥有或修改任务。
/// 与 PyQt 信号/槽相似：onSelect 是回调；实际状态更新发生在调用者。
class WorkspaceSidebar extends StatelessWidget {
  const WorkspaceSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.compact,
    required this.onSignOut,
    this.displayName = '管理员',
    this.roleLabel = '管理员',
  });
  final int selected;
  final ValueChanged<int> onSelect;
  final bool compact;
  final VoidCallback onSignOut;
  final String displayName;
  final String roleLabel;

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
      tooltip: '$displayName · 账户菜单',
      header: Row(
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
                displayName,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 3),
              Text(
                roleLabel,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      roleLabel,
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
