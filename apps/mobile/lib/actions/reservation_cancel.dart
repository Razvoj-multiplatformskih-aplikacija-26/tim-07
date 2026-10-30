import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../text/reservation_texts.dart';

/// Otkazivanje je nepovratno, pa traži potvrdu u dijalogu.
/// Rok proverava pravilo iz paketa domain; ekran samo bira poruku.
Future<void> cancelReservationWithConfirmation(
  BuildContext context,
  Reservation reservation,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final bloc = context.read<ReservationBloc>();

  final error = validateCancellation(
    reservation: reservation,
    now: DateTime.now(),
  );
  if (error != null) {
    messenger.showSnackBar(SnackBar(content: Text(validationMessage(error))));
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Otkaži rezervaciju'),
      content: const Text(
        'Da li ste sigurni da želite da otkažete ovu rezervaciju?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Ne'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Da, otkaži'),
        ),
      ],
    ),
  );

  if (confirmed != true) {
    return;
  }

  bloc.add(ReservationCancelRequested(reservation.id));
}
