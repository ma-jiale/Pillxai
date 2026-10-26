import 'package:flutter/material.dart';

/// Profile photos keep their own colors and are always cropped to a circle.
/// 展示头像及语义名称；缺少图片时保留统一占位，不改变身份文本。
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.label,
    this.asset,
    this.size = 36,
  });
  final String label;
  final String? asset;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    image: true,
    child: ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: asset == null
            ? const ColoredBox(
                color: Color(0xfff0efed),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xff777777),
                ),
              )
            : Image.asset(
                asset!,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, error, stack) => const ColoredBox(
                  color: Color(0xfff0efed),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: Color(0xff777777),
                  ),
                ),
              ),
      ),
    ),
  );
}

/// Shared identity presentation for lists, confirmation and the execution header.
/// 把头像、姓名、床位组合成同一个身份展示，列表/详情/弹窗共用。
class ResidentIdentity extends StatelessWidget {
  const ResidentIdentity({
    super.key,
    required this.name,
    required this.bed,
    this.asset,
    this.size = 38,
    this.nameSize = 15,
  });
  final String name;
  final String bed;
  final String? asset;
  final double size;
  final double nameSize;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      ProfileAvatar(label: '$name头像', asset: asset, size: size),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TextStyle(fontSize: nameSize, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(
              bed.isEmpty ? '床位未填写' : bed,
              style: const TextStyle(fontSize: 12, color: Color(0xff858585)),
            ),
          ],
        ),
      ),
    ],
  );
}
