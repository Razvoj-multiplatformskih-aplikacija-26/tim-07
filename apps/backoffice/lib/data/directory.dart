import 'package:domain/domain.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'backoffice_demo_data.dart';

final class BackofficeDirectory {
  const BackofficeDirectory({this.fields = const {}, this.users = const {}});

  BackofficeDirectory.demo()
    : fields = {for (final field in BackofficeDemoData.fields) field.id: field},
      users = {for (final user in BackofficeDemoData.users) user.id: user};

  final Map<FieldId, SportsField> fields;
  final Map<UserId, AppUser> users;

  SportsField? field(FieldId id) => fields[id];

  AppUser? user(UserId id) => users[id];

  String fieldName(FieldId id) => fields[id]?.name ?? 'Teren #${id.value}';

  String userName(UserId id) => users[id]?.fullName ?? 'Korisnik #${id.value}';
}

final class DirectoryCubit extends Cubit<BackofficeDirectory> {
  DirectoryCubit({this.fieldRepository, BackofficeDirectory? initial})
    : super(initial ?? const BackofficeDirectory());

  final SportsFieldRepository? fieldRepository;

  Future<void> load() async {
    final repository = fieldRepository;
    if (repository == null) return;
    try {
      final fields = await repository.getFields();
      emit(BackofficeDirectory(fields: {for (final field in fields) field.id: field}, users: state.users));
    } on Object {
      return;
    }
  }

  void clear() => emit(const BackofficeDirectory());
}
