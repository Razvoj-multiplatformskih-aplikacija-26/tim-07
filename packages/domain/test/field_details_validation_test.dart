import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  Set<FieldDataError> validate({
    String name = 'Arena',
    String address = 'Ulica 1',
    String city = 'Beograd',
    int price = 3000,
    String phone = '060 123 4567',
  }) =>
      validateFieldDetails(name: name, address: address, city: city, pricePerHour: price, contactPhone: phone);

  test('ispravni podaci nemaju greške', () {
    expect(validate(), isEmpty);
    expect(validate(phone: '+381601234567', price: 0), isEmpty);
  });

  test('prazna polja i razmaci', () {
    expect(validate(name: '  ', address: '', city: ''), {
      FieldDataError.emptyName,
      FieldDataError.emptyAddress,
      FieldDataError.emptyCity,
    });
  });

  test('cena mora biti od 0 do gornje granice', () {
    expect(validate(price: -1), {FieldDataError.invalidPrice});
    expect(validate(price: maxPricePerHour + 1), {FieldDataError.invalidPrice});
  });

  test('telefon ima samo cifre, razmake, crtice i vodeći plus', () {
    expect(validate(phone: 'abc'), {FieldDataError.invalidPhone});
    expect(validate(phone: '123'), {FieldDataError.invalidPhone});
  });
}
