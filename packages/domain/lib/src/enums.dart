
/// Uloge korisnika u aplikaciji.
enum UserRole {
  user,
  owner,
  admin,
}

/// Vrste sportova koje teren podržava.
enum SportType {
  football,
  basketball,
  tennis,
  padel,
  volleyball,
  swimming,
  futsal,
  other,
}

/// Način potvrđivanja rezervacija koji vlasnik bira za teren.
enum ConfirmationMode {
  automatic,
  manual,
}

/// Četiri osnovna stanja rezervacije.
enum ReservationStatus {
  pending,
  confirmed,
  completed,
  cancelled,
}

/// Evidencija plaćanja bez online naplate.
enum PaymentStatus {
  unpaid,
  paid,
}

/// Dani u nedelji za definisanje radnog vremena.
enum WeekDay {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday,
}
