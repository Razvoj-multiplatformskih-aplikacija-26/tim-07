import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../text/labels.dart';

/// Pregled svih naloga za administratora: pretraga, uloga i deaktivacija.
///
/// Stranica šalje događaje `UsersBloc`-u i crta njegovo stanje. Prava (ko sme da
/// vidi i menja naloge) su u domenu i proverava ih i server; vlasnik ni ne vidi
/// stavku u meniju.
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  /// Ispod ove širine se nalozi crtaju kao kartice, ne kao tabela.
  static const tableBreakpoint = 900.0;

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Nalozi su se možda promenili dok je bila druga stranica.
    context.read<UsersBloc>().add(const UsersRefreshed());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _change(AppUser user, {required bool active}) async {
    final bloc = context.read<UsersBloc>();

    if (!active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Deaktivirati nalog?'),
          content: Text(
            '${user.fullName} se više neće moći prijaviti, a postojeća '
            'prijava prestaje da važi. Nalog može ponovo da se aktivira.',
          ),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Odustani'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Deaktiviraj'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    bloc.add(UserActiveChangeRequested(user, active: active));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UsersBloc, UsersState>(
      // Polje pretrage se menja spolja samo kada se filteri poništavaju.
      listenWhen: (previous, current) =>
          previous is UsersLoaded &&
          current is UsersLoaded &&
          previous.search != current.search,
      listener: (context, state) {
        final search = (state as UsersLoaded).search;
        if (_search.text != search) _search.text = search;
      },
      builder: (context, state) => switch (state) {
        UsersLoading() => const _Notice(
          icon: CircularProgressIndicator(),
          title: 'Učitavanje naloga...',
        ),
        UsersForbidden() => const _Notice(
          icon: Icon(Icons.lock_outline, size: 48),
          title: 'Nemate pristup',
          message: 'Spisak naloga vidi samo administrator.',
        ),
        UsersError(:final message) => _Notice(
          icon: Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          title: 'Nalozi nisu učitani',
          message: message,
          action: FilledButton.icon(
            autofocus: true,
            onPressed: () =>
                context.read<UsersBloc>().add(const UsersStarted()),
            icon: const Icon(Icons.refresh),
            label: const Text('Pokušaj ponovo'),
          ),
        ),
        final UsersLoaded loaded => _Loaded(
          state: loaded,
          search: _search,
          onChange: _change,
        ),
      },
    );
  }
}

class _Loaded extends StatelessWidget {
  final UsersLoaded state;
  final TextEditingController search;
  final Future<void> Function(AppUser user, {required bool active}) onChange;

  const _Loaded({
    required this.state,
    required this.search,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<UsersBloc>();
    final visible = state.visible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: search,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Pretraga naloga',
                    hintText: 'Ime, prezime ili email',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: state.search.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Obriši pretragu',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              search.clear();
                              bloc.add(const UsersSearchChanged(''));
                            },
                          ),
                  ),
                  onChanged: (text) => bloc.add(UsersSearchChanged(text)),
                ),
              ),
              SizedBox(
                width: 200,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Uloga',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UserRole?>(
                      value: state.role,
                      isExpanded: true,
                      isDense: true,
                      items: [
                        const DropdownMenuItem<UserRole?>(
                          value: null,
                          child: Text('Sve uloge'),
                        ),
                        for (final role in UserRole.values)
                          DropdownMenuItem<UserRole?>(
                            value: role,
                            child: Text(roleLabel(role)),
                          ),
                      ],
                      onChanged: (role) => bloc.add(UsersRoleChanged(role)),
                    ),
                  ),
                ),
              ),
              if (state.hasFilters)
                TextButton.icon(
                  onPressed: () {
                    search.clear();
                    bloc
                      ..add(const UsersSearchChanged(''))
                      ..add(const UsersRoleChanged(null));
                  },
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Poništi filtere'),
                ),
              Semantics(
                liveRegion: true,
                child: Text(
                  state.hasFilters
                      ? 'Prikazano ${visible.length} od ${state.all.length}'
                      : 'Ukupno naloga: ${state.all.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        if (state.busy != null) const LinearProgressIndicator(),
        if (state.message case final message?)
          Semantics(
            liveRegion: true,
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: visible.isEmpty
              ? _Notice(
                  icon: const Icon(Icons.search_off, size: 48),
                  title: state.hasFilters
                      ? 'Nema naloga za izabrane filtere'
                      : 'Nema naloga',
                  message: state.hasFilters
                      ? 'Probajte drugačiju pretragu ili ulogu.'
                      : null,
                )
              : LayoutBuilder(
                  builder: (context, constraints) =>
                      constraints.maxWidth >= UsersPage.tableBreakpoint
                      ? _UsersTable(
                          state: state,
                          users: visible,
                          onChange: onChange,
                        )
                      : _UsersCards(
                          state: state,
                          users: visible,
                          onChange: onChange,
                        ),
                ),
        ),
      ],
    );
  }
}

class _StatusLabel extends StatelessWidget {
  final AppUser user;

  const _StatusLabel(this.user);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = user.isActive ? scheme.primary : scheme.error;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          user.isActive ? Icons.check_circle_outline : Icons.block,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          user.isActive ? 'Aktivan' : 'Deaktiviran',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Dugme „Deaktiviraj“ ili „Aktiviraj“; za svoj nalog je isključeno, sa
/// objašnjenjem.
class _ToggleButton extends StatelessWidget {
  final UsersLoaded state;
  final AppUser user;
  final Future<void> Function(AppUser user, {required bool active}) onChange;

  const _ToggleButton({
    required this.state,
    required this.user,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final viewer = context.read<AppUser>();
    final allowed = canDeactivateUser(viewer, user);
    final enabled = allowed && state.busy == null;

    final button = TextButton.icon(
      onPressed: enabled ? () => onChange(user, active: !user.isActive) : null,
      icon: Icon(
        user.isActive ? Icons.person_off_outlined : Icons.person_outline,
      ),
      label: Text(user.isActive ? 'Deaktiviraj' : 'Aktiviraj'),
    );

    return allowed
        ? button
        : Tooltip(message: 'Ne možete deaktivirati svoj nalog', child: button);
  }
}

class _UsersTable extends StatelessWidget {
  final UsersLoaded state;
  final List<AppUser> users;
  final Future<void> Function(AppUser user, {required bool active}) onChange;

  const _UsersTable({
    required this.state,
    required this.users,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingTextStyle: Theme.of(context).textTheme.labelLarge,
              // Tabela mora da stane u prozor, da se „Akcije“ ne kriju sa strane.
              columnSpacing: 20,
              horizontalMargin: 16,
              columns: const [
                DataColumn(label: Text('Korisnik')),
                DataColumn(label: Text('Uloga')),
                DataColumn(label: Text('Registrovan')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Akcije')),
              ],
              rows: [
                for (final user in users)
                  DataRow(
                    key: ValueKey(user.id.value),
                    cells: [
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.fullName),
                            Text(
                              user.email,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      DataCell(Text(roleLabel(user.role))),
                      DataCell(Text(formatDate(user.createdAt))),
                      DataCell(_StatusLabel(user)),
                      DataCell(
                        _ToggleButton(
                          state: state,
                          user: user,
                          onChange: onChange,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UsersCards extends StatelessWidget {
  final UsersLoaded state;
  final List<AppUser> users;
  final Future<void> Function(AppUser user, {required bool active}) onChange;

  const _UsersCards({
    required this.state,
    required this.users,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final user in users)
          Card(
            key: ValueKey(user.id.value),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName, style: theme.textTheme.titleMedium),
                  Text(user.email),
                  Text(
                    '${roleLabel(user.role)} · registrovan ${formatDate(user.createdAt)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _StatusLabel(user),
                      _ToggleButton(
                        state: state,
                        user: user,
                        onChange: onChange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  final Widget icon;
  final String title;
  final String? message;
  final Widget? action;

  const _Notice({
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = this.message;
    final action = this.action;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(message, textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }
}
