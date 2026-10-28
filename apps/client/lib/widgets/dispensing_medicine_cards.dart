import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'medicine_card_deck.dart';
import 'profile_avatar.dart';

class DispensingIdentity extends StatelessWidget {
  const DispensingIdentity({
    super.key,
    required this.name,
    required this.bed,
    required this.stage,
    this.avatar,
  });
  final String name;
  final String bed;
  final String stage;
  final String? avatar;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: ResidentIdentity(name: name, bed: bed, asset: avatar),
        ),
        if (bounds.maxWidth >= 700) ...[
          const SizedBox(width: 24),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: readableAccent(Theme.of(context).colorScheme.primary),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            stage,
            style: const TextStyle(fontSize: 12, color: Color(0xff666666)),
          ),
        ],
      ],
    ),
  );
}

class DispensingPrimaryButton extends StatelessWidget {
  const DispensingPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: FilledButton(
      key: const ValueKey('dispense-primary'),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Flexible(child: Text(label)),
        ],
      ),
    ),
  );
}

/// Display values only. Task transitions remain in the execution controller.
class DispensingMedicine {
  const DispensingMedicine({
    required this.id,
    required this.name,
    required this.form,
    required this.strength,
    required this.target,
    this.image,
  });
  final String id;
  final String name;
  final String form;
  final String strength;
  final int target;
  final ImageProvider? image;
}

/// Extracted from the approved Flutter screen without changing its geometry.
class DispensingMedicineCards extends StatelessWidget {
  const DispensingMedicineCards({
    super.key,
    required this.current,
    this.next,
    required this.count,
    required this.stageLabel,
    this.progressLabel = '已摆',
  });
  final DispensingMedicine current;
  final DispensingMedicine? next;
  final int count;
  final String stageLabel;
  final String progressLabel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, area) {
      final stacked = area.maxWidth < 800;
      return MedicineCardDeck(
        medicineId: current.id,
        nextMedicineId: next?.id,
        current: _currentMedicine(context),
        next: next == null
            ? null
            : _nextMedicine(context, next!, horizontal: stacked),
        stacked: stacked,
      );
    },
  );

  Widget _currentMedicine(BuildContext context) {
    final medicine = current;
    final text = _medicineInformation(context, medicine);
    final photo = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: MedicineImage(name: medicine.name, image: medicine.image),
        ),
      ),
    );
    final child = LayoutBuilder(
      builder: (context, bounds) {
        final vertical = bounds.maxWidth < 510;
        if (vertical) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 230, child: photo),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                child: text,
              ),
            ],
          );
        }
        return SizedBox(
          height: 410,
          child: Row(
            children: [
              Expanded(flex: 52, child: SizedBox.expand(child: photo)),
              const SizedBox(width: 28),
              Expanded(flex: 48, child: text),
            ],
          ),
        );
      },
    );
    return child;
  }

  Widget _medicineInformation(
    BuildContext context,
    DispensingMedicine medicine,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _medicineIdentity(context, medicine),
        const SizedBox(height: 54),
        _progressDetails(context, medicine),
      ],
    );
  }

  Widget _medicineIdentity(BuildContext context, DispensingMedicine medicine) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '当前药物',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontSize: 11, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          Text(
            medicine.name,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${medicine.form} · ${medicine.strength}',
            style: const TextStyle(fontSize: 14, color: Color(0xff777777)),
          ),
        ],
      );

  Widget _progressDetails(BuildContext context, DispensingMedicine medicine) {
    final progress = medicine.target == 0
        ? 0.0
        : (count / medicine.target).clamp(0.0, 1.0);
    final accent = readableAccent(Theme.of(context).colorScheme.primary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(progressLabel, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Semantics(
          label: '已摆 $count / ${medicine.target} 颗',
          excludeSemantics: true,
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 7,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
              Text(
                '/ ${medicine.target}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w400,
                  color: Color(0xff9a9a9a),
                ),
              ),
              const Text(
                '颗',
                style: TextStyle(fontSize: 12, color: Color(0xff888888)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        TweenAnimationBuilder<double>(
          tween: Tween(end: progress),
          duration: const Duration(milliseconds: 400),
          builder: (context, value, _) => LinearProgressIndicator(
            value: value,
            minHeight: 6,
            color: accent,
            backgroundColor: const Color(0xffe7e7e7),
            borderRadius: BorderRadius.circular(100),
            semanticsLabel: '摆药进度，已摆 $count 颗，共 ${medicine.target} 颗',
            semanticsValue: '${(value * 100).round()}',
          ),
        ),
        const SizedBox(height: 14),
        Text(stageLabel, style: TextStyle(fontSize: 12, color: accent)),
      ],
    );
  }

  Widget _nextMedicine(
    BuildContext context,
    DispensingMedicine medicine, {
    bool horizontal = false,
  }) {
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('下一药', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        Text(
          medicine.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 5),
        Text(
          '${medicine.form} · ${medicine.strength}',
          style: const TextStyle(fontSize: 12, color: Color(0xff777777)),
        ),
      ],
    );
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: MedicineImage(name: medicine.name, image: medicine.image),
        ),
      ),
    );
    final content = horizontal
        ? Row(
            children: [
              Expanded(child: details),
              SizedBox(width: 90, height: 90, child: image),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              details,
              const SizedBox(height: 30),
              SizedBox(height: 210, child: image),
            ],
          );
    return content;
  }
}

/// 药品图片只负责显示原图或缺图占位，不使用强调色给照片着色。
class MedicineImage extends StatelessWidget {
  const MedicineImage({super.key, required this.name, this.image});
  final String name;
  final ImageProvider? image;
  @override
  Widget build(BuildContext context) {
    final source = image;
    if (source == null) {
      return Container(
        color: const Color(0xfff6f6f6),
        alignment: Alignment.center,
        child: LayoutBuilder(
          builder: (context, bounds) {
            const icon = Icon(
              Icons.medication_outlined,
              size: 44,
              color: Color(0xffa0a0a0),
            );
            if (bounds.maxHeight < 120 || bounds.maxWidth < 120) return icon;
            return const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                SizedBox(height: 12),
                Text(
                  '尚未添加药品图片',
                  style: TextStyle(fontSize: 12, color: Color(0xff777777)),
                ),
              ],
            );
          },
        ),
      );
    }
    return Image(
      image: source,
      fit: BoxFit.contain,
      semanticLabel: '$name 药品图片',
    );
  }
}
