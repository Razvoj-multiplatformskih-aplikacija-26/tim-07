import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'data/directory.dart';
import 'layout/backoffice_shell.dart';
import 'screens/login_screen.dart';
import 'selection/reservation_selection_bloc.dart';
import 'theme/backoffice_theme.dart';

class BackofficeApp extends StatefulWidget {
  final ReservationRepository repository;
  final SportsFieldRepository fieldRepository;
  final FieldScheduleRepository scheduleRepository;
  final AuthRepository? authRepository;
  final AppUser? owner;

  const BackofficeApp({
    super.key,
    required this.repository,
    required this.fieldRepository,
    required this.scheduleRepository,
    this.authRepository,
    this.owner,
  }) : assert(authRepository != null || owner != null);

  @override
  State<BackofficeApp> createState() => _BackofficeAppState();
}

class _BackofficeAppState extends State<BackofficeApp> {
  late final ReservationBloc _reservations = ReservationBloc(repository: widget.repository);
  late final ReservationSelectionBloc _selection = ReservationSelectionBloc();
  late final DirectoryCubit _directory = DirectoryCubit(
    fieldRepository: widget.fieldRepository,
    initial: BackofficeDirectory.demo(),
  );
  late final AuthBloc? _auth = switch (widget.authRepository) {
    final repository? => AuthBloc(repository: repository, app: ClientApp.backoffice)..add(const AuthStarted()),
    null => null,
  };

  @override
  void initState() {
    super.initState();
    if (_auth == null) {
      _directory.load();
      _reservations.add(const ReservationsRequested());
    }
  }

  @override
  void dispose() {
    _auth?.close();
    _directory.close();
    _selection.close();
    _reservations.close();
    super.dispose();
  }

  void _onAuthChanged(BuildContext context, AuthState state) {
    if (state is AuthAuthenticated) {
      _directory.load();
      _reservations.add(const ReservationsRequested());
    } else if (state is AuthUnauthenticated) {
      _directory.clear();
      _reservations.add(const ReservationsCleared());
    }
  }

  Widget _workspace(AppUser owner) => BlocProvider(
    key: ValueKey(owner.id),
    create: (_) => BlockedPeriodsBloc(
      fields: widget.fieldRepository,
      schedules: widget.scheduleRepository,
      reservations: widget.repository,
      owner: owner,
    )..add(const BlockedPeriodsStarted()),
    child: const BackofficeShell(),
  );

  @override
  Widget build(BuildContext context) {
    final auth = _auth;
    final home = auth == null
        ? _workspace(widget.owner!)
        : BlocConsumer<AuthBloc, AuthState>(
            listenWhen: (previous, current) => previous.runtimeType != current.runtimeType,
            listener: _onAuthChanged,
            builder: (context, state) =>
                state is AuthAuthenticated ? _workspace(state.user) : const LoginScreen(),
          );

    return RepositoryProvider<ReservationRepository>.value(
      value: widget.repository,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _reservations),
          BlocProvider.value(value: _selection),
          BlocProvider.value(value: _directory),
          if (auth != null) BlocProvider.value(value: auth),
        ],
        child: MaterialApp(
          title: 'Terenzo backoffice',
          debugShowCheckedModeBanner: false,
          theme: BackofficeTheme.lightTheme,
          darkTheme: BackofficeTheme.darkTheme,
          themeMode: ThemeMode.system,
          home: home,
        ),
      ),
    );
  }
}
