import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../text/labels.dart';
import '../widgets/field_form_dialog.dart';
import '../widgets/schedule_editor.dart';

String approvalLabel(SportsField field) => switch (field.approvalStatus) {
  ApprovalStatus.pending => 'Čeka odobrenje',
  ApprovalStatus.approved => field.isActive ? 'Objavljen' : 'Neaktivan',
  ApprovalStatus.rejected => 'Odbijen',
};

class FieldsPage extends StatelessWidget {
  const FieldsPage({super.key});

  static Future<void> add(BuildContext context) async {
    final draft = await showFieldFormDialog(context);
    if (draft != null && context.mounted) {
      context.read<FieldManagementBloc>().add(FieldSaveRequested(draft));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FieldManagementBloc, FieldManagementState>(
      listenWhen: (previous, current) => switch (current) {
        FieldManagementLoaded(:final message?) => message != (previous is FieldManagementLoaded ? previous.message : null),
        FieldManagementEmpty(:final message?) => message.isNotEmpty,
        _ => false,
      },
      listener: (context, state) {
        final message = switch (state) {
          FieldManagementLoaded(:final message) => message,
          FieldManagementEmpty(:final message) => message,
          _ => null,
        };
        if (message == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
      builder: (context, state) => switch (state) {
        FieldManagementLoading() => const Center(child: CircularProgressIndicator()),
        FieldManagementError(:final message) => _Notice(
          icon: Icons.error_outline,
          title: 'Tereni nisu učitani',
          message: message,
          action: FilledButton.icon(
            onPressed: () => context.read<FieldManagementBloc>().add(const FieldManagementStarted()),
            icon: const Icon(Icons.refresh),
            label: const Text('Pokušaj ponovo'),
          ),
        ),
        FieldManagementEmpty(:final busy) => _Notice(
          icon: Icons.stadium_outlined,
          title: 'Nemate nijedan teren',
          message: 'Dodajte prvi teren. Biće vidljiv korisnicima kada ga administrator odobri.',
          action: FilledButton.icon(
            onPressed: busy ? null : () => add(context),
            icon: const Icon(Icons.add),
            label: const Text('Dodaj teren'),
          ),
        ),
        final FieldManagementLoaded loaded => _Loaded(state: loaded),
      },
    );
  }
}

class _Loaded extends StatelessWidget {
  final FieldManagementLoaded state;

  const _Loaded({required this.state});

  Future<void> _edit(BuildContext context) async {
    final draft = await showFieldFormDialog(context, field: state.field);
    if (draft != null && context.mounted) {
      context.read<FieldManagementBloc>().add(FieldSaveRequested(draft, fieldId: state.field.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final field = state.field;
    final bloc = context.read<FieldManagementBloc>();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: state.busy ? null : () => FieldsPage.add(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Dodaj teren'),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final candidate in state.fields)
                      ListTile(
                        selected: candidate.id == field.id,
                        leading: const Icon(Icons.stadium_outlined),
                        title: Text(candidate.name),
                        subtitle: Text('${sportLabel(candidate.sport)} · ${candidate.city} · ${approvalLabel(candidate)}'),
                        onTap: () => bloc.add(FieldManagementFieldSelected(candidate.id)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(child: Text(field.name, style: theme.textTheme.headlineSmall)),
                  OutlinedButton.icon(
                    onPressed: state.busy ? null : () => _edit(context),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Izmeni'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text(approvalLabel(field))),
                  Chip(label: Text(sportLabel(field.sport))),
                  Chip(label: Text('${formatPrice(field.pricePerHour)} / sat')),
                  Chip(
                    label: Text(
                      field.confirmationMode == ConfirmationMode.manual ? 'Ručna potvrda' : 'Automatska potvrda',
                    ),
                  ),
                ],
              ),
              if (field.approvalStatus == ApprovalStatus.rejected && field.rejectionReason != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Razlog odbijanja: ${field.rejectionReason}. Posle izmene teren ponovo čeka odobrenje.',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              const SizedBox(height: 12),
              Text('${field.address}, ${field.city} · ${field.contactPhone}'),
              if (field.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(field.description),
              ],
              const Divider(height: 32),
              ScheduleEditor(
                fieldId: field.id,
                schedules: state.schedules,
                busy: state.busy,
                onSave: (schedules) => bloc.add(FieldScheduleSaveRequested(schedules)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget action;

  const _Notice({required this.icon, required this.title, required this.message, required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            action,
          ],
        ),
      ),
    );
  }
}
