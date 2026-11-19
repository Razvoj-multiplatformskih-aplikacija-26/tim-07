import 'package:bloc/bloc.dart';
import 'package:contract/contract.dart';
import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';
import 'package:messages/messages.dart';

// --- događaji -------------------------------------------------------------

sealed class UsersEvent extends Equatable {
  const UsersEvent();

  @override
  List<Object?> get props => [];
}

/// Učitaj sve naloge. Šalje se na početku i za „Pokušaj ponovo“.
final class UsersStarted extends UsersEvent {
  const UsersStarted();
}

/// Ponovo učitaj naloge, a pretraga i uloga ostaju.
final class UsersRefreshed extends UsersEvent {
  const UsersRefreshed();
}

final class UsersSearchChanged extends UsersEvent {
  final String text;

  const UsersSearchChanged(this.text);

  @override
  List<Object?> get props => [text];
}

/// `null` znači sve uloge.
final class UsersRoleChanged extends UsersEvent {
  final UserRole? role;

  const UsersRoleChanged(this.role);

  @override
  List<Object?> get props => [role];
}

/// Administrator deaktivira ([active] je `false`) ili ponovo aktivira nalog.
final class UserActiveChangeRequested extends UsersEvent {
  final AppUser user;
  final bool active;

  const UserActiveChangeRequested(this.user, {required this.active});

  @override
  List<Object?> get props => [user.id, active];
}

// --- stanja ---------------------------------------------------------------

sealed class UsersState extends Equatable {
  const UsersState();

  @override
  List<Object?> get props => [];
}

final class UsersLoading extends UsersState {
  const UsersLoading();
}

final class UsersError extends UsersState {
  /// Poruka za korisnika (nikad tehnički tekst).
  final String message;

  const UsersError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Pregled naloga nije za ovu ulogu; podaci se i ne traže od servera.
final class UsersForbidden extends UsersState {
  const UsersForbidden();
}

final class UsersLoaded extends UsersState {
  /// Svi nalozi, po prezimenu; pretraga i uloga se primenjuju na [visible].
  final List<AppUser> all;

  final UserRole? role;
  final String search;

  /// Nalog čija se izmena upravo šalje, ili `null`.
  final UserId? busy;

  /// Poruka o poslednjoj radnji koja nije uspela, ili `null`.
  final String? message;

  UsersLoaded({
    required List<AppUser> all,
    this.role,
    this.search = '',
    this.busy,
    this.message,
  }) : all = List.unmodifiable(all);

  /// Nalozi koji ispunjavaju ulogu i pretragu, istim pravilom kao u domenu.
  List<AppUser> get visible => filterUsers(all, role: role, search: search);

  /// Da li pretraga ili uloga sužavaju spisak.
  bool get hasFilters => role != null || search.trim().isNotEmpty;

  UsersLoaded copyWith({
    List<AppUser>? all,
    UserRole? role,
    bool clearRole = false,
    String? search,
    UserId? busy,
    bool clearBusy = false,
    String? message,
    bool clearMessage = false,
  }) => UsersLoaded(
    all: all ?? this.all,
    role: clearRole ? null : (role ?? this.role),
    search: search ?? this.search,
    busy: clearBusy ? null : (busy ?? this.busy),
    message: clearMessage ? null : (message ?? this.message),
  );

  @override
  List<Object?> get props => [
    [for (final u in all) (u.id, u.isActive, u.role)],
    role,
    search,
    busy,
    message,
  ];
}

// --- Bloc -----------------------------------------------------------------

/// Stranica „Korisnici“ za administratora: spisak naloga, pretraga, uloga i
/// deaktivacija.
///
/// Prava su u domenu (`canManageUsers`, `canDeactivateUser`) i proverava ih i
/// server; Bloc ih proverava da ne bi uopšte tražio tuđe podatke.
final class UsersBloc extends Bloc<UsersEvent, UsersState> {
  final UserAdministrationRepository users;
  final AppUser viewer;

  static const _forbidden = ErrorDto(code: ErrorCodes.forbidden);

  // Raste sa svakim učitavanjem: odgovor starijeg zahteva se odbacuje.
  var _request = 0;

  UsersBloc({required this.users, required this.viewer})
    : super(
        canManageUsers(viewer) ? const UsersLoading() : const UsersForbidden(),
      ) {
    on<UsersStarted>(_onStarted);
    on<UsersRefreshed>(_onRefreshed);
    on<UsersSearchChanged>(_onSearchChanged);
    on<UsersRoleChanged>(_onRoleChanged);
    on<UserActiveChangeRequested>(_onActiveChangeRequested);
  }

  Future<void> _onStarted(UsersStarted event, Emitter<UsersState> emit) async {
    if (!canManageUsers(viewer)) return;

    final request = ++_request;
    final previous = state;
    emit(const UsersLoading());

    try {
      final all = await users.getUsers();
      if (request != _request) return;

      emit(
        UsersLoaded(
          all: filterUsers(all),
          role: previous is UsersLoaded ? previous.role : null,
          search: previous is UsersLoaded ? previous.search : '',
        ),
      );
    } catch (error) {
      if (request != _request) return;
      emit(UsersError(describeError(error)));
    }
  }

  Future<void> _onRefreshed(
    UsersRefreshed event,
    Emitter<UsersState> emit,
  ) async {
    final current = state;
    if (current is! UsersLoaded) return _onStarted(const UsersStarted(), emit);

    final request = ++_request;
    try {
      final all = await users.getUsers();
      if (request != _request) return;
      emit(
        current.copyWith(
          all: filterUsers(all),
          clearBusy: true,
          clearMessage: true,
        ),
      );
    } catch (error) {
      if (request != _request) return;
      emit(current.copyWith(clearBusy: true, message: describeError(error)));
    }
  }

  void _onSearchChanged(UsersSearchChanged event, Emitter<UsersState> emit) {
    final current = state;
    if (current is UsersLoaded && current.search != event.text) {
      emit(current.copyWith(search: event.text));
    }
  }

  void _onRoleChanged(UsersRoleChanged event, Emitter<UsersState> emit) {
    final current = state;
    if (current is UsersLoaded && current.role != event.role) {
      emit(
        event.role == null
            ? current.copyWith(clearRole: true)
            : current.copyWith(role: event.role),
      );
    }
  }

  Future<void> _onActiveChangeRequested(
    UserActiveChangeRequested event,
    Emitter<UsersState> emit,
  ) async {
    final current = state;
    if (current is! UsersLoaded || current.busy != null) return;

    if (!canDeactivateUser(viewer, event.user)) {
      emit(current.copyWith(message: errorMessage(_forbidden)));
      return;
    }

    emit(current.copyWith(busy: event.user.id, clearMessage: true));

    try {
      final changed = await users.setUserActive(
        event.user.id,
        active: event.active,
      );
      emit(
        current.copyWith(
          all: [
            for (final user in current.all)
              user.id == changed.id ? changed : user,
          ],
          clearBusy: true,
        ),
      );
    } catch (error) {
      // Odbijanje najčešće znači da se nešto promenilo na serveru: spisak se
      // ponovo učitava, a razlog ostaje.
      final message = describeError(error);
      emit(current.copyWith(clearBusy: true, message: message));
      try {
        final all = await users.getUsers();
        emit(
          current.copyWith(
            all: filterUsers(all),
            clearBusy: true,
            message: message,
          ),
        );
      } catch (_) {
        // Spisak ostaje kakav je; poruka o izmeni je već prikazana.
      }
    }
  }
}
