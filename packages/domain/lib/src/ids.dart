
// Jedinstveni identifikatori domenskih entiteta.
//
// Tipizirani ID-jevi sprečavaju da slučajno prosledimo,
// na primer, UserId tamo gde se očekuje FieldId.

extension type const UserId(int value) {}

extension type const FieldId(int value) {}

extension type const ReservationId(int value) {}

extension type const ReviewId(int value) {}
