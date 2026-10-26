import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:pillxai_execution_core/execution_core.dart';
import 'package:sqlite3/sqlite3.dart';

/// Engineering-only journal. Not a production task store or synchronization queue.
final class DiagnosticJournal {
  DiagnosticJournal(String path) {
    File(path).parent.createSync(recursive: true);
    _db = sqlite3.open(path);
    _db.execute('PRAGMA journal_mode=WAL');
    _db.execute('PRAGMA synchronous=FULL');
    _db.execute('PRAGMA busy_timeout=5000');
    _db.execute('PRAGMA foreign_keys=ON');
    _db.execute('''CREATE TABLE IF NOT EXISTS probe_sessions (
      session_id TEXT PRIMARY KEY, mode TEXT NOT NULL, device TEXT NOT NULL,
      started_at TEXT NOT NULL, ended_at TEXT, outcome TEXT NOT NULL
    )''');
    _db.execute('''CREATE TABLE IF NOT EXISTS probe_events (
      sequence INTEGER PRIMARY KEY AUTOINCREMENT,
      session_id TEXT NOT NULL REFERENCES probe_sessions(session_id),
      observed_at TEXT NOT NULL, kind TEXT NOT NULL, payload TEXT NOT NULL
    )''');
  }

  late final Database _db;

  String beginSession({required String mode, required String device}) {
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _db.execute('INSERT INTO probe_sessions VALUES (?, ?, ?, ?, NULL, ?)', [
      id,
      mode,
      device,
      _now(),
      'open',
    ]);
    return id;
  }

  void record(String session, String kind, Map<String, Object?> payload) {
    _db.execute(
      'INSERT INTO probe_events(session_id,observed_at,kind,payload) VALUES(?,?,?,?)',
      [session, _now(), kind, jsonEncode(payload)],
    );
  }

  /// Raw bytes and their decoded events commit together.
  void recordIncoming(
    String session,
    List<int> bytes,
    List<DeviceEvent> events,
  ) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      record(session, 'rx', {'bytes': bytes});
      for (final event in events) {
        record(session, 'feedback', event.toJson());
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void endSession(String session, String outcome) {
    _db.execute(
      'UPDATE probe_sessions SET ended_at=?, outcome=? WHERE session_id=?',
      [_now(), outcome, session],
    );
  }

  List<Map<String, Object?>> readEvents(String session) => _db
      .select(
        'SELECT sequence,observed_at,kind,payload FROM probe_events WHERE session_id=? ORDER BY sequence',
        [session],
      )
      .map(
        (row) => <String, Object?>{
          'sequence': row['sequence'],
          'observed_at': row['observed_at'],
          'kind': row['kind'],
          'payload': jsonDecode(row['payload'] as String),
        },
      )
      .toList();

  List<Map<String, Object?>> sessions() => _db
      .select('SELECT * FROM probe_sessions ORDER BY started_at')
      .map((row) => Map<String, Object?>.from(row))
      .toList();

  void close() => _db.close();
  static String _now() => DateTime.now().toUtc().toIso8601String();
}
