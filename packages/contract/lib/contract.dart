// Terenzo - HTTP ugovor između klijenata i servera.
//
// Zahtevi, odgovori, kodovi grešaka i adrese u jednom paketu koji koriste
// mobilna aplikacija, backoffice i server. Paket ne uvozi `domain`, Flutter ni
// `dart:io`, pa radi svuda gde radi Dart. Prevod u domen je u paketu `mapping`.

export 'src/codes.dart';
export 'src/error_dto.dart';
export 'src/field_dto.dart';
export 'src/json.dart' show ClockTime, dateToJson, instantToJson;
export 'src/page_dto.dart';
export 'src/paths.dart';
export 'src/reservation_dto.dart';
export 'src/schedule_dto.dart';
export 'src/stats_dto.dart';
export 'src/user_dto.dart';
