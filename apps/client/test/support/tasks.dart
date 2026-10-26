import 'package:pillxai_client/models/demo_model.dart';
import 'package:pillxai_client/models/preparation_plan.dart';

/// 测试数据入口：模拟收到药盒匹配，然后调用应用唯一的启动方法。
/// counts 指定短任务每种药的颗数，便于用少量 advance() 验证转换。
/// 有 counts 时构造“首日早服指定数量、当天结束”的处方，再照常生成计划；
/// 不直接改 taskMedicines、stage 或 target，也不绕过计划与启动校验。
bool startTestTask(
  DemoModel model, {
  Resident? resident,
  List<int>? counts,
  DateTime? start,
  int days = 7,
}) {
  final source = resident ?? model.residents.first;
  final date = start ?? model.planFor(source).start;
  final input = counts == null
      ? source
      : Resident(
          id: source.id,
          name: source.name,
          bed: source.bed,
          avatarAsset: source.avatarAsset,
          medicines: [
            for (var i = 0; i < counts.length; i++)
              source.medicines[i].copyWith(
                doses: DoseSchedule(
                  morning: counts[i].toDouble(),
                  noon: 0,
                  evening: 0,
                ),
                form: '整片',
                startDate: date,
                endDate: date,
              ),
          ],
        );
  final plan = PreparationPlan(input, date, days, bedtime: model.bedtime);
  model.boxFeedback.value = BoxFeedback.match;
  return model.startPreparedTask(plan);
}
