import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Prijavljen korisnik, iz `AuthBloc`-a umesto iz demo podataka.
///
/// `null` kada niko nije prijavljen (npr. u trenutku isteka prijave, dok ruta
/// još vodi na prijavu): ekrani to moraju da izdrže.
extension CurrentUser on BuildContext {
  /// Za `build`: ekran se ponovo crta kada se korisnik promeni.
  AppUser? get watchUser =>
      select<AuthBloc, AppUser?>((bloc) => bloc.state.user);

  /// Za rukovaoce događaja i `initState`.
  AppUser? get readUser => read<AuthBloc>().state.user;
}
