
import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';

import 'reservation_event.dart';
import 'reservation_state.dart';

/// Upravlja rezervacijama koristeci repository port.
///
/// Ne zna da li podaci dolaze iz memorije, baze ili API-ja.
final class ReservationBloc
    extends Bloc<ReservationEvent, ReservationState> {
  // Ugovor iz domena: Bloc ne zna koja konkretna klasa stoji iza njega.
  final ReservationRepository repository;
  // Zapamceni "recept" poslednjeg ucitavanja, da se posle akcije osvezi isti pregled.
  Future<List<Reservation>> Function()? _lastQuery;

  // Prosledjuje pocetno stanje roditeljskom Bloc-u i registruje obradu dogadjaja.
  ReservationBloc({required this.repository})
      : super(const ReservationInitial()) {
    // Svaki on<> kaze: kad stigne ovaj tip dogadjaja, pozovi ovu funkciju.
    on<ReservationsRequested>(_onReservationsRequested);
    on<UserReservationsRequested>(_onUserReservationsRequested);
    on<FieldReservationsRequested>(_onFieldReservationsRequested);
    on<ReservationCreateRequested>(_onReservationCreateRequested);
    on<ReservationConfirmRequested>(_onReservationConfirmRequested);
    on<ReservationCancelRequested>(_onReservationCancelRequested);
    on<ReservationCheckInRequested>(_onReservationCheckInRequested);
  }

  // Zajednicko ucitavanje: Loading, pa Loaded ili Empty, a greska postaje Error.
  Future<void> _loadReservations(
      Emitter<ReservationState> emit,
      // Funkcija koja zna sta tacno da trazi od repozitorijuma (sve, korisnik, teren).
      Future<List<Reservation>> Function() fetch,
      ) async {
    // Pamti upit da ga _performAction moze ponoviti posle izmene.
    _lastQuery = fetch;
    // Ekran odmah prikaze spinner dok se ceka odgovor.
    emit(const ReservationLoading());

    try {
      // Pokrece upit i ceka rezultat; ako baci gresku, izvrsavanje ide u catch.
      final reservations = await fetch();

      // Prazna lista je poseban prikaz (Empty), a ne Loaded sa nula elemenata.
      if (reservations.isEmpty) {
        emit(const ReservationEmpty());
      } else {
        emit(ReservationLoaded(reservations));
      }
    } catch (error) {
      // Svaka greska postaje stanje Error, pa aplikacija ne pada.
      emit(ReservationError(error.toString()));
    }
  }

  // Dogadjaj: ucitaj sve rezervacije.
  Future<void> _onReservationsRequested(
      ReservationsRequested event,
      Emitter<ReservationState> emit,
      ) async {
    await _loadReservations(
      emit,
      // Prosledjuje se sama metoda (bez zagrada), jer vec nema parametre.
      repository.getReservations,
    );
  }

  // Dogadjaj: ucitaj rezervacije jednog korisnika (mobilna aplikacija).
  Future<void> _onUserReservationsRequested(
      UserReservationsRequested event,
      Emitter<ReservationState> emit,
      ) async {
    await _loadReservations(
      emit,
          // Lambda nosi userId u sebi, pa isti upit moze da se ponovi i kasnije.
          () => repository.getReservationsByUser(event.userId),
    );
  }

  // Dogadjaj: ucitaj rezervacije jednog terena (backoffice).
  Future<void> _onFieldReservationsRequested(
      FieldReservationsRequested event,
      Emitter<ReservationState> emit,
      ) async {
    await _loadReservations(
      emit,
          // Lambda nosi fieldId u sebi, isto kao kod korisnika.
          () => repository.getReservationsByField(event.fieldId),
    );
  }

  // Dogadjaj: napravi novu rezervaciju.
  Future<void> _onReservationCreateRequested(
      ReservationCreateRequested event,
      Emitter<ReservationState> emit,
      ) async {
    await _performAction(
      emit,
          // Pravila (preklapanje, radno vreme...) proverava repozitorijum, ne Bloc.
          () => repository.createReservation(
        fieldId: event.fieldId,
        userId: event.userId,
        startTime: event.startTime,
        endTime: event.endTime,
      ),
    );
  }

  // Dogadjaj: potvrdi rezervaciju (backoffice).
  Future<void> _onReservationConfirmRequested(
      ReservationConfirmRequested event,
      Emitter<ReservationState> emit,
      ) async {
    await _performAction(
      emit,
          // Dogadjaj znaci "potvrdi", zato je trazeni status uvek confirmed.
          () => repository.updateReservationStatus(
        reservationId: event.reservationId,
        status: ReservationStatus.confirmed,
      ),
    );
  }

  // Dogadjaj: otkazi rezervaciju (rok proverava repozitorijum preko domena).
  Future<void> _onReservationCancelRequested(
      ReservationCancelRequested event,
      Emitter<ReservationState> emit,
      ) async {
    await _performAction(
      emit,
          () => repository.cancelReservation(event.reservationId),
    );
  }

  // Dogadjaj: korisnik potvrdjuje dolazak (check-in).
  Future<void> _onReservationCheckInRequested(
      ReservationCheckInRequested event,
      Emitter<ReservationState> emit,
      ) async {
    await _performAction(
      emit,
          () => repository.checkIn(event.reservationId),
    );
  }

  // Zajednicka akcija koja menja podatke: Loading, izvrsi, ponovo ucitaj, prikazi rezultat.
  Future<void> _performAction(
      Emitter<ReservationState> emit,
      // Funkcija koja izvrsava jednu izmenu i vraca izmenjenu rezervaciju.
      Future<Reservation> Function() action,
      ) async {
    // Ekran prikaze spinner dok izmena traje.
    emit(const ReservationLoading());

    try {
      // Izvrsava izmenu; rezultat se odbacuje jer se podaci ionako ucitavaju ponovo.
      await action();

      // Ponavlja poslednji upit da korisnik vidi isti pregled kao pre izmene.
      final reload = _lastQuery ?? repository.getReservations;
      final reservations = await reload();

      if (reservations.isEmpty) {
        emit(const ReservationEmpty());
      } else {
        emit(ReservationLoaded(reservations));
      }
    } catch (error) {
      // Ako izmena ili ponovno ucitavanje pukne, ide Error i ucitavanje se preskace.
      emit(ReservationError(error.toString()));
    }
  }
}
