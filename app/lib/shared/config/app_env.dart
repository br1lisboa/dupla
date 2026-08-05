/// The environment a build targets.
///
/// The name of each value is the contract: it must match both the `env` key of
/// `config/<flavor>.json` and the flavor the binary is compiled with.
enum AppEnv { local, staging, prod }

/// Thrown when the configuration file and the compiled binary disagree.
class AppConfigError implements Exception {
  const AppConfigError(this.message);

  final String message;

  @override
  String toString() => 'AppConfigError: $message';
}

/// Resolves [env] — the `env` key of the configuration file — into an [AppEnv],
/// rejecting it when it does not match [flavor], the flavor the binary was
/// compiled with.
///
/// Pure on purpose: both inputs are parameters rather than globals, so the rule
/// can be tested without building the app once per environment.
///
/// Throws [AppConfigError] when [env] is not a known environment, or when it
/// disagrees with [flavor]. A build compiled with no flavor at all has a null
/// [flavor] and is always a mismatch.
AppEnv resolveAppEnv({required String env, required String? flavor}) {
  final resolved = AppEnv.values.asNameMap()[env];

  if (resolved == null) {
    final known = AppEnv.values.map((value) => value.name).join(', ');
    throw AppConfigError(
      'Unknown env "$env" in the configuration file. Expected one of: $known.',
    );
  }

  if (flavor != resolved.name) {
    throw AppConfigError(
      'Environment mismatch: the binary was compiled with flavor '
      '"${flavor ?? '<none>'}" but the configuration file declares env "$env". '
      'Build with: --flavor ${resolved.name} '
      '--dart-define-from-file=config/${resolved.name}.json',
    );
  }

  return resolved;
}
