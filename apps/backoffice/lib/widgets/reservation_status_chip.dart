import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

class ReservationStatusChip extends StatelessWidget {
  final ReservationStatus status;

  const ReservationStatusChip({super.key, required this.status});

  static String label(ReservationStatus status) {
    return switch (status) {
      ReservationStatus.pending => 'Na čekanju',
      ReservationStatus.confirmed => 'Potvrđena',
      ReservationStatus.completed => 'Završena',
      ReservationStatus.cancelled => 'Otkazana',
    };
  }

  Color _color(ColorScheme colors) {
    return switch (status) {
      ReservationStatus.pending => Colors.orange.shade700,
      ReservationStatus.confirmed => colors.primary,
      ReservationStatus.completed => colors.outline,
      ReservationStatus.cancelled => colors.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(Theme.of(context).colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label(status),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
