import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'layout/backoffice_shell.dart';
import 'theme/backoffice_theme.dart';

/// Koren backoffice aplikacije.
///
/// Repozitorijum se prosledjuje spolja, pa aplikacija
/// ne zna da li radi sa FakeRepository-jem ili pravim API-jem.
class BackofficeApp extends StatelessWidget {
  final ReservationRepository repository;

  const BackofficeApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<ReservationRepository>.value(
      value: repository,
      child: BlocProvider(
        create: (_) => ReservationBloc(repository: repository)
          ..add(const ReservationsRequested()),
        child: MaterialApp(
          title: 'Terenzo backoffice',
          debugShowCheckedModeBanner: false,
          theme: BackofficeTheme.lightTheme,
          darkTheme: BackofficeTheme.darkTheme,
          themeMode: ThemeMode.system,
          home: const BackofficeShell(),
        ),
      ),
    );
  }
}
