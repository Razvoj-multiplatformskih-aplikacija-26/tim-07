import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/fields_screen.dart';
import 'main_navigation.dart';
import '../screens/reservations_screen.dart';

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
