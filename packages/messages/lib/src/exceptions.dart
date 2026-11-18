import 'package:contract/contract.dart';

/// Server je odbio poziv i poslao kod i podatke pravila (odluka 13).
///
/// Ne nosi tekst za korisnika: poruku pravi klijent iz koda
/// (`describeError`), istom funkcijom kao kada pravilo proveri lokalno.
/// Baca ga HTTP repozitorijum (T43), hvata Bloc.
final class ServerRejectedException implements Exception {
  final ErrorDto error;

  const ServerRejectedException(this.error);

  @override
  String toString() => 'ServerRejectedException(${error.code})';
}

/// Nema mreže, server ne radi ili ne odgovara na vreme.
final class ServerUnreachableException implements Exception {
  const ServerUnreachableException();

  @override
  String toString() => 'ServerUnreachableException';
}
