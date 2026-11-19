import 'package:contract/contract.dart';
import 'package:domain/domain.dart';
import 'package:mapping/mapping.dart';
import 'package:messages/messages.dart';

import 'api_client.dart';
import 'page.dart';
import 'paging.dart';

/// Rezervacije preko HTTP-a. Isti port kao lažni repozitorijum, pa Bloc i
/// ekrani ne znaju da li podaci dolaze sa servera ili iz memorije.
///
/// Šta koja uloga vidi određuje server iz tokena (odluka 4): isti
/// `GET /reservations` vraća različit skup korisniku, vlasniku i administratoru.
final class HttpReservationRepository
    implements ReservationRepository, ReservationSearchRepository {
  const HttpReservationRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Reservation>> getReservations() async {
    final dtos = await getAllDtos(
      _api,
      ApiPaths.reservations,
      fromJson: ReservationDto.fromJson,
    );
    return dtos.toDomainKnown();
  }

  /// Server već vraća samo ono što pozivalac sme da vidi, pa se ovde samo
  /// sužava na traženog korisnika (vlasnik dobija rezervacije više korisnika).
  @override
  Future<List<Reservation>> getReservationsByUser(UserId userId) async {
    final all = await getReservations();
    return [
      for (final reservation in all)
        if (reservation.userId == userId) reservation,
    ];
  }

  @override
  Future<List<Reservation>> getReservationsByField(FieldId fieldId) async {
    final dtos = await getAllDtos(
      _api,
      ApiPaths.reservations,
      query: {ApiQuery.fieldId: '${fieldId.value}'},
      fromJson: ReservationDto.fromJson,
    );
    return dtos.toDomainKnown();
  }

  /// Jedna strana, za tabelu u backoffice-u (broj strana i skok na stranu).
  Future<Page<Reservation>> getReservationsPage({
    FieldId? fieldId,
    ReservationStatus? status,
    int limit = ApiPaging.defaultLimit,
    int offset = 0,
  }) async {
    final page = await getPageDto(
      _api,
      ApiPaths.reservations,
      query: {
        if (fieldId != null) ApiQuery.fieldId: '${fieldId.value}',
        if (status != null) ApiQuery.status: reservationStatusToCode(status),
      },
      limit: limit,
      offset: offset,
      fromJson: ReservationDto.fromJson,
    );
    return Page(
      items: page.items.toDomainKnown(),
      total: page.total,
      limit: page.limit,
      offset: page.offset,
    );
  }

  /// Jedna strana tabele rezervacija: filteri, pretraga, sortiranje i strana
  /// računaju se na serveru (`searchReservations` u domenu), pa tabela traži
  /// samo ono što prikazuje. Dani idu kao `yyyy-MM-dd`.
  @override
  Future<PagedResult<Reservation>> searchReservations(
    ReservationQuery query,
  ) async {
    final from = query.fromDate;
    final to = query.toDate;
    final search = query.search.trim();

    final page = await getPageDto(
      _api,
      ApiPaths.reservations,
      query: {
        if (query.fieldId != null) ApiQuery.fieldId: '${query.fieldId!.value}',
        if (query.status != null)
          ApiQuery.status: reservationStatusToCode(query.status!),
        if (from != null)
          ApiQuery.from: dateToJson(from.year, from.month, from.day),
        if (to != null) ApiQuery.to: dateToJson(to.year, to.month, to.day),
        if (search.isNotEmpty) ApiQuery.search: search,
        ApiQuery.sort: reservationSortKeyToCode(query.sortKey),
        ApiQuery.order: query.ascending
            ? SortOrderCodes.ascending
            : SortOrderCodes.descending,
      },
      limit: query.limit,
      offset: query.offset,
      fromJson: ReservationDto.fromJson,
    );

    return PagedResult(
      items: page.items.toDomainKnown(),
      total: page.total,
      limit: page.limit,
      offset: page.offset,
    );
  }

  @override
  Future<Reservation?> getReservationById(ReservationId id) async {
    try {
      final json = await _api.get(ApiPaths.reservation(id.value));
      final reservation = readBody(
        json,
        (o) => ReservationDto.fromJson(o).toDomain(),
      );
      return reservation;
    } on ServerRejectedException catch (error) {
      // Tuđa rezervacija stiže kao 404, isto kao nepostojeća (odluka 4).
      if (isNotFound(error)) return null;
      rethrow;
    }
  }

  /// `userId` se ne šalje: server zna ko poziva samo iz tokena (odluka 11).
  @override
  Future<Reservation> createReservation({
    required FieldId fieldId,
    required UserId userId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final request = CreateReservationRequestDto(
      fieldId: fieldId.value,
      startTime: startTime,
      endTime: endTime,
    );
    final json = await _api.post(ApiPaths.reservations, body: request.toJson());
    return readBody(json, (o) => ReservationDto.fromJson(o).toDomain());
  }

  /// Potvrda i otkazivanje idu na svoje adrese. Odbijanje vlasnika je
  /// otkazivanje rezervacije na čekanju, pa ide na `/cancel` (za razlog:
  /// [rejectReservation]). `completed` je automatsko stanje i ne menja se
  /// sa klijenta.
  @override
  Future<Reservation> updateReservationStatus({
    required ReservationId reservationId,
    required ReservationStatus status,
  }) async {
    final id = reservationId.value;
    final json = switch (status) {
      ReservationStatus.confirmed => await _api.post(
        ApiPaths.confirmReservation(id),
      ),
      ReservationStatus.cancelled => await _api.post(
        ApiPaths.cancelReservation(id),
      ),
      ReservationStatus.pending ||
      ReservationStatus.completed => throw const ReservationRuleViolation(
        InvalidReservationStatus(),
      ),
    };
    return readBody(json, (o) => ReservationDto.fromJson(o).toDomain());
  }

  /// Vlasnik odbija zahtev za rezervaciju, sa razlogom koji vidi korisnik.
  Future<Reservation> rejectReservation(
    ReservationId reservationId, {
    String? reason,
  }) async {
    final json = await _api.post(
      ApiPaths.rejectReservation(reservationId.value),
      body: ReservationReasonRequestDto(reason: reason).toJson(),
    );
    return readBody(json, (o) => ReservationDto.fromJson(o).toDomain());
  }

  @override
  Future<Reservation> checkIn(ReservationId reservationId) async {
    final json = await _api.post(
      ApiPaths.checkInReservation(reservationId.value),
    );
    return readBody(json, (o) => ReservationDto.fromJson(o).toDomain());
  }

  @override
  Future<Reservation> cancelReservation(ReservationId reservationId) async {
    final json = await _api.post(
      ApiPaths.cancelReservation(reservationId.value),
    );
    return readBody(json, (o) => ReservationDto.fromJson(o).toDomain());
  }
}
