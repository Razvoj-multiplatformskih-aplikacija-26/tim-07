import 'package:blocs/blocs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Sekcija sa rezervacijama.
///
/// T22: proverava da je backoffice povezan sa ReservationBloc-om
/// i prikazuje broj ucitanih rezervacija.
/// Tabela (T23), bocni panel (T24) i sva cetiri stanja (T28)
/// dodaju se u narednim taskovima.
class ReservationsPage extends StatelessWidget {
  const ReservationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<ReservationBloc, ReservationState>(
      builder: (context, state) {
        final text = switch (state) {
          ReservationInitial() || ReservationLoading() =>
            'Učitavanje rezervacija...',
          ReservationLoaded(:final reservations) =>
            'Učitano rezervacija: ${reservations.length}',
          ReservationEmpty() => 'Nema rezervacija.',
          ReservationError(:final message) => 'Greška: $message',
        };

        return Center(
          child: Text(text, style: theme.textTheme.titleMedium),
        );
      },
    );
  }
}
