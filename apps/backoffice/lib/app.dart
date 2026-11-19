import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'data/backoffice_demo_data.dart';
import 'data/directory.dart';
import 'layout/backoffice_shell.dart';
import 'screens/login_screen.dart';
import 'selection/reservation_selection_bloc.dart';
import 'theme/backoffice_theme.dart';

class BackofficeApp extends StatefulWidget {
  final ReservationRepository repository;

  /// Izvor tabele rezervacija (filteri, pretraga, strane). Kada nije dat,
  /// koristi se [repository], koji ga mora implementirati.
  final ReservationSearchRepository? searchRepository;
  final SportsFieldRepository fieldRepository;
  final FieldScheduleRepository scheduleRepository;
  final AuthRepository? authRepository;
  final StatisticsRepository? statisticsRepository;

  /// Nalozi za stranicu „Korisnici“. Kada nije dat, koriste se demo nalozi iz
  /// memorije.
  final UserAdministrationRepository? userRepository;
  final AppUser? owner;

  const BackofficeApp({
    super.key,
    required this.repository,
    this.searchRepository,
    required this.fieldRepository,
    required this.scheduleRepository,
    this.authRepository,
    this.statisticsRepository,
    this.userRepository,
    this.owner,
  }) : assert(authRepository != null || owner != null),
       assert(
         searchRepository != null || repository is ReservationSearchRepository,
         'Tabela rezervacija traži ReservationSearchRepository.',
       );

  @override
  State<BackofficeApp> createState() => _BackofficeAppState();
}

class _BackofficeAppState extends State<BackofficeApp> {
  late final ReservationBloc _reservations = ReservationBloc(repository: widget.repository);
  // Tabela rezervacija: filteri, pretraga i strane. `ReservationBloc` ostaje za
  // akcije nad jednom rezervacijom (potvrda, otkazivanje).
  late final ReservationListBloc _list = ReservationListBloc(
    reservations:
        widget.searchRepository ?? widget.repository as ReservationSearchRepository,
  );
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
      _list.add(const ReservationListStarted());
    }
  }

  @override
  void dispose() {
    _auth?.close();
    _directory.close();
    _selection.close();
    _reservations.close();
    _list.close();
    super.dispose();
  }

  void _onAuthChanged(BuildContext context, AuthState state) {
    if (state is AuthAuthenticated) {
      _directory.load();
      _list.add(const ReservationListStarted());
    } else if (state is AuthUnauthenticated) {
      _directory.clear();
      _reservations.add(const ReservationsCleared());
      _list.add(const ReservationListCleared());
    }
  }

    Widget _workspace(AppUser owner) => MultiBlocProvider(
    key: ValueKey(owner.id),
    providers: [
      RepositoryProvider<AppUser>.value(value: owner),
      BlocProvider(
        create: (_) => StatisticsBloc(
          repository: widget.statisticsRepository ??
              LocalStatisticsRepository(
                fields: widget.fieldRepository,
                schedules: widget.scheduleRepository,
                reservations: widget.repository,
                viewer: owner,
              ),
          viewer: owner,
        )..add(const StatisticsStarted()),
      ),
      BlocProvider(
        create: (_) => FieldReviewBloc(fields: widget.fieldRepository, reviewer: owner)..add(const FieldReviewStarted()),
      ),
      BlocProvider(
        create: (_) => BlockedPeriodsBloc(
          fields: widget.fieldRepository,
          schedules: widget.scheduleRepository,
          reservations: widget.repository,
          owner: owner,
        )..add(const BlockedPeriodsStarted()),
      ),
      BlocProvider(
        create: (_) => CalendarBloc(
          fields: widget.fieldRepository,
          schedules: widget.scheduleRepository,
          reservations: widget.repository,
          owner: owner,
        )..add(const CalendarStarted()),
      ),
      if (canManageUsers(owner))
        BlocProvider(
          create: (_) => UsersBloc(
            users: widget.userRepository ??
                FakeUserAdministrationRepository(
                  users: [...BackofficeDemoData.users, owner],
                ),
            viewer: owner,
          )..add(const UsersStarted()),
        ),
      BlocProvider(
        create: (_) => FieldManagementBloc(
          fields: widget.fieldRepository,
          schedules: widget.scheduleRepository,
          owner: owner,
        )..add(const FieldManagementStarted()),
      ),
    ],
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
          BlocProvider.value(value: _list),
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
