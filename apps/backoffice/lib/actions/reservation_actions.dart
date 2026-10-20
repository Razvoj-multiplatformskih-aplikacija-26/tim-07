import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../text/labels.dart';

List<ReservationStatus> allowedTransitions(Reservation reservation) => [
      for (final to in ReservationStatus.values)
        if (to != ReservationStatus.completed &&
            canTransitionReservationStatus(reservation.status, to))
          to,
    ];

bool needsConfirmation(ReservationStatus target) =>
    target == ReservationStatus.cancelled;

ReservationEvent? _eventFor(Reservation reservation, ReservationStatus target) {
  return switch (target) {
    ReservationStatus.confirmed => ReservationConfirmRequested(reservation.id),
    ReservationStatus.cancelled => ReservationCancelRequested(reservation.id),
    ReservationStatus.pending || ReservationStatus.completed => null,
  };
}

Future<void> runReservationAction(
  BuildContext context,
  Reservation reservation,
  ReservationStatus target,
) async {
  if (!allowedTransitions(reservation).contains(target)) {
    return;
  }

  final event = _eventFor(reservation, target);
  if (event == null) {
    return;
  }

  if (needsConfirmation(target)) {
    final confirmed = await _confirm(context, reservation, target);
    if (!confirmed || !context.mounted) {
      return;
    }
  }

  context.read<ReservationBloc>().add(event);
}

Future<bool> _confirm(
  BuildContext context,
  Reservation reservation,
  ReservationStatus target,
) async {
  final label = actionLabel(reservation.status, target);

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final colors = Theme.of(dialogContext).colorScheme;

      return AlertDialog(
        title: Text('$label rezervaciju #${reservation.id.value}?'),
        content: const Text('Ova radnja se ne može poništiti.'),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(label),
          ),
        ],
      );
    },
  );

  return result ?? false;
}
