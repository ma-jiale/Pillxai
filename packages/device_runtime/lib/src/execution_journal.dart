import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_execution_core/execution_core.dart';
import 'package:sqlite3/sqlite3.dart';

String newExecutionId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = bytes[6] & 15 | 64;
  bytes[8] = bytes[8] & 63 | 128;
  final hex = bytes.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Full state and pending upload facts commit atomically before any next action.
class ExecutionJournal {
  ExecutionJournal(String path) {
    File(path).parent.createSync(recursive: true);
    db = sqlite3.open(path);
    db.execute('PRAGMA journal_mode=WAL');
    db.execute('PRAGMA synchronous=FULL');
    db.execute('PRAGMA foreign_keys=ON');
    db.execute('PRAGMA busy_timeout=5000');
    db.execute('PRAGMA secure_delete=ON');
    db.execute(
      'CREATE TABLE IF NOT EXISTS terminal_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
    db.execute(
      'CREATE TABLE IF NOT EXISTS local_tasks (id TEXT PRIMARY KEY, task TEXT NOT NULL, state TEXT NOT NULL, active INTEGER NOT NULL)',
    );
    db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS one_local_task ON local_tasks(active) WHERE active=1',
    );
    db.execute(
      'CREATE TABLE IF NOT EXISTS outbox (task_id TEXT NOT NULL REFERENCES local_tasks(id) ON DELETE CASCADE, sequence INTEGER NOT NULL, event TEXT NOT NULL, uploaded INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(task_id, sequence))',
    );
    if (setting('terminal_id') == null) {
      setSetting('terminal_id', newExecutionId());
    }
  }
  late final Database db;
  void observe(String kind, Map<String, dynamic> detail) {
    db.execute(
      'CREATE TABLE IF NOT EXISTS terminal_observations (id INTEGER PRIMARY KEY, at TEXT NOT NULL, kind TEXT NOT NULL, detail TEXT NOT NULL)',
    );
    db.execute(
      'INSERT INTO terminal_observations(at,kind,detail) VALUES(?,?,?)',
      [DateTime.now().toUtc().toIso8601String(), kind, jsonEncode(detail)],
    );
  }

  String get terminalId => setting('terminal_id') as String;
  Object? setting(String key) {
    final rows = db.select('SELECT value FROM terminal_settings WHERE key=?', [
      key,
    ]);
    return rows.isEmpty ? null : jsonDecode(rows.first['value'] as String);
  }

  void setSetting(String key, Object? value) => db.execute(
    'INSERT INTO terminal_settings VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
    [key, jsonEncode(value)],
  );

  Map<String, dynamic>? active() {
    final rows = db.select('SELECT task,state FROM local_tasks WHERE active=1');
    if (rows.isEmpty) return null;
    return {
      'task': jsonDecode(rows.first['task'] as String),
      'state': jsonDecode(rows.first['state'] as String),
    };
  }

  void save(
    api.TaskView task,
    ExecutionState state, {
    String? kind,
    Map<String, dynamic>? detail,
  }) {
    final oldSequence = state.sequence;
    db.execute('BEGIN IMMEDIATE');
    try {
      if (kind != null) state.sequence++;
      // Retain the slot until final facts are acknowledged by the server.
      db.execute(
        'INSERT INTO local_tasks VALUES(?,?,?,1) ON CONFLICT(id) DO UPDATE SET task=excluded.task,state=excluded.state',
        [task.id, jsonEncode(task.toJson()), jsonEncode(state.toJson())],
      );
      if (kind != null) {
        final event = api.ExecutionEvent(
          sequence: state.sequence,
          kind: kind,
          batch: state.batch,
          at: DateTime.now().toUtc(),
          detail: {
            for (final entry in (detail ?? <String, dynamic>{}).entries)
              if (entry.value != null) entry.key: entry.value as Object,
          },
        );
        db.execute('INSERT INTO outbox(task_id,sequence,event) VALUES(?,?,?)', [
          task.id,
          state.sequence,
          jsonEncode(event.toJson()),
        ]);
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      state.sequence = oldSequence;
      rethrow;
    }
  }

  List<Map<String, dynamic>> pending(String id) => db
      .select(
        'SELECT event FROM outbox WHERE task_id=? AND uploaded=0 ORDER BY sequence LIMIT 200',
        [id],
      )
      .map((row) => jsonDecode(row['event'] as String) as Map<String, dynamic>)
      .toList();
  int pendingCount(String id) =>
      db.select(
            'SELECT COUNT(*) AS n FROM outbox WHERE task_id=? AND uploaded=0',
            [id],
          ).first['n']
          as int;
  void acknowledge(String id, int sequence) => db.execute(
    'UPDATE outbox SET uploaded=1 WHERE task_id=? AND sequence<=?',
    [id, sequence],
  );
  void release(String id) {
    if (pendingCount(id) != 0) throw StateError('结果尚未同步，不能释放本机。');
    db.execute('UPDATE local_tasks SET active=0 WHERE id=?', [id]);
  }

  void discard(String id) {
    db.execute('DELETE FROM local_tasks WHERE id=?', [id]);
    db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
  }

  void close() => db.close();
}
