import 'package:domain/domain.dart';

/// Nalozi u memoriji, za demo i testove stranice „Korisnici“.
final class FakeUserAdministrationRepository
    implements UserAdministrationRepository {
  final List<AppUser> _users;

  FakeUserAdministrationRepository({Iterable<AppUser> users = const []})
    : _users = List.of(users);

  @override
  Future<List<AppUser>> getUsers({UserRole? role}) async => [
    for (final user in _users)
      if (role == null || user.role == role) user,
  ];

  @override
  Future<AppUser> setUserActive(UserId id, {required bool active}) async {
    final index = _users.indexWhere((user) => user.id == id);
    if (index < 0) throw EntityNotFound('user', id.value);

    return _users[index] = _users[index].copyWith(isActive: active);
  }
}
