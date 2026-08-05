import 'package:dupla/shared/config/index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveAppEnv', () {
    test('resolves every environment when the flavor agrees', () {
      for (final value in AppEnv.values) {
        expect(resolveAppEnv(env: value.name, flavor: value.name), value);
      }
    });

    test('rejects an env the enum does not know', () {
      expect(
        () => resolveAppEnv(env: 'qa', flavor: 'qa'),
        throwsA(
          isA<AppConfigError>().having(
            (error) => error.message,
            'names the offending value',
            contains('qa'),
          ),
        ),
      );
    });

    test('rejects a config whose env disagrees with the compiled flavor', () {
      expect(
        () => resolveAppEnv(env: 'staging', flavor: 'prod'),
        throwsA(
          isA<AppConfigError>()
              .having(
                (error) => error.message,
                'names the compiled flavor',
                contains('prod'),
              )
              .having(
                (error) => error.message,
                'names the declared env',
                contains('staging'),
              ),
        ),
      );
    });

    test('rejects a binary compiled without any flavor', () {
      expect(
        () => resolveAppEnv(env: 'local', flavor: null),
        throwsA(isA<AppConfigError>()),
      );
    });
  });
}
