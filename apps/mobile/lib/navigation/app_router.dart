import 'package:domain/domain.dart';
import 'package:go_router/go_router.dart';

import '../data/mobile_demo_data.dart';
import '../screens/field_details_screen.dart';
import '../screens/fields_screen.dart';
import '../screens/home_screen.dart';
import '../screens/message_screen.dart';
import '../screens/reservation_details_screen.dart';
import '../screens/reservation_form_screen.dart';
import '../screens/reservations_screen.dart';
import 'main_navigation.dart';

/// Adrese ekrana:
///   /                                  početna
///   /fields                            katalog terena
///   /fields/:fieldId                   detalj terena
///   /fields/:fieldId/reserve           forma (?date=...&start=HH:mm&end=HH:mm)
///   /reservations                      moje rezervacije
///   /reservations/:reservationId       detalj rezervacije
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
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
                      final field = _field(state);

                      if (field == null) {
                        return const MessageScreen(
                          title: 'Detalji terena',
                          message: 'Teren nije pronađen.',
                        );
                      }

                      return FieldDetailsScreen(field: field);
                    },
                    routes: [
                      GoRoute(
                        path: 'reserve',
                        builder: (context, state) {
                          final field = _field(state);
                          final query = state.uri.queryParameters;
                          final date = DateTime.tryParse(query['date'] ?? '');
                          final start = query['start'];
                          final end = query['end'];

                          if (field == null ||
                              date == null ||
                              start == null ||
                              end == null) {
                            return const MessageScreen(
                              title: 'Nova rezervacija',
                              message: 'Termin nije pronađen.',
                            );
                          }

                          return ReservationFormScreen(
                            field: field,
                            date: date,
                            initialStart: start,
                            initialEnd: end,
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

  static SportsField? _field(GoRouterState state) {
    final id = int.tryParse(state.pathParameters['fieldId'] ?? '');

    return id == null ? null : MobileDemoData.fieldById(FieldId(id));
  }
}
