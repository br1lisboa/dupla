# dupla

Aplicación de pádel. Monorepo con la app Flutter en `app/` y la base de datos Supabase en `supabase/`.

## Arranque desde un clon limpio

```bash
# 1. Instalar la versión de Flutter fijada en .fvmrc
fvm install

# 2. Dependencias
cd app && fvm flutter pub get

# 3. Generar el código de freezed / json_serializable / riverpod
fvm dart run build_runner build --delete-conflicting-outputs

# 4. Levantar la base local (en otra terminal, desde la raíz)
cd supabase && supabase start

# 5. Correr la app
cd app && fvm flutter run --flavor local --dart-define-from-file=config/local.json
```

El paso 3 no es opcional: el código generado no está versionado. Sin él, el editor muestra errores y la app no compila.

## Flavors

Los tres se instalan a la vez en el mismo dispositivo, con bundle ID, nombre e ícono distintos.

| Flavor | Comando | Configuración |
| --- | --- | --- |
| `local` | `fvm flutter run --flavor local --dart-define-from-file=config/local.json` | Versionada. Apunta a la Supabase local. Sin Sentry. |
| `staging` | `fvm flutter run --flavor staging --dart-define-from-file=config/staging.json` | Versionada. |
| `prod` | `fvm flutter run --flavor prod --dart-define-from-file=config/prod.json` | **No versionada.** Copiar `config/prod.example.json` y completar. |

El flavor compilado y el `env` del JSON tienen que coincidir. Si no, la app falla al arrancar con un mensaje que nombra ambos: es a propósito, evita escribir en la base equivocada.

## Estructura

```
app/          Aplicación Flutter (FSD: app, features, entities, shared)
  config/     Un JSON de configuración por entorno
  tools/      fsd_lint — analyzer plugin con las reglas de fronteras
supabase/     Migraciones y config.toml
specs/        Specs aprobadas
grill/        Sesiones de decisión previas a las specs
```

## Comandos útiles

```bash
fvm flutter analyze                  # incluye las reglas de fronteras FSD
fvm flutter test
fvm dart run build_runner watch --delete-conflicting-outputs
supabase db reset                    # desde supabase/
```
