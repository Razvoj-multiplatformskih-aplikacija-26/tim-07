import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../actions/reservation_cancel.dart';
import '../data/mobile_demo_data.dart';
import '../text/reservation_texts.dart';
import 'message_screen.dart';

/// Detalj jedne rezervacije na posebnom ekranu (/reservations/:id).
class ReservationDetailsScreen extends StatelessWidget {
  final ReservationId reservationId;

  const ReservationDetailsScreen({super.key, required this.reservationId});

  static const title = 'Detalji rezervacije';

  void _reload(BuildContext context) {
    context.read<ReservationBloc>().add(
      const UserReservationsRequested(MobileDemoData.currentUserId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReservationBloc, ReservationState>(
      builder: (context, state) {
        return switch (state) {
          ReservationInitial() || ReservationLoading() => Scaffold(
            appBar: AppBar(title: const Text(title)),
            body: const Center(child: CircularProgressIndicator()),
          ),
          ReservationError(:final message) => Scaffold(
            appBar: AppBar(title: const Text(title)),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(errorDetails(message), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _reload(context),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Pokušaj ponovo'),
                  ),
                ],
              ),
            ),
          ),
          ReservationEmpty() => const MessageScreen(
            title: title,
            message: 'Rezervacija nije pronađena.',
          ),
          ReservationLoaded(:final reservations) => _body(
            context,
            reservations,
          ),
        };
      },
    );
  }

  Widget _body(BuildContext context, List<Reservation> reservations) {
    Reservation? reservation;
    for (final candidate in reservations) {
      if (candidate.id == reservationId &&
          candidate.userId == MobileDemoData.currentUserId) {
        reservation = candidate;
      }
    }

    if (reservation == null) {
      return const MessageScreen(
        title: title,
        message: 'Rezervacija nije pronađena.',
      );
    }

    final theme = Theme.of(context);
    final status = reservation.status;
    final cancellationError = validateCancellation(
      reservation: reservation,
      now: DateTime.now(),
    );

    return Scaffold(
      appBar: AppBar(title: const Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            MobileDemoData.fieldName(reservation.fieldId),
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              avatar: Icon(switch (status) {
                ReservationStatus.cancelled => Icons.cancel_outlined,
                ReservationStatus.completed => Icons.check_circle_outline,
                ReservationStatus.confirmed => Icons.event_available,
                ReservationStatus.pending => Icons.schedule,
              }, size: 18),
              label: Text(statusLabel(status)),
            ),
          ),
          const SizedBox(height: 16),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Datum',
            value: formatDate(reservation.startTime),
          ),
          _DetailRow(
            icon: Icons.access_time,
            label: 'Termin',
            value: formatTimeRange(reservation.startTime, reservation.endTime),
          ),
          _DetailRow(
            icon: Icons.person_outline,
            label: 'Korisnik',
            value: MobileDemoData.currentUserName,
          ),
          _DetailRow(
            icon: Icons.payments_outlined,
            label: 'Cena',
            value: formatPrice(reservation.totalPrice),
          ),
          _DetailRow(
            icon: Icons.event_note_outlined,
            label: 'Kreirana',
            value: formatDate(reservation.createdAt),
          ),
          if (reservation.cancellationReason != null)
            _DetailRow(
              icon: Icons.info_outline,
              label: 'Razlog otkazivanja',
              value: reservation.cancellationReason!,
            ),
          if (reservation.isActive) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: cancellationError == null
                  ? () =>
                        cancelReservationWithConfirmation(context, reservation!)
                  : null,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Otkaži rezervaciju'),
            ),
            if (cancellationError != null) ...[
              const SizedBox(height: 8),
              Text(
                validationMessage(cancellationError),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                Text(value, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
