import 'package:contract/contract.dart';
import 'package:domain/domain.dart';
import 'package:mapping/mapping.dart';

import 'api_client.dart';
import 'paging.dart';

/// Nalozi za administratora preko HTTP-a.
///
/// Server vraća spisak i dozvoljava izmenu samo administratoru (odluka 4);
/// ostalima odgovara sa 403, što klijent prikazuje kao „nemate pravo“.
final class HttpUserRepository implements UserAdministrationRepository {
  const HttpUserRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<AppUser>> getUsers({UserRole? role}) async {
    final dtos = await getAllDtos(
      _api,
      ApiPaths.users,
      query: {if (role != null) ApiQuery.role: roleToCode(role)},
      fromJson: UserDto.fromJson,
    );
    return [for (final dto in dtos) dto.toDomain()];
  }

  @override
  Future<AppUser> setUserActive(UserId id, {required bool active}) async {
    final json = await _api.patch(
      ApiPaths.user(id.value),
      body: SetUserActiveRequestDto(isActive: active).toJson(),
    );
    return readBody(json, (o) => UserDto.fromJson(o).toDomain());
  }
}
