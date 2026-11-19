import 'package:domain/domain.dart' show SportsField;
import 'package:flutter/material.dart';

import '../text/labels.dart';

/// Šta je vlasnik uneo u dijalogu za blokadu.
typedef BlockDraft = ({DateTime start, DateTime end, String? reason});

/// Dijalog za novu blokadu terena. Vraća unos ili `null` kada je odustao.
///
/// Dijalog ne proverava pravila: kraj pre početka, prošlost i potvrđene
/// rezervacije proverava Bloc istim pravilom kao server i prikazuje razlog.
Future<BlockDraft?> showAddBlockDialog(
  BuildContext context, {
  required SportsField field,
}) {
  return showDialog<BlockDraft>(
    context: context,
    builder: (context) => _AddBlockDialog(field: field),
  );
}

class _AddBlockDialog extends StatefulWidget {
  final SportsField field;

  const _AddBlockDialog({required this.field});

  @override
  State<_AddBlockDialog> createState() => _AddBlockDialogState();
}

class _AddBlockDialogState extends State<_AddBlockDialog> {
  // Početna ponuda: sutra od 10 do 12 časova.
  late DateTime _start = _tomorrowAt(10);
  late DateTime _end = _tomorrowAt(12);
  final _reason = TextEditingController();

  static DateTime _tomorrowAt(int hour) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1, hour);
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime current) async {
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Blokiraj ${widget.field.name}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DateTimeButton(
              label: 'Početak',
              value: _start,
              onPressed: () async {
                final picked = await _pick(_start);
                if (picked != null) setState(() => _start = picked);
              },
            ),
            const SizedBox(height: 12),
            _DateTimeButton(
              label: 'Kraj',
              value: _end,
              onPressed: () async {
                final picked = await _pick(_end);
                if (picked != null) setState(() => _end = picked);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Razlog (neobavezno)',
                hintText: 'Održavanje, turnir...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            start: _start,
            end: _end,
            reason: _reason.text,
          )),
          child: const Text('Blokiraj'),
        ),
      ],
    );
  }
}

class _DateTimeButton extends StatelessWidget {
  final String label;
  final DateTime value;
  final VoidCallback onPressed;

  const _DateTimeButton({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.calendar_month),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text('$label: ${formatDateTime(value)}'),
      ),
    );
  }
}
