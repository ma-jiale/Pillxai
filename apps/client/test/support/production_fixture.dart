import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pillxai_client/data/backend_connection.dart';

import '../connected_prescriptions_test.dart'
    show connection, jsonResponse, profile, residentId, actorId;
import '../server_planning_test.dart'
    show previewJson, prescription, settingsJson;
import '../terminal_ui_test.dart' show FakeHost, snapshot;

Map<String, dynamic> clone(Map value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

/// A transport fixture behind the real login, controllers and workspace.
/// It never loads DemoModel, contacts a server or sends hardware commands.
class ProductionFixture {
  ProductionFixture() {
    plan = clone(previewJson()['snapshot'] as Map);
    plan['business_date'] = '2026-10-27';
    plan['dates'] = [
      for (var day = 0; day < 7; day++)
        DateTime(2026, 10, 27 + day).toIso8601String().substring(0, 10),
    ];
    medicines = [
      for (var i = 0; i < 7; i++)
        {
          ...clone(prescription),
          'id': 'prescription-$i',
          'medicine_id': 'medicine-$i',
          'data': {
            ...clone(prescription['data'] as Map),
            'medicine_name': '测试药 ${String.fromCharCode(65 + i)}',
            'meal_relation': i < 4 ? 'before' : 'after',
            'doses': {
              'morning': '0.5',
              'noon': '0.5',
              'evening': '0',
              'night': '0',
            },
          },
        },
    ];
    plan['sources'] = medicines;
    plan['trays'] = [
      for (var tray = 0; tray < 2; tray++)
        {
          'purpose': tray == 0 ? '餐前盘' : '餐后盘',
          'medicines': [
            for (var i = tray == 0 ? 0 : 4; i < (tray == 0 ? 4 : 7); i++)
              {
                'prescription': medicines[i],
                'particles': [
                  for (var day = 0; day < 7; day++) [1, 1, 0, 0],
                ],
                'total_particles': 14,
                'original_units': '7',
              },
          ],
        },
    ];
    task = clone(snapshot()['task'] as Map)
      ..['plan'] = plan
      ..['plan_id'] = plan['id']
      ..['owner_id'] = actorId
      ..['state'] = 'claimed'
      ..['batches'] = [
        for (var i = 0; i < 7; i++)
          {
            ...clone((snapshot()['task'] as Map)['batches'][0] as Map),
            'index': i,
            'tray': i < 4 ? 0 : 1,
            'prescription_id': 'prescription-$i',
            'medicine_id': 'medicine-$i',
            'name': '测试药 ${String.fromCharCode(65 + i)}',
            'matrix': [
              [1, 1, 1, 1, 1, 1, 1],
              [1, 1, 1, 1, 1, 1, 1],
              [0, 0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0, 0],
            ],
            'purpose': i < 4 ? '餐前盘' : '餐后盘',
          },
      ];
    (task['device']['configuration'] as Map).addAll(<String, dynamic>{
      'mode': 'hardware',
      'name': '01 号机',
    });
    host = ProductionHost();
    backend = connection(respond);
  }
  late final Map<String, dynamic> plan;
  late final List<Map<String, dynamic>> medicines;
  late final Map<String, dynamic> task;
  late final ProductionHost host;
  late final BackendConnection backend;
  bool failQueue = false;
  bool stale = false;
  int previewWrites = 0;

  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path == '/auth/login') {
      return jsonResponse({
        'access_token': 'fixture-only',
        'expires_at': '2026-10-28T00:00:00Z',
        'account': {
          'id': actorId,
          'username': 'admin',
          'display_name': '管理员',
          'role': 'admin',
          'can_maintain': true,
          'active': true,
          'revision': 1,
        },
      });
    }
    if (path == '/settings') return jsonResponse(settingsJson);
    if (path == '/residents') {
      return jsonResponse({
        'items': [profile],
        'next_after': null,
      });
    }
    if (path.endsWith('/prescriptions')) return jsonResponse(medicines);
    if (path == '/devices') return jsonResponse([task['device']]);
    if (path == '/preparation') {
      return failQueue
          ? jsonResponse({'code': 'offline', 'message': '清单读取失败'}, 503)
          : jsonResponse([
              {
                'resident_id': residentId,
                'name': '服务端长者',
                'bed': 'A-1',
                'early': false,
                'medicine_count': 7,
                'dates': plan['dates'],
              },
              {
                'resident_id': 'other',
                'name': '测试长者',
                'bed': 'A-2',
                'early': true,
                'medicine_count': 1,
                'dates': ['2026-11-03'],
              },
            ]);
    }
    if (path.endsWith('/plans/preview') || path.startsWith('/plans/')) {
      if (request.method == 'POST') previewWrites++;
      return jsonResponse({
        'current': !stale,
        'message': stale ? '资料已变化，请重新生成。' : '',
        'snapshot': plan,
      });
    }
    if (path.startsWith('/tasks/') &&
        request.method == 'PUT' &&
        !path.endsWith('/start')) {
      task['id'] = path.split('/').last;
      return jsonResponse(task);
    }
    if (path.endsWith('/start')) {
      task['state'] = 'started';
      return jsonResponse(task);
    }
    if (path.endsWith('/events')) return jsonResponse([]);
    if (path.startsWith('/tasks/')) return jsonResponse(task);
    if (path == '/tasks') {
      return jsonResponse([
        {
          ...clone(task),
          'id': 'history-task',
          'state': 'completed',
          'completed_batches': [0, 1, 2, 3, 4, 5, 6],
          'counts': [14, 14, 14, 14, 14, 14, 14],
        },
      ]);
    }
    return jsonResponse([]);
  }

  void dispose() {
    backend.dispose();
    host.close();
  }
}

class ProductionHost extends FakeHost {
  ProductionHost()
    : super({
        'terminal_id': 'terminal',
        'task': null,
        'pending_count': 0,
        'recognized': false,
        'configuration': {'device_id': 'device', 'port': 'COM7'},
        'state': <String, dynamic>{
          'phase': 'idle',
          'connected': true,
          'batch': 0,
          'count': 0,
          'permitted': false,
        },
      });

  void feedback(String phase, {int? batch, int? count, bool? recognized}) {
    final state = value['state'] as Map;
    state['phase'] = phase;
    state['message'] = switch (phase) {
      'recognizing' => '请放入当前长者的药盒',
      'ready' => '药盒匹配，请确认开始',
      'running' => '摆药进行中',
      'paused' => '已暂停',
      'collecting' => '请取出药盒，等待设备反馈',
      'closing' => '药盒已离轨，等待轨道就绪',
      'recovery' => '设备连接中断，请检查现场后重连',
      _ => '',
    };
    if (batch != null) state['batch'] = batch;
    if (count != null) state['count'] = count;
    if (recognized != null) value['recognized'] = recognized;
    if (recognized == true) {
      state['uid'] = 'AABB';
      state['uid_at'] = '2026-10-27T08:00:00Z';
    }
    events.add(value);
  }

  @override
  Future<dynamic> command(
    String operation, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (operation == 'pause' || operation == 'resume') {
      operations.add(operation);
      feedback(operation == 'pause' ? 'paused' : 'running');
      return null;
    }
    if ([
      'claim_intent',
      'attach',
      'begin',
      'continue_tray',
      'stop',
    ].contains(operation)) {
      operations.add(operation);
      if (operation == 'claim_intent') {
        value['claim_intent'] = data;
        events.add(value);
      }
      if (operation == 'attach') {
        value['task'] = data;
        value.remove('claim_intent');
        feedback('recognizing');
      }
      if (operation == 'begin' || operation == 'continue_tray') {
        (value['state'] as Map).addAll(<String, dynamic>{
          'permitted': true,
          'matrix_issued': true,
        });
        feedback('running');
      }
      if (operation == 'stop') feedback('awaitingSafeConfirmation');
      return null;
    }
    return super.command(operation, data);
  }
}
