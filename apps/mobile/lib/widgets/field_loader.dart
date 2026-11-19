import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../screens/message_screen.dart';

/// Učitava jedan teren po adresi (`/fields/:fieldId`) i tek tada pravi ekran.
///
/// Ima sva četiri stanja: učitavanje, greška sa „Pokušaj ponovo“, teren koji ne
/// postoji i teren. Teren ne dolazi iz demo podataka, pa isti ekran radi i sa serverom.
class FieldLoader extends StatelessWidget {
  final FieldId fieldId;
  final String title;
  final Widget Function(SportsField field) builder;

  const FieldLoader({
    super.key,
    required this.fieldId,
    required this.title,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          FieldDetailsBloc(repository: context.read<SportsFieldRepository>())
            ..add(FieldDetailsRequested(fieldId)),
      child: BlocBuilder<FieldDetailsBloc, FieldDetailsState>(
        builder: (context, state) {
          return switch (state) {
            FieldDetailsLoading() => Scaffold(
              appBar: AppBar(title: Text(title)),
              body: const Center(child: CircularProgressIndicator()),
            ),
            FieldDetailsNotFound() => MessageScreen(
              title: title,
              message: 'Teren nije pronađen.',
            ),
            FieldDetailsError(:final message) => Scaffold(
              appBar: AppBar(title: Text(title)),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(message, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => context.read<FieldDetailsBloc>().add(
                          FieldDetailsRequested(fieldId),
                        ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Pokušaj ponovo'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            FieldDetailsLoaded(:final field) => builder(field),
          };
        },
      ),
    );
  }
}
