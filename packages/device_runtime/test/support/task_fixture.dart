import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_device_runtime/device_runtime.dart';

api.TaskView fixture(String terminal, {int batches = 2}) {
  final id = newExecutionId();
  final device = api.DeviceView(
    id: newExecutionId(),
    revision: 1,
    configuration: api.DeviceConfiguration(
      name: '模拟机',
      identity: id,
      terminalId: terminal,
      mode: api.DeviceMode.simulator,
      rows: [2, 1, 0, 3],
      positionsVerified: true,
      feedbackVerified: true,
      trayPresentLine: 'SIM:TRAY_PRESENT',
      trayAbsentLine: 'SIM:TRAY_ABSENT',
      readyLine: 'SIM:READY',
    ),
  );
  final plan = api.PlanSnapshot(
    id: newExecutionId(),
    residentId: id,
    residentRevision: 1,
    residentName: '虚构长者',
    bed: '',
    businessDate: DateTime.now(),
    createdAt: DateTime.now().toUtc(),
    settings: api.AppSettings(
      timezone: 'Asia/Shanghai',
      bedtimeEnabled: false,
      preparationDays: 1,
      splitMeals: true,
      startTomorrow: false,
      revision: 1,
    ),
    requestedDays: 1,
    splitMeals: true,
    dates: [DateTime.now()],
    slots: ['早', '午', '晚'],
  );
  return api.TaskView(
    id: newExecutionId(),
    planId: plan.id,
    deviceId: device.id,
    terminalId: terminal,
    ownerId: newExecutionId(),
    revision: 1,
    state: api.TaskState.claimed,
    plan: plan,
    device: device,
    labels: ['A1B2C3D4'],
    sequence: 0,
    counts: List.filled(batches, 0),
    startedAt: null,
    updatedAt: DateTime.now().toUtc(),
    batches: [
      for (var i = 0; i < batches; i++)
        api.BatchPlan(
          index: i,
          tray: i,
          prescriptionId: id,
          medicineId: id,
          name: '虚构药物$i',
          strength: '10mg',
          feedForm: 'half',
          purpose: '第${i + 1}盘',
          total: 2,
          matrix: [
            [1, 1, 0, 0, 0, 0, 0],
            List.filled(7, 0),
            List.filled(7, 0),
            List.filled(7, 0),
          ],
          parameters: api.ParameterView(
            prescriptionId: id,
            medicineId: id,
            revision: 1,
            turntable: 1,
            gate: .5,
          ),
        ),
    ],
  );
}
