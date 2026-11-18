import 'package:blocs/blocs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../navigation/app_router.dart';

/// Dugme u traci aplikacije: prijava kada niko nije prijavljen, a kada jeste,
/// meni sa imenom korisnika i odjavom.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state.user;

        if (user != null) {
          return PopupMenuButton<String>(
            tooltip: 'Nalog',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (_) {
              // Posle odjave se ne ostaje na zaštićenom ekranu.
              context.go('/');
              context.read<AuthBloc>().add(const AuthLogoutRequested());
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                enabled: false,
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(user.fullName),
                  subtitle: Text(user.email),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Odjavi se'),
                ),
              ),
            ],
          );
        }

        if (state is AuthUnknown) return const SizedBox.shrink();

        return IconButton(
          tooltip: 'Prijavi se',
          icon: const Icon(Icons.login),
          onPressed: () => context.go(
            AppRouter.loginLocation(GoRouterState.of(context).uri.toString()),
          ),
        );
      },
    );
  }
}
