import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../text/labels.dart';

class FieldReviewPage extends StatelessWidget {
  const FieldReviewPage({super.key});

  Future<void> _reject(BuildContext context, SportsField field) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Odbij „${field.name}“?'),
        content: TextField(
          controller: reason,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Razlog (vidi ga vlasnik)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Odustani')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Odbij')),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (confirmed == true && context.mounted) {
      context.read<FieldReviewBloc>().add(
        FieldReviewDecided(field.id, ApprovalStatus.rejected, reason: text.isEmpty ? null : text),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FieldReviewBloc, FieldReviewState>(
      listenWhen: (previous, current) => current is FieldReviewLoaded && current.message != null,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text((state as FieldReviewLoaded).message!))),
      builder: (context, state) => switch (state) {
        FieldReviewLoading() => const Center(child: CircularProgressIndicator()),
        FieldReviewError(:final message) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.read<FieldReviewBloc>().add(const FieldReviewStarted()),
                icon: const Icon(Icons.refresh),
                label: const Text('Pokušaj ponovo'),
              ),
            ],
          ),
        ),
        FieldReviewLoaded(:final waiting) when waiting.isEmpty => const Center(
          child: Text('Nema terena koji čekaju odobrenje.'),
        ),
        FieldReviewLoaded(:final waiting, :final busy) => ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: waiting.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final field = waiting[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(field.name, style: Theme.of(context).textTheme.titleMedium),
                    Text('${sportLabel(field.sport)} · ${field.address}, ${field.city} · ${formatPrice(field.pricePerHour)} / sat'),
                    if (field.description.isNotEmpty) Text(field.description),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: busy
                              ? null
                              : () => context.read<FieldReviewBloc>().add(
                                  FieldReviewDecided(field.id, ApprovalStatus.approved),
                                ),
                          icon: const Icon(Icons.check),
                          label: const Text('Odobri'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => _reject(context, field),
                          icon: const Icon(Icons.close),
                          label: const Text('Odbij'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      },
    );
  }
}
