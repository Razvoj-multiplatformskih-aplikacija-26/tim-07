import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messages/messages.dart';

import '../auth/current_user.dart';
import '../text/reservation_texts.dart';

/// Forma za novu rezervaciju (`/fields/:fieldId/reserve`).
///
/// Provera termina i slanje su u `ReservationFormBloc`-u; ekran šalje događaje
/// i crta stanje. Bez prijavljenog korisnika (prijava je upravo istekla) ostaje
/// prazan dok router ne vrati na prijavu.
class ReservationFormScreen extends StatelessWidget {
  final SportsField field;
  final DateTime date;
  final String initialStart;
  final String initialEnd;

  const ReservationFormScreen({
    super.key,
    required this.field,
    required this.date,
    required this.initialStart,
    required this.initialEnd,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watchUser;
    if (user == null) return const SizedBox.shrink();

    return BlocProvider(
      // Drugi korisnik na istom ekranu dobija novu formu, ne tuđe podatke.
      key: ValueKey(user.id),
      create: (context) => ReservationFormBloc(
        reservations: context.read<ReservationRepository>(),
        schedules: context.read<FieldScheduleRepository>(),
        field: field,
        userId: user.id,
        date: date,
        initialStart: initialStart,
        initialEnd: initialEnd,
      )..add(const ReservationFormStarted()),
      child: _ReservationFormView(field: field, date: date, user: user),
    );
  }
}

class _ReservationFormView extends StatefulWidget {
  final SportsField field;
  final DateTime date;
  final AppUser user;

  const _ReservationFormView({
    required this.field,
    required this.date,
    required this.user,
  });

  @override
  State<_ReservationFormView> createState() => _ReservationFormViewState();
}

class _ReservationFormViewState extends State<_ReservationFormView> {
  static const _formatHint = 'Unesite vreme u obliku HH:mm, na primer 18:00.';

  // Tekst u poljima pripada ekranu, a provera i slanje Bloc-u.
  late final TextEditingController _start;
  late final TextEditingController _end;

  @override
  void initState() {
    super.initState();
    final state = context.read<ReservationFormBloc>().state;
    _start = TextEditingController(text: state.startText);
    _end = TextEditingController(text: state.endText);
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  void _onState(BuildContext context, ReservationFormState state) {
    final messenger = ScaffoldMessenger.of(context);

    switch (state) {
      case ReservationFormSucceeded():
        messenger.showSnackBar(
          const SnackBar(content: Text('Rezervacija je uspešno kreirana!')),
        );
        // Spisak mojih rezervacija se osvežava sa novom rezervacijom.
        context.read<ReservationBloc>().add(
          UserReservationsRequested(widget.user.id),
        );
        Navigator.of(context).pop();
      case ReservationFormRejected(:final message) ||
          ReservationFormFailed(:final message):
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ReservationFormBloc>();

    return BlocConsumer<ReservationFormBloc, ReservationFormState>(
      listener: _onState,
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Nova rezervacija')),
          body: switch (state) {
            ReservationFormLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            ReservationFormLoadFailed(:final message) => _LoadFailed(
              message: message,
              onRetry: () => bloc.add(const ReservationFormStarted()),
            ),
            _ => _form(context, bloc, state),
          },
        );
      },
    );
  }

  Widget _form(
    BuildContext context,
    ReservationFormBloc bloc,
    ReservationFormState state,
  ) {
    final theme = Theme.of(context);
    final submitting = state is ReservationFormSubmitting;
    final editing = state is ReservationFormEditing ? state : null;
    final price = editing?.price;

    // Poruka o odbijanju ostaje na ekranu dok korisnik ne izmeni unos.
    final notice = switch (state) {
      ReservationFormRejected(:final message) ||
      ReservationFormFailed(:final message) => message,
      _ => null,
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Detalji rezervacije', style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.field.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Text('Datum: ${formatDate(widget.date)}'),
                const SizedBox(height: 8),
                Text(
                  'Cena: ${price == null ? '-' : formatPrice(price)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Termin', style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: _start,
          enabled: !submitting,
          keyboardType: TextInputType.datetime,
          onChanged: (text) => bloc.add(ReservationFormStartChanged(text)),
          decoration: InputDecoration(
            labelText: 'Početak (HH:mm)',
            prefixIcon: const Icon(Icons.schedule),
            border: const OutlineInputBorder(),
            errorText: editing?.startInvalid == true ? _formatHint : null,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _end,
          enabled: !submitting,
          keyboardType: TextInputType.datetime,
          onChanged: (text) => bloc.add(ReservationFormEndChanged(text)),
          decoration: InputDecoration(
            labelText: 'Kraj (HH:mm)',
            prefixIcon: const Icon(Icons.schedule),
            border: const OutlineInputBorder(),
            errorText: editing == null
                ? null
                : editing.endInvalid
                ? _formatHint
                : editing.slotError == null
                ? null
                : validationMessage(editing.slotError!),
          ),
        ),
        if (notice != null) ...[
          const SizedBox(height: 16),
          // Poruka je u živoj oblasti, da je čitač ekrana pročita.
          Semantics(
            liveRegion: true,
            child: Text(
              notice,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text('Podaci za rezervaciju', style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: widget.user.fullName,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Ime i prezime',
            prefixIcon: Icon(Icons.person_outline),
            border: OutlineInputBorder(),
            helperText: 'Prijavljeni korisnik',
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: submitting
              ? null
              : () => bloc.add(const ReservationFormSubmitted()),
          icon: submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_outline),
          label: Text(
            submitting ? 'Slanje rezervacije...' : 'Potvrdi rezervaciju',
          ),
        ),
      ],
    );
  }
}

class _LoadFailed extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadFailed({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Pokušaj ponovo'),
            ),
          ],
        ),
      ),
    );
  }
}
