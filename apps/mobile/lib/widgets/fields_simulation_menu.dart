import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/mobile_field_repository.dart';

enum _Action { failNext, emptyNext, reload }

/// Demo meni za katalog terena: izaziva grešku ili prazan odgovor sledećeg
/// zahteva. Postoji samo dok su tereni iz memorije; sa serverom ga nema.
class FieldsSimulationMenu extends StatelessWidget {
  const FieldsSimulationMenu({super.key});

  void _onSelected(
    BuildContext context,
    MobileFakeFieldRepository repository,
    _Action action,
  ) {
    switch (action) {
      case _Action.failNext:
        repository.failNextRequest();
        _inform(context, 'Sledeći zahtev će vratiti grešku.');
      case _Action.emptyNext:
        repository.returnEmptyOnNextRequest();
        _inform(context, 'Sledeće učitavanje će vratiti praznu listu.');
      case _Action.reload:
        context.read<FieldsBloc>().add(const FieldsRequested());
    }
  }

  void _inform(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<SportsFieldRepository>();
    if (repository is! MobileFakeFieldRepository) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<_Action>(
      tooltip: 'Simulacija terena',
      icon: const Icon(Icons.science_outlined),
      onSelected: (action) => _onSelected(context, repository, action),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _Action.failNext,
          child: ListTile(
            leading: Icon(Icons.error_outline),
            title: Text('Greška pri sledećem zahtevu'),
          ),
        ),
        PopupMenuItem(
          value: _Action.emptyNext,
          child: ListTile(
            leading: Icon(Icons.inbox_outlined),
            title: Text('Prazan odgovor pri sledećem učitavanju'),
          ),
        ),
        PopupMenuItem(
          value: _Action.reload,
          child: ListTile(
            leading: Icon(Icons.refresh),
            title: Text('Osveži terene'),
          ),
        ),
      ],
    );
  }
}
