enum FieldDataError { emptyName, emptyAddress, emptyCity, invalidPrice, invalidPhone }

const maxPricePerHour = 1000000;

final _phone = RegExp(r'^\+?[0-9 /-]{6,20}$');

Set<FieldDataError> validateFieldDetails({
  required String name,
  required String address,
  required String city,
  required int pricePerHour,
  required String contactPhone,
}) => {
  if (name.trim().isEmpty) FieldDataError.emptyName,
  if (address.trim().isEmpty) FieldDataError.emptyAddress,
  if (city.trim().isEmpty) FieldDataError.emptyCity,
  if (pricePerHour < 0 || pricePerHour > maxPricePerHour) FieldDataError.invalidPrice,
  if (!_phone.hasMatch(contactPhone.trim())) FieldDataError.invalidPhone,
};
