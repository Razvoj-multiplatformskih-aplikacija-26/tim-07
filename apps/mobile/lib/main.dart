import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:messages/messages.dart';

import 'data/mobile_auth.dart';
import 'data/mobile_availability_repository.dart';
import 'data/mobile_field_repository.dart';
import 'data/mobile_repository.dart';
import 'navigation/app_router.dart';
import 'theme/app_theme.dart';

void main() {
  final reservations = createMobileRepository();

  runApp(
    MyApp(
      repository: reservations,
      availabilityRepository: createMobileAvailabilityRepository(
        reservations: reservations,
      ),
      fieldRepository: createMobileFieldRepository(),
      authRepository: createMobileAuthRepository(),
    ),
  );
}

class MyApp extends StatefulWidget {
  final ReservationRepository repository;
  final SportsFieldRepository fieldRepository;
  final AvailabilityRepository availabilityRepository;
  final AuthRepository authRepository;

  /// Adresa na kojoj aplikacija počinje (za testove i duboke linkove).
  final String initialLocation;

  const MyApp({
    super.key,
    required this.repository,
    required this.fieldRepository,
    required this.availabilityRepository,
    required this.authRepository,
    this.initialLocation = '/',
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  late final AuthBloc _auth = AuthBloc(
    repository: widget.authRepository,
    app: ClientApp.mobile,
  )..add(const AuthStarted());

  late final ReservationBloc _reservations = ReservationBloc(
    repository: widget.repository,
  );

  // Katalog je javan, pa se učitava čim se aplikacija pokrene.
  late final FieldsBloc _fields = FieldsBloc(
    repository: widget.fieldRepository,
  )..add(const FieldsRequested());

  late final AuthRefresh _refresh = AuthRefresh(_auth.stream);

  late final GoRouter _router = AppRouter.create(
    auth: _auth,
    refresh: _refresh,
    initialLocation: widget.initialLocation,
  );

  @override
  void dispose() {
    _router.dispose();
    _refresh.dispose();
    _reservations.close();
    _fields.close();
    _auth.close();
    super.dispose();
  }

  // Rezervacije pripadaju prijavljenom korisniku: učitavaju se pri prijavi, a
  // pri odjavi se brišu, da sledeći korisnik ne vidi tuđe.
  void _onAuthChanged(BuildContext context, AuthState state) {
    final user = state.user;
    if (user != null) {
      _reservations.add(UserReservationsRequested(user.id));
    } else if (state is! AuthUnknown && state is! AuthSigningIn) {
      _reservations.add(const ReservationsCleared());
    }
  }

  // Adresa koja ne traži prijavu i nije sama prijava.
  bool _isPublicLocation() {
    final uri = _router.routeInformationProvider.value.uri;
    return uri.path != '/login' && !AppRouter.requiresLogin(uri);
  }

  // Istek prijave na javnom ekranu ne gura korisnika na prijavu, ali mu kaže
  // šta se desilo. Na zaštićenom ekranu to radi router.
  void _onExpired(BuildContext context, AuthState state) {
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(state.message ?? sessionExpiredMessage)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ReservationRepository>.value(
          value: widget.repository,
        ),
        RepositoryProvider<SportsFieldRepository>.value(
          value: widget.fieldRepository,
        ),
        RepositoryProvider<AvailabilityRepository>.value(
          value: widget.availabilityRepository,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _auth),
          BlocProvider.value(value: _reservations),
          BlocProvider.value(value: _fields),
        ],
        child: MultiBlocListener(
          listeners: [
            BlocListener<AuthBloc, AuthState>(listener: _onAuthChanged),
            BlocListener<AuthBloc, AuthState>(
              listenWhen: (previous, current) =>
                  previous is AuthAuthenticated &&
                  current is AuthUnauthenticated &&
                  current.reason == SignOutReason.expired &&
                  _isPublicLocation(),
              listener: _onExpired,
            ),
          ],
          child: MaterialApp.router(
            title: 'Rezervacija terena',
            scaffoldMessengerKey: _messenger,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            routerConfig: _router,
          ),
        ),
      ),
    );
  }
}
