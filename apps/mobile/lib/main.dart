import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'data/mobile_demo_data.dart';
import 'data/mobile_repository.dart';
import 'navigation/app_router.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(MyApp(repository: createMobileRepository()));
}

class MyApp extends StatelessWidget {
  final ReservationRepository repository;

  const MyApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<ReservationRepository>.value(
      value: repository,
      child: BlocProvider(
        create: (_) => ReservationBloc(repository: repository)
          ..add(const UserReservationsRequested(MobileDemoData.currentUserId)),
        child: MaterialApp.router(
          title: 'Rezervacija terena',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          routerConfig: AppRouter.router,
        ),
      ),
    );
  }
}
