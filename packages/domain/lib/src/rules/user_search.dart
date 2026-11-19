import '../enums.dart';
import '../models/app_user.dart';
import 'reservation_search.dart';

/// Nalozi za spisak administratora: filter po ulozi, pretraga i redosled.
///
/// - Pretraga traži svaku reč u imenu, prezimenu ili email-u, bez razlike u
///   slovima i dijakriticima (`foldForSearch`).
/// - Redosled je po prezimenu, pa imenu, pa po `id`, da stranica ne menja
///   redosled pri svakom osvežavanju.
List<AppUser> filterUsers(
  Iterable<AppUser> users, {
  UserRole? role,
  String search = '',
}) {
  final words = [
    for (final word in foldForSearch(search).split(RegExp(r'\s+')))
      if (word.isNotEmpty) word,
  ];

  bool matches(AppUser user) {
    if (role != null && user.role != role) return false;
    if (words.isEmpty) return true;

    final haystack = foldForSearch(
      '${user.firstName} ${user.lastName} ${user.email}',
    );
    return words.every(haystack.contains);
  }

  return users.where(matches).toList()..sort((a, b) {
    final byLast = foldForSearch(a.lastName).compareTo(foldForSearch(b.lastName));
    if (byLast != 0) return byLast;
    final byFirst = foldForSearch(a.firstName).compareTo(foldForSearch(b.firstName));
    return byFirst != 0 ? byFirst : a.id.value.compareTo(b.id.value);
  });
}
