import 'package:domain/domain.dart';
import 'package:flutter/material.dart' hide TimeOfDay;

const dayLabels = {
  WeekDay.monday: 'Ponedeljak',
  WeekDay.tuesday: 'Utorak',
  WeekDay.wednesday: 'Sreda',
  WeekDay.thursday: 'Četvrtak',
  WeekDay.friday: 'Petak',
  WeekDay.saturday: 'Subota',
  WeekDay.sunday: 'Nedelja',
};

final _times = [
  for (var minutes = 0; minutes < 24 * 60; minutes += 30) TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
];

String _time(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

String scheduleErrorLabel(ScheduleValidationError error) => switch (error) {
  OpeningAfterClosing(:final day) => '${dayLabels[day]}: otvaranje mora biti pre zatvaranja.',
  InvalidTimeOfDay(:final day) => '${dayLabels[day]}: neispravno vreme.',
  DuplicateScheduleDay(:final day) => '${dayLabels[day]}: dan je naveden dvaput.',
  ScheduleForOtherField() => 'Radno vreme pripada drugom terenu.',
};

class ScheduleEditor extends StatefulWidget {
  final FieldId fieldId;
  final List<FieldSchedule> schedules;
  final bool busy;
  final ValueChanged<List<FieldSchedule>> onSave;

  const ScheduleEditor({
    super.key,
    required this.fieldId,
    required this.schedules,
    required this.busy,
    required this.onSave,
  });

  @override
  State<ScheduleEditor> createState() => _ScheduleEditorState();
}

class _Day {
  bool open;
  int opens;
  int closes;

  _Day({required this.open, required this.opens, required this.closes});
}

class _ScheduleEditorState extends State<ScheduleEditor> {
  late Map<WeekDay, _Day> _days = _fromSchedules(widget.schedules);
  String? _error;

  @override
  void didUpdateWidget(ScheduleEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fieldId != widget.fieldId || oldWidget.schedules != widget.schedules) {
      _days = _fromSchedules(widget.schedules);
      _error = null;
    }
  }

  Map<WeekDay, _Day> _fromSchedules(List<FieldSchedule> schedules) => {
    for (final day in WeekDay.values)
      day: switch (schedules.where((s) => s.dayOfWeek == day).firstOrNull) {
        final s? => _Day(open: s.isOpen, opens: s.opensAt.totalMinutes, closes: s.closesAt.totalMinutes),
        null => _Day(open: false, opens: 8 * 60, closes: 22 * 60),
      },
  };

  List<FieldSchedule> get _schedules => [
    for (final entry in _days.entries)
      FieldSchedule(
        fieldId: widget.fieldId,
        dayOfWeek: entry.key,
        opensAt: TimeOfDay(hour: entry.value.opens ~/ 60, minute: entry.value.opens % 60),
        closesAt: TimeOfDay(hour: entry.value.closes ~/ 60, minute: entry.value.closes % 60),
        isOpen: entry.value.open,
      ),
  ];

  void _save() {
    final schedules = _schedules;
    final error = validateFieldSchedule(fieldId: widget.fieldId, schedules: schedules);
    setState(() => _error = error == null ? null : scheduleErrorLabel(error));
    if (error == null) widget.onSave(schedules);
  }

  Widget _timePicker(int value, bool enabled, ValueChanged<int> onChanged, String label) => DropdownButton<int>(
    value: value,
    onChanged: enabled ? (minutes) => setState(() => onChanged(minutes ?? value)) : null,
    hint: Text(label),
    items: [
      for (final time in _times) DropdownMenuItem(value: time.totalMinutes, child: Text(_time(time))),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Radno vreme', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final entry in _days.entries)
          Row(
            children: [
              SizedBox(width: 110, child: Text(dayLabels[entry.key]!)),
              Checkbox(
                value: entry.value.open,
                onChanged: widget.busy ? null : (value) => setState(() => entry.value.open = value ?? false),
              ),
              SizedBox(width: 70, child: Text(entry.value.open ? 'Radi' : 'Ne radi')),
              _timePicker(entry.value.opens, entry.value.open && !widget.busy, (m) => entry.value.opens = m, 'Od'),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('–')),
              _timePicker(entry.value.closes, entry.value.open && !widget.busy, (m) => entry.value.closes = m, 'Do'),
            ],
          ),
        if (_error case final error?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(error, style: TextStyle(color: theme.colorScheme.error)),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: widget.busy ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Sačuvaj radno vreme'),
        ),
      ],
    );
  }
}
