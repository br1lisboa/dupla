/// Configuration injected at compile time by `--dart-define-from-file`.
///
/// The keys of `config/<flavor>.json` and the names passed to
/// [String.fromEnvironment] are the same strings: `--dart-define-from-file`
/// renames nothing.
///
/// Every field must be `static const`. [String.fromEnvironment] is resolved by
/// the compiler, so a `final` field reads as an empty string at runtime without
/// any error to point at the cause.
abstract final class AppConfig {
  static const env = String.fromEnvironment('env');
  static const supabaseUrl = String.fromEnvironment('supabaseUrl');
  static const supabaseAnonKey = String.fromEnvironment('supabaseAnonKey');
  static const sentryDsn = String.fromEnvironment('sentryDsn');
}
