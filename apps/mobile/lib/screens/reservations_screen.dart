import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../actions/reservation_cancel.dart';
import '../data/mobile_demo_data.dart';
import '../text/reservation_texts.dart';
import '../widgets/simulation_menu.dart';

class ReservationsScreen extends StatelessWidget {
  const ReservationsScreen({super.key});

  static void reload(BuildContext context) {
    context.read<ReservationBloc>().add(
      const UserReservationsRequested(MobileDemoData.currentUserId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moje rezervacije'),
        actions: const [SimulationMenu()],
      ),
      body: BlocBuilder<ReservationBloc, ReservationState>(
        builder: (context, state) {
          return switch (state) {
            ReservationInitial() ||
            ReservationLoading() => const _LoadingView(),
            ReservationError(:final message) => _ErrorView(
              message: errorDetails(message),
              onRetry: () => reload(context),
            ),
            ReservationEmpty() => _EmptyView(onReload: () => reload(context)),
            ReservationLoaded(:final reservations) => _ReservationsList(
              reservations: _mine(reservations),
            ),
          };
        },
      ),
    );
  }

  static List<Reservation> _mine(List<Reservation> reservations) {
    return [
      for (final reservation in reservations)
        if (reservation.userId == MobileDemoData.currentUserId) reservation,
    ]..sort((a, b) => b.startTime.compareTo(a.startTime));
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Učitavanje rezervacija...'),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 72, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Rezervacije nisu učitane', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Pokušaj ponovo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onReload;

  const _EmptyView({required this.onReload});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy_outlined, size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Nemate rezervacija', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            const Text('Izaberite teren i rezervišite termin.'),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onReload,
              icon: const Icon(Icons.refresh),
              label: const Text('Osveži'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReservationsList extends StatelessWidget {
  final List<Reservation> reservations;

  const _ReservationsList({required this.reservations});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => ReservationsScreen.reload(context),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: reservations.length,
        itemBuilder: (context, index) =>
            _ReservationCard(reservation: reservations[index]),
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  final Reservation reservation;

  const _ReservationCard({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = reservation.status;
    final isActive = reservation.isActive;
    final cancellationError = validateCancellation(
      reservation: reservation,
      now: DateTime.now(),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/reservations/${reservation.id.value}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                MobileDemoData.fieldName(reservation.fieldId),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                text: formatDate(reservation.startTime),
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.access_time,
                text: formatTimeRange(
                  reservation.startTime,
                  reservation.endTime,
                ),
              ),
              const SizedBox(height: 8),
              const _InfoRow(
                icon: Icons.person_outline,
                text: MobileDemoData.currentUserName,
              ),
              const SizedBox(height: 12),
              Text(
                '${reservation.totalPrice} RSD',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Chip(
                avatar: Icon(switch (status) {
                  ReservationStatus.cancelled => Icons.cancel_outlined,
                  ReservationStatus.completed => Icons.check_circle_outline,
                  ReservationStatus.confirmed => Icons.event_available,
                  ReservationStatus.pending => Icons.schedule,
                }, size: 18),
                label: Text(statusLabel(status)),
              ),
              if (isActive) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: cancellationError == null
                      ? () => cancelReservationWithConfirmation(
                          context,
                          reservation,
                        )
                      : null,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Otkaži rezervaciju'),
                ),
                if (cancellationError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    validationMessage(cancellationError),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
