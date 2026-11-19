import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

/// Ikonica sporta. Izbor ide po `SportType`, ne po tekstu naslova, a `switch`
/// je iscrpan: nov sport u domenu ne prolazi dok ovde ne dobije ikonicu.
IconData sportIcon(SportType sport) {
  return switch (sport) {
    SportType.football || SportType.futsal => Icons.sports_soccer,
    SportType.basketball => Icons.sports_basketball,
    SportType.tennis || SportType.padel => Icons.sports_tennis,
    SportType.volleyball => Icons.sports_volleyball,
    SportType.swimming => Icons.pool,
    SportType.other => Icons.sports,
  };
}
