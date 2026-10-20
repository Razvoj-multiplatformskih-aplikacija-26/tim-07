import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../actions/reservation_actions.dart';
import '../data/backoffice_demo_data.dart';
import '../selection/reservation_selection_bloc.dart';
import '../text/labels.dart';
import 'reservation_status_chip.dart';

class ReservationDetailsPanel extends StatelessWidget {
  final List<Reservation> reservations;
  final FocusNode? actionsFocusNode;

  const ReservationDetailsPanel({
    super.key,
    required this.reservations,
    this.actionsFocusNode,
  });

  Reservation? _find(ReservationId? id) {
    if (id == null) {
      return null;
    }

    for (final reservation in reservations) {
      if (reservation.id == id) {
        return reservation;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selectedId =
        context.watch<ReservationSelectionBloc>().state.selectedId;
    final reservation = _find(selectedId);

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: reservation == null
          ? const _EmptyDetails()
          : _Details(
              key: ValueKey(reservation.id.value),
              reservation: reservation,
              actionsFocusNode: actionsFocusNode,
            ),
    );
  }
}

class _EmptyDetails extends StatelessWidget {
  const _EmptyDetails();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Izaberite rezervaciju u tabeli.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  final Reservation reservation;
  final FocusNode? actionsFocusNode;

  const _Details({
    super.key,
    required this.reservation,
    this.actionsFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final field = BackofficeDemoData.fieldById(reservation.fieldId);
    final user = BackofficeDemoData.userById(reservation.userId);
    final transitions = allowedTransitions(reservation);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Rezervacija #${reservation.id.value}',
                style: theme.textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Zatvori detalje',
              icon: const Icon(Icons.close),
              onPressed: () => context
                  .read<ReservationSelectionBloc>()
                  .add(const ReservationSelectionCleared()),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: ReservationStatusChip(status: reservation.status),
        ),
        const _SectionTitle('Teren'),
        _InfoRow(
          label: 'Naziv',
          value: field?.name ?? 'Teren #${reservation.fieldId.value}',
        ),
        if (field != null) ...[
          _InfoRow(label: 'Sport', value: sportLabel(field.sport)),
          _InfoRow(label: 'Adresa', value: '${field.address}, ${field.city}'),
        ],
        const _SectionTitle('Korisnik'),
        _InfoRow(
          label: 'Ime',
          value: user?.fullName ?? 'Korisnik #${reservation.userId.value}',
        ),
        if (user != null) ...[
          _InfoRow(label: 'Email', value: user.email),
          _InfoRow(label: 'Telefon', value: user.phoneNumber),
        ],
        const _SectionTitle('Termin'),
        _InfoRow(label: 'Datum', value: formatDate(reservation.startTime)),
        _InfoRow(
          label: 'Vreme',
          value: formatTimeRange(reservation.startTime, reservation.endTime),
        ),
        _InfoRow(label: 'Trajanje', value: formatDuration(reservation.duration)),
        const _SectionTitle('Plaćanje'),
        _InfoRow(label: 'Cena', value: formatPrice(reservation.totalPrice)),
        _InfoRow(label: 'Status', value: paymentLabel(reservation.paymentStatus)),
        const _SectionTitle('Dostupne akcije'),
        if (transitions.isEmpty)
          Text(
            'Nema dostupnih akcija za ovaj status.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (index, to) in transitions.indexed)
                _ActionButton(
                  reservation: reservation,
                  target: to,
                  focusNode: index == 0 ? actionsFocusNode : null,
                ),
            ],
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Reservation reservation;
  final ReservationStatus target;
  final FocusNode? focusNode;

  const _ActionButton({
    required this.reservation,
    required this.target,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final label = Text(actionLabel(reservation.status, target));
    void onPressed() => runReservationAction(context, reservation, target);

    if (needsConfirmation(target)) {
      final error = Theme.of(context).colorScheme.error;

      return OutlinedButton(
        focusNode: focusNode,
        style: OutlinedButton.styleFrom(
          foregroundColor: error,
          side: BorderSide(color: error),
        ),
        onPressed: onPressed,
        child: label,
      );
    }

    return FilledButton(
      focusNode: focusNode,
      onPressed: onPressed,
      child: label,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
