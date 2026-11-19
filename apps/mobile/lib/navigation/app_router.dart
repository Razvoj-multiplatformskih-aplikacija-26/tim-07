import 'dart:async';

import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../screens/field_details_screen.dart';
import '../screens/fields_screen.dart';
import '../screens/home_screen.dart';
import '../screens/message_screen.dart';
import '../screens/reservation_details_screen.dart';
import '../screens/reservation_form_screen.dart';
import '../screens/reservations_screen.dart';
import '../screens/sign_in_screen.dart';
import '../widgets/field_loader.dart';
import 'main_navigation.dart';

/// Adrese ekrana:
///   /                                  početna
///   /fields                            katalog terena
///   /fields/:fieldId                   detalj terena
///   /fields/:fieldId/reserve           forma (?date=...&start=HH:mm&end=HH:mm)
///   /reservations                      moje rezervacije
///   /reservations/:reservationId       detalj rezervacije
///   /login?from=ADRESA                 prijava
///
/// Katalog (`/`, `/fields`, `/fields/:id`) je javan. Rezervisanje i moje
/// rezervacije traže prijavu: bez nje router vodi na `/login`, a posle prijave
/// nazad na adresu sa koje je korisnik došao.
class AppRouter {
  static GoRouter create({
    required AuthBloc auth,
    required Listenable refresh,
    String initialLocation = '/',
  }) => GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refresh,
    redirect: (context, state) => guard(auth.state, state.uri),
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            SignInScreen(from: state.uri.queryParameters['from']),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigation(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/fields',
                builder: (context, state) => const FieldsScreen(),
                routes: [
                  GoRoute(
                    path: ':fieldId',
                    builder: (context, state) {
                      final id = _fieldId(state);

                      if (id == null) {
                        return const MessageScreen(
                          title: 'Detalji terena',
                          message: 'Teren nije pronađen.',
                        );
                      }

                      return FieldLoader(
                        fieldId: id,
                        title: 'Detalji terena',
                        builder: (field) => BlocProvider(
                          create: (context) => AvailabilityBloc(
                            repository: context.read<AvailabilityRepository>(),
                            fieldId: field.id,
                          )..add(const AvailabilityRequested()),
                          child: FieldDetailsScreen(field: field),
                        ),
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'reserve',
                        builder: (context, state) {
                          final id = _fieldId(state);
                          final query = state.uri.queryParameters;
                          final date = DateTime.tryParse(query['date'] ?? '');
                          final start = query['start'];
                          final end = query['end'];

                          if (id == null ||
                              date == null ||
                              start == null ||
                              end == null) {
                            return const MessageScreen(
                              title: 'Nova rezervacija',
                              message: 'Termin nije pronađen.',
                            );
                          }

                          return FieldLoader(
                            fieldId: id,
                            title: 'Nova rezervacija',
                            builder: (field) => ReservationFormScreen(
                              field: field,
                              date: date,
                              initialStart: start,
                              initialEnd: end,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reservations',
                builder: (context, state) => const ReservationsScreen(),
                routes: [
                  GoRoute(
                    path: ':reservationId',
                    builder: (context, state) {
                      final id = int.tryParse(
                        state.pathParameters['reservationId'] ?? '',
                      );

                      if (id == null) {
                        return const MessageScreen(
                          title: ReservationDetailsScreen.title,
                          message: 'Rezervacija nije pronađena.',
                        );
                      }

                      return ReservationDetailsScreen(
                        reservationId: ReservationId(id),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );

  /// Adresa prijave koja pamti kuda korisnik ide posle nje.
  static String loginLocation(String from) =>
      Uri(path: '/login', queryParameters: {'from': from}).toString();

  /// Da li adresa traži prijavu: rezervisanje i moje rezervacije.
  static bool requiresLogin(Uri uri) =>
      uri.path.startsWith('/reservations') ||
      RegExp(r'^/fields/[^/]+/reserve$').hasMatch(uri.path);

  /// Kuda router šalje korisnika, ili `null` kada ostaje gde jeste.
  static String? guard(AuthState auth, Uri uri) {
    final signedIn = auth is AuthAuthenticated;

    if (uri.path == '/login') {
      return signedIn ? _safeFrom(uri.queryParameters['from']) : null;
    }

    if (!signedIn && requiresLogin(uri)) return loginLocation(uri.toString());
    return null;
  }

  // Posle prijave se ide samo na adresu unutar aplikacije, nikad na
  // `/login` (petlja) ni na tuđu adresu.
  static String _safeFrom(String? from) {
    if (from == null || !from.startsWith('/') || from.startsWith('//')) {
      return '/';
    }
    return Uri.parse(from).path == '/login' ? '/' : from;
  }

  static FieldId? _fieldId(GoRouterState state) {
    final id = int.tryParse(state.pathParameters['fieldId'] ?? '');

    return id == null ? null : FieldId(id);
  }
}

/// Javlja routeru da se stanje prijave promenilo, da ponovo proveri zaštitu ruta.
class AuthRefresh extends ChangeNotifier {
  late final StreamSubscription<AuthState> _subscription;

  AuthRefresh(Stream<AuthState> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
