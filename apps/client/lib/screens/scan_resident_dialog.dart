import 'package:flutter/material.dart';

import '../data/prescription_repository.dart';
import '../data/settings_controller.dart';
import '../data/terminal_controller.dart';
import '../models/prescription_controller.dart';
import '../models/prescription_store.dart';
import 'plan_preview_page.dart';

/// Opens once, then resolves only the barcode currently observed by the host.
class ScanResidentDialog extends StatefulWidget {
  const ScanResidentDialog({
    super.key,
    required this.terminal,
    required this.residents,
    required this.settings,
  });
  final TerminalController terminal;
  final PrescriptionController residents;
  final SettingsController settings;
  @override
  State<ScanResidentDialog> createState() => _ScanResidentDialogState();
}

class _ScanResidentDialogState extends State<ScanResidentDialog> {
  Resident? resident;
  String? barcode;
  String? error;
  bool loading = false;
  bool closing = false;
  bool removing = false;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    widget.terminal.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!widget.terminal.identifying) {
        await widget.terminal.action('open_identification');
      }
      _changed();
    });
  }

  @override
  void dispose() {
    widget.terminal.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    final terminal = widget.terminal;
    if (closing && !terminal.identifying && !removing) {
      removing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final route = ModalRoute.of(context);
        if (route != null) Navigator.of(context).removeRoute(route);
      });
    }
    // Keep the confirmed plan mounted while its claim/start request is in flight.
    if (!terminal.active) {
      final code = terminal.connected && terminal.phase == 'recognizing'
          ? terminal.state['barcode'] as String?
          : null;
      if (code != barcode) {
        generation++;
        barcode = code;
        resident = null;
        error = null;
        loading = false;
        if (code != null) _resolve(code);
      }
    }
    setState(() {});
  }

  Future<void> _resolve(String code) async {
    final request = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final page = await widget.terminal.backend.request(
        widget.terminal.backend.residents.listResidents(barcode: code),
      );
      if (!mounted || request != generation || barcode != code) return;
      if (page == null || page.items.length != 1) {
        throw const SaveFailure('未找到该药盒对应的长者，请核对标签或更换药盒。');
      }
      setState(() => resident = residentFromApi(page.items.single));
    } catch (failure) {
      if (mounted && request == generation) {
        setState(() => error = failure.toString());
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final terminal = widget.terminal;
    if (resident != null) {
      return ServerPlanDialog(
        key: ValueKey('${resident!.id}-$barcode'),
        backend: terminal.backend,
        resident: resident!,
        residents: widget.residents,
        settings: widget.settings,
        terminal: terminal,
        scannedBarcode: barcode,
      );
    }
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('为任意长者摆药'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              error ??
                  terminal.error ??
                  (loading
                      ? '正在读取长者资料…'
                      : terminal.state['message'] as String? ??
                            '请放入药盒，扫描条码识别长者。'),
            ),
            if (loading) const LinearProgressIndicator(),
          ],
        ),
        actions: [
          if (error != null && barcode != null)
            TextButton(
              onPressed: loading ? null : () => _resolve(barcode!),
              child: const Text('重新读取'),
            ),
          TextButton(
            onPressed: terminal.busy || terminal.state['pending'] != null
                ? null
                : () async {
                    if (!terminal.identifying || terminal.phase == 'recovery') {
                      Navigator.pop(context);
                      return;
                    }
                    closing = true;
                    await terminal.action('close_identification');
                    if (!mounted) return;
                    if (terminal.error != null) closing = false;
                    _changed();
                  },
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
