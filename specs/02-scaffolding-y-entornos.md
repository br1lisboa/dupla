# SPEC 02 — Scaffolding y entornos

> **Estado:** Aprobado · **Depende de:** — · **Fecha:** 2026-08-02
> **Objetivo:** Levantar el esqueleto del proyecto —monorepo, tres entornos, i18n, fronteras FSD verificadas y CI— para que la primera feature se escriba sin decisiones de cimientos pendientes.

---

## Alcance

**Dentro:**

- Monorepo con `/app` (Flutter) y `/supabase` (`supabase init`, cero migraciones).
- Fijado de versión de Flutter/Dart con FVM (`.fvmrc` versionado), sobre Dart 3.10+.
- Tres flavors (`local`, `staging`, `prod`) con `--dart-define-from-file` y un JSON de configuración por entorno. `local` y `staging` versionados; `prod` fuera del repo.
- Bundle ID / applicationId, nombre visible e ícono distintos por flavor, para tener los tres instalados a la vez.
- Banner de entorno en builds no productivos y aserción en `main()` que falla si el `env` del JSON no coincide con el flavor compilado.
- Pisos de OS: iOS 15 y Android API 26.
- Infraestructura de i18n (`flutter_localizations` + `gen-l10n`) con un único locale `es` y `lib/l10n/app_es.arb`.
- Sentry inicializado en `main()`, con DSN por flavor y apagado en `local`.
- Estructura FSD de cuatro capas (`app`, `features`, `entities`, `shared`), cada slice con su `index.dart`.
- Slice `features/home` con una pantalla mínima que muestra un string del `.arb` y el banner de entorno.
- Analyzer plugin nativo de Dart en `/app/tools/fsd_lint` con las tres reglas de fronteras y un test por regla.
- Cadena de codegen (`freezed`, `json_serializable`, `riverpod_generator`, `build_runner`) con el código generado fuera del repositorio.
- Workflow único de CI con dos jobs en paralelo: `app` (codegen + `flutter analyze` + unitarios) y `db` (`supabase start` + `supabase db reset`).
- Un test unitario puro sobre la función que resuelve la configuración de entorno.

**Fuera de alcance (para specs futuras):**

- Codemagic: build de release, firma, distribución y subida de debug symbols a Sentry.
- Schema, RLS, RPC de validación 3-de-4 y tests de integración contra la base (SPEC 03).
- Tokens del design system, tipografía Barlow Condensed y `ThemeData`; la pantalla placeholder usa el tema Material por defecto (SPEC 04).
- Autenticación, gate de navegación y `go_router` (SPEC 05).
- Traducción a otros idiomas. Esta spec deja la infraestructura, no agrega locales.
- Push FCM, deep linking y cola offline (SPEC 07).
- Ícono e identidad visual definitivos: los tres flavors arrancan con íconos placeholder diferenciables entre sí.
- Shorebird (OTA) y analytics de producto.

---

## Modelo de datos

Esta spec no introduce tablas ni estructuras de dominio: el schema es la SPEC 03. Lo que sí introduce es el **contrato de configuración por entorno**, que es dato versionado y del que dependen todas las specs siguientes.

### JSON de configuración — `/app/config/<flavor>.json`

```json
{
  "env": "staging",
  "supabaseUrl": "https://xxxxxxxx.supabase.co",
  "supabaseAnonKey": "eyJhbGciOi...",
  "sentryDsn": "https://xxxxxxxx@o0.ingest.sentry.io/0"
}
```

Archivos:

- `config/local.json` — versionado. Apunta a la Supabase local. `sentryDsn` en cadena vacía.
- `config/staging.json` — versionado.
- `config/prod.json` — **no versionado**, listado en `.gitignore`. Lo inyecta el CI del build de release.
- `config/prod.example.json` — versionado, con las cuatro claves y valores vacíos, para que se sepa qué hay que inyectar.

### Lectura en Dart — `/app/lib/shared/config/`

```dart
enum AppEnv { local, staging, prod }

class AppConfig {
  static const env = String.fromEnvironment('env');
  static const supabaseUrl = String.fromEnvironment('supabaseUrl');
  static const supabaseAnonKey = String.fromEnvironment('supabaseAnonKey');
  static const sentryDsn = String.fromEnvironment('sentryDsn');
}
```

Convenciones:

- Las claves del JSON y los nombres pasados a `String.fromEnvironment` son **el mismo string**. `--dart-define-from-file` no renombra nada.
- Los campos son `static const`: `String.fromEnvironment` se resuelve en tiempo de compilación. Declarado como `final` devuelve siempre la cadena vacía.
- `env` es la única clave que la app compara contra el flavor compilado. Las otras tres son opacas para la app.
- La comparación usa la constante `appFlavor` de `package:flutter/services.dart`, que expone el flavor con el que se compiló. Verificar su disponibilidad en el canal estable al hacer el scaffolding.

Nota de seguridad: `supabaseAnonKey` es pública por diseño; lo que protege los datos es RLS. La clave `service_role` **no aparece en ningún JSON de este directorio** ni en ningún archivo bajo `/app`.

---

## Plan de implementación

Cada paso deja el repositorio en un estado compilable y commiteable.

1. **Fijar la versión de Flutter.** `.fvmrc` con la versión del canal estable (Dart 3.10+), `.gitignore` raíz y un `README.md` con el comando de arranque de cada flavor. *Verificación:* `fvm flutter --version` devuelve la versión fijada.

2. **Crear la app.** `flutter create` en `/app` con la organización y sólo las plataformas `ios` y `android`. *Verificación:* `fvm flutter run` levanta la app de ejemplo.

3. **Subir los pisos de OS.** iOS 15 en `Podfile` y en el proyecto de Xcode; `minSdk 26` en `build.gradle`. *Verificación:* compila en ambas plataformas.

4. **Definir los tres flavors.** Schemes y configuraciones en iOS, `productFlavors` en Android, con bundle ID, nombre visible e ícono placeholder distintos por flavor. *Verificación:* los tres se instalan a la vez en el mismo dispositivo y se distinguen en la pantalla de inicio.

5. **Agregar los JSON de configuración.** `config/local.json` y `config/staging.json` versionados, `config/prod.example.json` versionado, `config/prod.json` en `.gitignore`. *Verificación:* la app compila con `--dart-define-from-file=config/local.json`.

6. **Resolver el entorno en Dart.** `AppConfig` y el enum `AppEnv` en `shared/config/`, más la función pura que traduce el `env` del JSON a `AppEnv` y falla si no coincide con el flavor compilado. Test unitario de esa función: caso válido, caso de `env` desconocido, caso de mismatch. *Verificación:* `fvm flutter test` pasa.

7. **Levantar la estructura FSD.** Las cuatro capas (`app`, `features`, `entities`, `shared`), cada slice con su `index.dart`, y el slice `features/home` con una pantalla mínima cableada desde `main()`. *Verificación:* la app arranca y muestra la pantalla de home.

8. **Instalar la infraestructura de i18n.** `flutter_localizations`, `l10n.yaml`, `lib/l10n/app_es.arb` con el título de home, y la pantalla leyendo el string generado en vez del literal. *Verificación:* la app muestra el mismo texto que antes, ahora desde el `.arb`.

9. **Cablear el banner y la aserción.** Banner de entorno visible en `local` y `staging`, ausente en `prod`, y la aserción de mismatch corriendo en `main()`. *Verificación:* compilar con `--flavor staging` y el JSON de `local` falla al arrancar.

10. **Inicializar Sentry.** `SentryFlutter.init` en `main()` con el DSN del JSON, salteado cuando el DSN viene vacío. *Verificación:* una excepción forzada en `staging` aparece en el dashboard; en `local` no se envía nada.

11. **Montar la cadena de codegen.** `freezed`, `json_serializable`, `riverpod_generator` y `build_runner`; `*.g.dart` y `*.freezed.dart` en `.gitignore`; el estado de la pantalla de home migrado a un provider generado, para que haya algo real que generar. *Verificación:* `dart run build_runner build` genera los archivos y la app compila; con la carpeta de generados borrada, no compila.

12. **Crear el analyzer plugin con la primera regla.** Paquete `/app/tools/fsd_lint`, registro en `analysis_options.yaml`, y la regla `no-higher-level-imports` con su par de fixtures (uno que viola, uno que cumple). *Verificación:* `fvm flutter analyze` marca el import prohibido; el test del paquete pasa.

13. **Agregar `no-cross-imports`** con sus fixtures. *Verificación:* un import entre slices hermanos queda marcado.

14. **Agregar `no-public-api-sidestep`** con sus fixtures. *Verificación:* un import que apunta más profundo que el `index.dart` de un slice ajeno queda marcado.

15. **Inicializar Supabase.** `supabase init` en `/supabase`, con `config.toml` versionado y cero migraciones. *Verificación:* `supabase start` levanta los contenedores y `supabase db reset` termina sin error.

16. **Escribir el workflow de CI.** Un archivo, dos jobs en paralelo: `app` (FVM + `build_runner` + `flutter analyze` + `flutter test`) y `db` (`supabase start` + `supabase db reset`). Sin filtros por path ni por tag. *Verificación:* un push con un import que viola una regla FSD pone el job `app` en rojo.

---

## Criterios de aceptación

- [ ] `fvm flutter --version` devuelve la versión fijada en `.fvmrc`.
- [ ] Los tres flavors se instalan a la vez en un mismo dispositivo, con nombre e ícono distinguibles entre sí.
- [ ] Cada flavor compila con su JSON correspondiente vía `--dart-define-from-file`.
- [ ] Compilar `--flavor prod` con `config/staging.json` hace que la app falle al arrancar, con un mensaje que nombra el flavor y el `env` en conflicto.
- [ ] El banner de entorno se ve en `local` y `staging`, y no se ve en `prod`.
- [ ] `git ls-files` no lista `config/prod.json` ni ningún `*.g.dart` o `*.freezed.dart`.
- [ ] `config/prod.example.json` existe y tiene las cuatro claves con valores vacíos.
- [ ] La pantalla de home no contiene ningún literal de texto visible: todos salen de `lib/l10n/app_es.arb`.
- [ ] Una excepción no capturada en `staging` aparece en el proyecto de Sentry.
- [ ] En `local` no se envía nada a Sentry: con el DSN vacío, la inicialización se saltea.
- [ ] Las cuatro capas existen y cada slice expone un `index.dart`.
- [ ] `fvm flutter analyze` termina sin errores sobre el repositorio limpio.
- [ ] Un import desde `shared` hacia `features` es marcado por `no-higher-level-imports`.
- [ ] Un import entre dos slices hermanos de `features` es marcado por `no-cross-imports`.
- [ ] Un import que apunta más profundo que el `index.dart` de un slice ajeno es marcado por `no-public-api-sidestep`.
- [ ] Los tests del paquete `fsd_lint` pasan, con al menos un caso que viola y uno que cumple por regla.
- [ ] `dart run build_runner build` genera los archivos sin conflictos y la app compila; borrados los generados, la app no compila.
- [ ] `fvm flutter test` pasa, incluyendo los tres casos de resolución de entorno.
- [ ] `supabase start` y `supabase db reset` terminan sin error con cero migraciones.
- [ ] El workflow de CI corre `app` y `db` en paralelo y ambos quedan en verde sobre `main`.
- [ ] Un push con un import que viola una regla FSD deja el job `app` en rojo.
- [ ] Un clon limpio del repositorio puede correr el flavor `local` siguiendo únicamente el `README.md`.

---

## Decisiones

**Fronteras y estructura**

- **Sí:** analyzer plugin nativo de Dart (`analysis_server_plugin`). Corre dentro de `flutter analyze`, sin paso aparte, y da feedback en el editor. Supersede la decisión 11 del grill 01.
- **No:** `custom_lint`. En camino de deprecación desde que Dart 3.10 incorporó el sistema oficial.
- **No:** el paquete `fsd_lint` de pub.dev. Un like, unas 138 descargas, uploader no verificado, y construido sobre el camino deprecado.
- **No:** Steiger, el linter oficial de FSD. Es JS/TS: necesitaría un parser y un resolver de Dart que no tiene.
- **No:** chequeo de imports con `rg` en CI. Funciona, pero el error aparece cinco minutos después del push en vez de mientras escribís.
- **Sí:** un `index.dart` por slice. Sin él, las dos primeras reglas garantizan la dirección de los imports pero no la encapsulación. En Dart no hay privacidad dentro de un paquete, así que la regla es la única defensa. Costo aceptado: mantener los barrels a mano.
- **Sí:** tests por regla, con un fixture que viola y uno que cumple. Una regla de lint sin test es una regla que un día deja de disparar en silencio.

**Entornos y configuración**

- **Sí:** `--dart-define-from-file` con un JSON por entorno, `local` y `staging` versionados. Clonar el repo y poder correr la app sin pedirle valores a nadie.
- **No:** toda la configuración por variables de CI. Los valores de `local` y `staging` no son secretos; tratarlos como tales sólo agrega fricción.
- **Sí:** bundle ID, nombre e ícono distintos por flavor. Para no reportar bugs de staging creyendo que son de producción.
- **Sí:** banner de entorno y aserción `env` contra `appFlavor` en `main()`. Cierra la pregunta abierta 3 del grill 03: `--flavor prod` con el JSON de staging compila sin error y escribiría en la base equivocada.
- **Sí:** FVM con `.fvmrc` versionado. El plugin de analyzer exige Dart 3.10+; una versión distinta en cada máquina convierte eso en un bug intermitente.
- **No:** `.tool-versions` ni pin únicamente en CI. El primero es equivalente pero el proyecto no usa asdf/mise para nada más; el segundo deja cada máquina librada a sí misma.

**Cadena de build**

- **Sí:** `freezed`, `json_serializable`, `riverpod_generator` y `build_runner` desde el esqueleto, estrenados con un provider real en home.
- **Sí:** código generado fuera del repositorio, regenerado en CI. Commitearlo ensucia todos los diffs y produce conflictos de merge que no significan nada.
- **Sí:** un workflow con dos jobs en paralelo, sin filtros por path ni por tags. Simple no es menos cosas corriendo: es menos cosas que decidir cada vez.
- **Sí:** el job `db` nace en esta spec con cero migraciones. Verifica que el entorno local levanta, y la SPEC 03 le enchufa tests sin tocar CI.
- **No:** Codemagic en esta spec. Firma y distribución sin app que distribuir es setup muerto. Se lleva consigo la subida de debug symbols a Sentry.

**Producto y alcance**

- **Sí:** infraestructura de i18n con un único locale `es`. Sumar un idioma después pasa a ser copiar y traducir un archivo, en vez de peinar cuarenta pantallas cazando literales, que siempre deja afuera los `SnackBar`, los errores y los `semanticsLabel`.
- **No:** hardcodear español en los widgets, y **no** multi-idioma real desde el día uno.
- **Sí:** iOS 15 y Android API 26. El criterio no fue cobertura de parque sino cuánto código condicional se evita: cada piso que se sube borra ramas `if (versión < X)` que nunca se testean.
- **Sí:** Sentry como parte del esqueleto, no como spec propia ni diferido. Es configuración de `main()`. Nota operativa: la cuota de Sentry es por organización, no por proyecto, y el plan gratuito es de un solo usuario.
- **Sí:** numeración de specs arrancando en `02`, respetando el plan del grill 02. La trazabilidad con los grills vale más que la prolijidad del contador.

---

## Riesgos

| Riesgo | Mitigación |
| --- | --- |
| `appFlavor` no disponible en el canal fijado. La aserción se compararía contra sí misma. | Verificar en el paso 2 del plan. Si no está, pasar el flavor como un `--dart-define` aparte en el comando de build; el chequeo detecta el JSON desactualizado, no la mezcla de archivos. |
| La API de `analysis_server_plugin` es nueva y puede cambiar entre versiones de Dart. | La versión está fijada en `.fvmrc` y los tests de las tres reglas corren en CI: un cambio de API rompe el job `app`, no se descubre en producción. |
| El piso de Dart sube solo en cada versión mayor de Flutter. Actualizar FVM puede forzar tocar el plugin. | Tratar cada suba de versión en `.fvmrc` como un cambio con su propio commit y su corrida de CI, nunca junto con otro trabajo. |
| Los archivos generados (`*.g.dart`, `*.freezed.dart`) pueden disparar falsos positivos en las reglas FSD. | Excluirlos explícitamente en `analysis_options.yaml` desde el paso 12, antes de escribir la primera regla. |
| Con el generado fuera del repositorio, un clon limpio abre el editor con errores por todos lados. | El `README.md` pone `dart run build_runner build` como paso obligatorio antes del primer `run`, y el job `app` lo ejecuta antes del `analyze`. |
| El job `db` levanta Docker en cada push y es el más lento de los dos. | Se acepta mientras sean dos jobs en paralelo: el job `app` da feedback en aproximadamente un minuto y no espera al otro. Si el tiempo del job `db` se vuelve un problema, se revisa en la SPEC 03, que es la que le agrega carga real. |
| Los íconos placeholder llegan a producción. | El ícono definitivo es criterio de aceptación de la SPEC 04, que es la spec dueña de la identidad visual. |

---

## Lo que **no** entra en esta spec

- Codemagic: build de release, firma, distribución y debug symbols.
- Schema, RLS y RPC de validación 3-de-4 (SPEC 03).
- Tokens del design system, tipografía e ícono definitivo (SPEC 04).
- Autenticación y gate de navegación (SPEC 05).
- Push FCM, deep linking y cola offline (SPEC 07).
- Idiomas adicionales al `es`.
- Shorebird (OTA) y analytics de producto.

Cada uno de esos, cuando llegue, va en su propia spec.
