import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/fields_screen.dart';
import 'main_navigation.dart';
import '../screens/reservations_screen.dart';
import '../screens/field_details_screen.dart';
import '../screens/reservation_form_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigation(
            navigationShell: navigationShell,
          );
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
                    path: 'details',
                    builder: (context, state) {
                      final field = state.extra as ({
                      String name,
                      String location,
                      String sport,
                      int price,
                      });

                      return FieldDetailsScreen(
                        name: field.name,
                        location: field.location,
                        sport: field.sport,
                        pricePerHour: field.price,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'reserve',
                    builder: (context, state) {
                      final reservation = state.extra as ({
                      String fieldName,
                      DateTime date,
                      String timeSlot,
                      int price,
                      });

                      return ReservationFormScreen(
                        fieldName: reservation.fieldName,
                        date: reservation.date,
                        timeSlot: reservation.timeSlot,
                        price: reservation.price,
                      );
                    },
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
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
