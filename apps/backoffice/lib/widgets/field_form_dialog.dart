import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../text/labels.dart';

String fieldDataErrorLabel(FieldDataError error) => switch (error) {
  FieldDataError.emptyName => 'Unesite naziv terena.',
  FieldDataError.emptyAddress => 'Unesite adresu.',
  FieldDataError.emptyCity => 'Unesite grad.',
  FieldDataError.invalidPrice => 'Cena mora biti od 0 do $maxPricePerHour din.',
  FieldDataError.invalidPhone => 'Unesite ispravan broj telefona.',
};

Future<FieldDraft?> showFieldFormDialog(BuildContext context, {SportsField? field}) =>
    showDialog<FieldDraft>(context: context, builder: (_) => _FieldFormDialog(field: field));

class _FieldFormDialog extends StatefulWidget {
  final SportsField? field;

  const _FieldFormDialog({this.field});

  @override
  State<_FieldFormDialog> createState() => _FieldFormDialogState();
}

class _FieldFormDialogState extends State<_FieldFormDialog> {
  late final _name = TextEditingController(text: widget.field?.name);
  late final _description = TextEditingController(text: widget.field?.description);
  late final _address = TextEditingController(text: widget.field?.address);
  late final _city = TextEditingController(text: widget.field?.city);
  late final _price = TextEditingController(text: widget.field?.pricePerHour.toString());
  late final _phone = TextEditingController(text: widget.field?.contactPhone);
  late SportType _sport = widget.field?.sport ?? SportType.football;
  late ConfirmationMode _mode = widget.field?.confirmationMode ?? ConfirmationMode.manual;
  late bool _active = widget.field?.isActive ?? true;
  Set<FieldDataError> _errors = const {};

  @override
  void dispose() {
    for (final controller in [_name, _description, _address, _city, _price, _phone]) {
      controller.dispose();
    }
    super.dispose();
  }

  FieldDraft get _draft => FieldDraft(
    name: _name.text,
    description: _description.text,
    sport: _sport,
    address: _address.text,
    city: _city.text,
    pricePerHour: int.tryParse(_price.text.trim()) ?? -1,
    contactPhone: _phone.text,
    confirmationMode: _mode,
    isActive: _active,
  );

  void _submit() {
    final draft = _draft;
    setState(() => _errors = draft.errors);
    if (_errors.isEmpty) Navigator.of(context).pop(draft);
  }

  String? _error(FieldDataError error) => _errors.contains(error) ? fieldDataErrorLabel(error) : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.field == null ? 'Novi teren' : 'Izmena terena'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(labelText: 'Naziv', errorText: _error(FieldDataError.emptyName)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<SportType>(
                initialValue: _sport,
                decoration: const InputDecoration(labelText: 'Sport'),
                items: [
                  for (final sport in SportType.values) DropdownMenuItem(value: sport, child: Text(sportLabel(sport))),
                ],
                onChanged: (value) => setState(() => _sport = value ?? _sport),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Opis'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _address,
                decoration: InputDecoration(labelText: 'Adresa', errorText: _error(FieldDataError.emptyAddress)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _city,
                decoration: InputDecoration(labelText: 'Grad', errorText: _error(FieldDataError.emptyCity)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Cena po satu (din)',
                  errorText: _error(FieldDataError.invalidPrice),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: 'Kontakt telefon', errorText: _error(FieldDataError.invalidPhone)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ConfirmationMode>(
                initialValue: _mode,
                decoration: const InputDecoration(labelText: 'Potvrđivanje rezervacija'),
                items: const [
                  DropdownMenuItem(value: ConfirmationMode.manual, child: Text('Ručno (vlasnik potvrđuje)')),
                  DropdownMenuItem(value: ConfirmationMode.automatic, child: Text('Automatski')),
                ],
                onChanged: (value) => setState(() => _mode = value ?? _mode),
              ),
              if (widget.field != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktivan'),
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Odustani')),
        FilledButton(onPressed: _submit, child: const Text('Sačuvaj')),
      ],
    );
  }
}
