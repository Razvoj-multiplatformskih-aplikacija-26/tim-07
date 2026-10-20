import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'layout/backoffice_shell.dart';
import 'selection/reservation_selection_bloc.dart';
import 'theme/backoffice_theme.dart';

class BackofficeApp extends StatelessWidget {
  final ReservationRepository repository;

  const BackofficeApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<ReservationRepository>.value(
      value: repository,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => ReservationBloc(repository: repository)
              ..add(const ReservationsRequested()),
          ),
          BlocProvider(create: (_) => ReservationSelectionBloc()),
        ],
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
