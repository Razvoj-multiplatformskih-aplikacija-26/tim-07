import 'package:server/server.dart';

Future<void> insertFixtures(SqlExecutor db) async {
  await db.query('''
    INSERT INTO users (id, first_name, last_name, email, phone_number, date_of_birth, role, password_hash)
    VALUES (1, 'Ana', 'Anić', 'ana@example.com', '0601', '2000-01-01', 'user', 'x'),
           (2, 'Marko', 'Marić', 'marko@example.com', '0602', '1999-05-05', 'user', 'x'),
           (3, 'Vlada', 'Vlasnik', 'vlada@example.com', '0603', '1985-03-03', 'owner', 'x'),
           (4, 'Admin', 'Adminović', 'admin@example.com', '0604', '1980-01-01', 'admin', 'x')''');

  await db.query('''
    INSERT INTO sports_fields (id, owner_id, name, description, sport, address, city,
                               price_per_hour, contact_phone, confirmation_mode, approval_status)
    VALUES (1, 3, 'Arena', 'Mali fudbal', 'football', 'Ulica 1', 'Beograd', 3000, '060', 'manual', 'approved'),
           (2, 3, 'Tenis', 'Šljaka', 'tennis', 'Ulica 2', 'Novi Sad', 2000, '061', 'automatic', 'approved'),
           (3, 3, 'Novi', 'Čeka odobrenje', 'padel', 'Ulica 3', 'Beograd', 2500, '062', 'manual', 'pending')''');

  for (final fieldId in [1, 2, 3]) {
    for (final day in ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']) {
      await db.query(
        "INSERT INTO field_schedules (field_id, day_of_week, opens_at, closes_at) VALUES (?, ?, '08:00:00', '23:00:00')",
        [fieldId, day],
      );
    }
  }
}
