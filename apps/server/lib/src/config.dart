import 'dart:io';

/// Podešavanja servera.
///
/// Sve vrednosti dolaze iz okruženja ili iz `.env` fajla. U kodu nema
/// tajni ni podrazumevanih lozinki: ako nešto obavezno nedostaje,
/// server odbija da se podigne i kaže šta fali.
final class ServerConfig {
  /// Adresa na kojoj server sluša (`0.0.0.0` u kontejneru).
  final String host;
  final int port;

  final String dbHost;
  final int dbPort;
  final String dbName;
  final String dbUser;
  final String dbPassword;

  /// Tajna kojom server potpisuje tokene (HS256).
  final String jwtSecret;

  /// Koliko dugo važi prijava.
  final Duration tokenTtl;

  /// Porekla kojima pregledač sme da šalje zahteve (CORS).
  ///
  /// `http://localhost:*` dozvoljava bilo koji port na localhost-u.
  final List<String> corsAllowedOrigins;

  /// Da li server pri podizanju upisuje početne podatke (samo razvoj).
  final bool seedDemoData;

  const ServerConfig({
    required this.host,
    required this.port,
    required this.dbHost,
    required this.dbPort,
    required this.dbName,
    required this.dbUser,
    required this.dbPassword,
    required this.jwtSecret,
    required this.tokenTtl,
    required this.corsAllowedOrigins,
    required this.seedDemoData,
  });

  /// Čita podešavanja iz [environment].
  ///
  /// Baca [ConfigException] sa spiskom svih problema odjednom.
  factory ServerConfig.fromEnvironment(Map<String, String> environment) {
    final problems = <String>[];

    String required(String key) {
      final value = environment[key];
      if (value == null || value.trim().isEmpty) {
        problems.add('$key nije podešen');
        return '';
      }
      return value.trim();
    }

    int requiredInt(String key) {
      final raw = required(key);
      if (raw.isEmpty) return 0;
      final value = int.tryParse(raw);
      if (value == null || value <= 0) {
        problems.add('$key mora biti pozitivan ceo broj (dobijeno "$raw")');
        return 0;
      }
      return value;
    }

    final config = ServerConfig(
      host: environment['SERVER_HOST']?.trim().isNotEmpty == true
          ? environment['SERVER_HOST']!.trim()
          : '0.0.0.0',
      port: requiredInt('SERVER_PORT'),
      dbHost: required('DB_HOST'),
      dbPort: requiredInt('DB_PORT'),
      dbName: required('DB_NAME'),
      dbUser: required('DB_USER'),
      dbPassword: required('DB_PASSWORD'),
      jwtSecret: required('JWT_SECRET'),
      tokenTtl: Duration(minutes: requiredInt('JWT_TTL_MINUTES')),
      corsAllowedOrigins: (environment['CORS_ALLOWED_ORIGINS'] ?? '')
          .split(',')
          .map((origin) => origin.trim())
          .where((origin) => origin.isNotEmpty)
          .toList(growable: false),
      seedDemoData: environment['SEED_DEMO_DATA']?.trim() == 'true',
    );

    if (config.jwtSecret.isNotEmpty && config.jwtSecret.length < 32) {
      problems.add('JWT_SECRET mora imati bar 32 znaka');
    }

    if (problems.isNotEmpty) {
      throw ConfigException(problems);
    }

    return config;
  }

  /// Spaja `.env` fajl (ako postoji) i promenljive okruženja.
  ///
  /// `.env` je u korenu repozitorijuma (deli ga sa Docker Compose-om), pa
  /// se traži u tekućem folderu i do dva nivoa iznad (`apps/server` → koren).
  /// Promenljive okruženja imaju prednost, pa Docker Compose može da
  /// pregazi vrednost iz `.env` (npr. `DB_HOST=db`).
  static Future<ServerConfig> load({String? envFilePath}) async {
    final file = envFilePath != null ? File(envFilePath) : _findDotEnv();
    final fromFile = file != null && await file.exists()
        ? parseDotEnv(await file.readAsString())
        : const <String, String>{};

    return ServerConfig.fromEnvironment({
      ...fromFile,
      ...Platform.environment,
    });
  }

  static File? _findDotEnv() {
    var directory = Directory.current;
    for (var level = 0; level < 3; level++) {
      final candidate = File('${directory.path}${Platform.pathSeparator}.env');
      if (candidate.existsSync()) return candidate;
      directory = directory.parent;
    }
    return null;
  }
}

/// Podešavanja nisu potpuna ili su neispravna.
final class ConfigException implements Exception {
  final List<String> problems;

  const ConfigException(this.problems);

  @override
  String toString() =>
      'Neispravna podešavanja servera:\n${problems.map((p) => '  - $p').join('\n')}';
}

/// Čita jednostavan `.env` format: `KLJUČ=vrednost`, `#` za komentar.
///
/// Navodnici oko vrednosti se skidaju. Ne podržava višelinijske vrednosti
/// ni zamenu `${...}`, jer nam ne trebaju.
Map<String, String> parseDotEnv(String content) {
  final result = <String, String>{};

  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;

    final separator = line.indexOf('=');
    if (separator <= 0) continue;

    final key = line.substring(0, separator).trim();
    var value = line.substring(separator + 1).trim();

    final quoted = value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")));
    if (quoted) {
      value = value.substring(1, value.length - 1);
    }

    result[key] = value;
  }

  return result;
}
