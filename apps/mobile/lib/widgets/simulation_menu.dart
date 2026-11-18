import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/mobile_demo_data.dart';
import '../data/mobile_fake_repository.dart';

enum _SimulationAction { failNext, emptyNext, reload }

class SimulationMenu extends StatelessWidget {
  const SimulationMenu({super.key});

  void _onSelected(
    BuildContext context,
    MobileFakeReservationRepository repository,
    _SimulationAction action,
  ) {
    switch (action) {
      case _SimulationAction.failNext:
        repository.failNextRequest();
        _inform(context, 'Sledeći zahtev će vratiti grešku.');
      case _SimulationAction.emptyNext:
        repository.returnEmptyOnNextRequest();
        _inform(context, 'Sledeće učitavanje će vratiti praznu listu.');
      case _SimulationAction.reload:
        context.read<ReservationBloc>().add(
              const UserReservationsRequested(MobileDemoData.currentUserId),
            );
    }
  }

  void _inform(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<ReservationRepository>();
    if (repository is! MobileFakeReservationRepository) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<_SimulationAction>(
      tooltip: 'Simulacija',
      icon: const Icon(Icons.science_outlined),
      onSelected: (action) => _onSelected(context, repository, action),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _SimulationAction.failNext,
          child: ListTile(
            leading: Icon(Icons.error_outline),
            title: Text('Greška pri sledećem zahtevu'),
          ),
        ),
        PopupMenuItem(
          value: _SimulationAction.emptyNext,
          child: ListTile(
            leading: Icon(Icons.inbox_outlined),
            title: Text('Prazan odgovor pri sledećem učitavanju'),
          ),
        ),
        PopupMenuItem(
          value: _SimulationAction.reload,
          child: ListTile(
            leading: Icon(Icons.refresh),
            title: Text('Osveži rezervacije'),
          ),
        ),
      ],
    );
  }
}
