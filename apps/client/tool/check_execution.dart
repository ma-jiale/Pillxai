// Real Dart SDK + FastAPI + PostgreSQL + SQLite + byte-protocol simulator.
// Never opens a serial port. Creates labelled fictional fixtures only.
import 'dart:convert';
import 'dart:io';

import 'package:pillxai_api_client/api.dart';
import 'package:pillxai_device_runtime/device_runtime.dart';
import 'package:pillxai_execution_core/execution_core.dart';

import 'check_business.dart' show check, newId;

Future<void> until(ExecutionEngine engine, bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await engine.tick();
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  check(condition(), 'Unexpected local phase: ${engine.state.toJson()}');
}

Future<void> main() async {
  final credentialsFile = jsonDecode(
    await File('../../.var/local-login.json').readAsString(),
  ) as Map;
  final credentials = (credentialsFile['accounts'] as List)
      .cast<Map>()
      .firstWhere((r) => r['username'] == 'local-admin');
  final client = ApiClient(basePath: 'http://127.0.0.1:8000');
  final run = newId();
  final journal = ExecutionJournal(
    '../../.var/execution-check/$run/execution.sqlite',
  );
  final engine = ExecutionEngine(
    journal,
    removalWindow: const Duration(milliseconds: 50),
  );
  final machine = MachineSimulator(
    interval: const Duration(milliseconds: 150),
    uid: run.replaceAll('-', '').toUpperCase(),
  );
  try {
    final login = (await IdentityApi(client).login(
      Login(
        username: credentials['username'],
        password: credentials['password'],
      ),
    ))!;
    client.addDefaultHeader('Authorization', 'Bearer ${login.accessToken}');
    final execution = ExecutionApi(client);
    await ResidentsApi(client).saveResident(
      run,
      SaveResident(
        expectedRevision: 0,
        data: ResidentData(name: '上机流程模拟长者', bed: '模拟-${run.substring(0, 8)}'),
      ),
    );
    for (final before in [true, false]) {
      final prescriptionId = newId();
      final prescription = (await PrescriptionsApi(client).savePrescription(
        run,
        prescriptionId,
        SavePrescription(
          expectedRevision: 0,
          data: PrescriptionData(
            medicineName: before ? '模拟半片药物' : '模拟整片药物',
            strength: '10 mg',
            unit: DoseUnit.tablet,
            feedForm: before ? FeedForm.half : FeedForm.whole,
            doses: DoseAmounts(
              morning: before ? '0.5' : '1',
              noon: '0',
              evening: before ? '0.5' : '1',
              night: '0',
            ),
            mealRelation: before ? MealRelation.before : MealRelation.after,
            startDate: DateTime(2026, 10, 26),
            endDate: null,
          ),
        ),
      ))!;
      await execution.saveParameters(
        run,
        prescriptionId,
        MedicationParameters(
          expectedRevision: 0,
          medicineId: prescription.medicineId,
          turntable: 1,
          gate: .5,
          simulationOnly: true,
        ),
      );
    }
    await execution.bindLabel(run, BindLabel(uid: machine.uid!));
    final device = (await execution.saveDevice(
      newId(),
      SaveDevice(
        expectedRevision: 0,
        configuration: DeviceConfiguration(
          name: '字节协议模拟机',
          identity: run,
          terminalId: journal.terminalId,
          mode: DeviceMode.simulator,
          rows: [2, 1, 0, 3],
          positionsVerified: true,
          feedbackVerified: true,
          trayPresentLine: 'SIM:TRAY_PRESENT',
          trayAbsentLine: 'SIM:TRAY_ABSENT',
          readyLine: 'SIM:READY',
        ),
      ),
    ))!;
    final preview = (await PlanningApi(client)
        .createPlanPreview(run, PreviewRequest(days: 2, splitMeals: true)))!;
    final claimed = (await execution.claimTask(
      newId(),
      ClaimTask(
        planId: preview.snapshot.id,
        deviceId: device.id,
        terminalId: journal.terminalId,
      ),
    ))!;
    check(claimed.batches.length == 2, 'Expected two trays');
    await engine.connect(machine);
    check(machine.writes.isEmpty, 'Connect sent an unsolicited command');
    await engine.attach(claimed);
    await until(engine, () => engine.state.phase == ExecutionPhase.ready);
    Future<TaskView> flush() async {
      TaskView? saved;
      while (journal.pendingCount(claimed.id) > 0) {
        saved = (await execution.syncEvents(
          claimed.id,
          SyncEvents(
            terminalId: journal.terminalId,
            events: journal
                .pending(claimed.id)
                .map((e) => ExecutionEvent.fromJson(e)!)
                .toList(),
          ),
        ))!;
        engine.acknowledge(saved.sequence);
      }
      return saved ?? (await execution.getTask(claimed.id))!;
    }

    final fresh = await flush();
    final permitted = (await execution.startTask(
      claimed.id,
      StartTask(
        terminalId: journal.terminalId,
        expectedRevision: fresh.revision,
        uid: engine.state.uid!,
        observedAt: engine.state.uidAt!,
      ),
    ))!;
    await engine.begin(permitted);
    await until(engine, () => engine.state.phase == ExecutionPhase.running);
    await engine.pause();
    await until(engine, () => engine.state.phase == ExecutionPhase.paused);
    await engine.resume();
    // Intentionally no HTTP from here through the second tray and collection.
    await until(
      engine,
      () =>
          engine.state.batch == 1 && engine.state.phase == ExecutionPhase.ready,
    );
    await engine.continueTray();
    await until(engine, () => engine.state.phase == ExecutionPhase.collecting);
    machine.emit('NO CARD');
    await engine.tick();
    check(
      engine.state.phase == ExecutionPhase.collecting,
      'NO CARD released occupancy',
    );
    machine.removeTray();
    await until(engine, () => engine.state.phase == ExecutionPhase.completed);
    final countBefore = journal.pendingCount(claimed.id);
    machine.emit('UID:FFFF');
    await engine.tick();
    check(
      journal.pendingCount(claimed.id) == countBefore,
      'Post-completion events leaked into closed task',
    );
    final completed = await flush();
    check(
      completed.state == TaskState.completed &&
          completed.completedBatches.length == 2 &&
          engine.task == null,
      'Completion did not release both owners',
    );
    check(
      machine.writes.where((b) => b[2] == 5).length == 2,
      'Matrix replayed',
    );
    final next = (await PlanningApi(client)
        .createPlanPreview(run, PreviewRequest(days: 2, splitMeals: true)))!;
    check(
      next.snapshot.dates.first == preview.snapshot.dates.first,
      'Simulation advanced real coverage',
    );
    final report = {
      'result': 'passed',
      'run_id': run,
      'task_id': claimed.id,
      'state': completed.state.toJson(),
      'batches': completed.completedBatches,
      'counts': completed.counts,
      'sequence': completed.sequence,
      'checks': [
        'real_sdk_http_postgres',
        'sqlite_journal',
        'protocol_bytes',
        'two_trays',
        'pause_resume_no_replay',
        'offline_after_permit',
        'no_card_not_tray_absence',
        'collection_ready',
        'idempotent_upload',
        'simulation_no_coverage',
      ],
    };
    await File('../../.var/execution-check/latest.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    stdout.writeln(jsonEncode(report));
  } finally {
    await engine.disconnect();
    journal.close();
    client.client.close();
  }
}
