// Pomoćne funkcije za čitanje JSON-a u DTO-ovima.
//
// Svaka funkcija baca `FormatException` kada polje nedostaje ili je pogrešnog
// tipa, a nepoznata polja se ignorišu. Zato stariji klijent čita odgovor novijeg
// servera (server doda polje, klijent ga preskoči), a loš zahtev ne obara server.

Map<String, Object?> jsonObject(Object? value) => switch (value) {
  final Map<String, Object?> object => object,
  _ => throw FormatException('Expected a JSON object', value),
};

List<Map<String, Object?>> jsonObjects(Map<String, Object?> json, String key) =>
    switch (json[key]) {
      final List<Object?> list => [for (final item in list) jsonObject(item)],
      _ => throw FormatException('Expected "$key" to be a list', json),
    };

List<String> jsonStrings(Map<String, Object?> json, String key) =>
    switch (json[key]) {
      final List<Object?> list => [
        for (final item in list)
          switch (item) {
            final String value => value,
            _ => throw FormatException('Expected "$key" to hold strings', json),
          },
      ],
      _ => throw FormatException('Expected "$key" to be a list', json),
    };

String jsonString(Map<String, Object?> json, String key) => switch (json[key]) {
  final String value => value,
  _ => throw FormatException('Expected "$key" to be a string', json),
};

String? jsonOptionalString(Map<String, Object?> json, String key) =>
    switch (json[key]) {
      null => null,
      final String value => value,
      _ => throw FormatException('Expected "$key" to be a string', json),
    };

int jsonInt(Map<String, Object?> json, String key) => switch (json[key]) {
  final int value => value,
  _ => throw FormatException('Expected "$key" to be an integer', json),
};

int? jsonOptionalInt(Map<String, Object?> json, String key) =>
    switch (json[key]) {
      null => null,
      final int value => value,
      _ => throw FormatException('Expected "$key" to be an integer', json),
    };

bool jsonBool(Map<String, Object?> json, String key) => switch (json[key]) {
  final bool value => value,
  _ => throw FormatException('Expected "$key" to be true or false', json),
};

/// Trenutak na mreži: ISO-8601 u UTC, uvek sa `Z` na kraju.
///
/// Trenutak bez zone se odbija jer se ne zna u kojoj zoni je napisan.
DateTime jsonInstant(Map<String, Object?> json, String key) =>
    _instant(jsonString(json, key), key);

DateTime? jsonOptionalInstant(Map<String, Object?> json, String key) =>
    switch (jsonOptionalString(json, key)) {
      null => null,
      final String value => _instant(value, key),
    };

DateTime _instant(String value, String key) {
  final parsed = DateTime.parse(value);
  if (!parsed.isUtc) {
    throw FormatException(
      'Expected "$key" with a time zone, like 2026-11-12T17:00:00.000Z',
      value,
    );
  }
  return parsed;
}

String instantToJson(DateTime instant) => instant.toUtc().toIso8601String();

/// Dnevno vreme `HH:mm` (radno vreme terena, lokalno vreme objekta).
final class ClockTime {
  final int hour;
  final int minute;

  const ClockTime(this.hour, this.minute);

  factory ClockTime.parse(String value) {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
    final hour = int.tryParse(match?.group(1) ?? '');
    final minute = int.tryParse(match?.group(2) ?? '');
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      throw FormatException('Expected a time like 08:30', value);
    }
    return ClockTime(hour, minute);
  }

  String toJson() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => toJson();
}

ClockTime jsonClockTime(Map<String, Object?> json, String key) =>
    ClockTime.parse(jsonString(json, key));

/// Datum bez vremena `YYYY-MM-DD` (slobodni termini za izabrani dan).
String dateToJson(int year, int month, int day) =>
    '${year.toString().padLeft(4, '0')}-'
    '${month.toString().padLeft(2, '0')}-'
    '${day.toString().padLeft(2, '0')}';
