import '../enums.dart';
import '../ids.dart';
import '../models/app_user.dart';

abstract interface class UserRepository {
  Future<AppUser?> getUserById(UserId id);

  Future<AppUser?> getUserByEmail(String email);

  Future<List<AppUser>> getUsers({UserRole? role});
}
