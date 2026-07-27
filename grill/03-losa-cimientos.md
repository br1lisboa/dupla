# PadelAPP — La losa: cimientos, entornos y fronteras

**Date:** 2026-07-27

## Resumen

Sesión de grill sobre la **losa horizontal** (specs 02, 03 y 04) definida en
`02-descomposicion-en-specs.md`. Se cerraron las dos preguntas bloqueantes
heredadas del grill 01 (i18n y versiones mínimas de OS), se resolvió el
mecanismo de configuración por entorno, y se **corrigieron dos decisiones del
grill 01** que quedaron desactualizadas o desproporcionadas: la herramienta de
fronteras FSD y la estrategia de testing de base.

También se estableció un **criterio de corte** para decidir qué entra en la losa
y qué no, que se aplicó para sacar temas de la 02 y devolverlos a su spec dueña.

## Criterio de corte de la losa

La pregunta no es "¿es importante?" sino **"¿el costo de hacerlo después crece o
se queda igual?"**.

- **Costo creciente → va ahora:** entornos/flavors, i18n, estructura FSD, schema,
  tokens del DS. Hacerlos después implica tocar todo lo construido encima.
- **Costo plano → puede esperar:** CI, plugin de lint, Sentry. Agregarlos hoy o
  en tres semanas cuesta lo mismo. Se incluyen igual por conveniencia, no por
  bloqueo.

## Decisiones clave

1. **Sentry entra en la 02**, no como spec propia ni diferido a la 05. Es config
   del esqueleto: init en `main()`, **DSN por flavor**, apagado en `local`, y
   subida de debug symbols en el build de Codemagic (sin símbolos, los stack
   traces de un build ofuscado son ilegibles). Nota operativa: **la cuota de
   Sentry es por organización, no por proyecto** — staging y prod comparten pote,
   y el plan gratuito es de 1 usuario.

2. **Infraestructura i18n desde la 02, con un solo locale (`es`).** No se traduce
   nada; los strings simplemente nacen en archivos `.arb` en vez de incrustados
   en widgets. Razón: sumar un idioma después pasa a ser copiar y traducir un
   archivo, en vez de peinar 40 pantallas cazando strings hardcodeados (que
   siempre deja afuera `SnackBar`, errores y `semanticsLabel`).

3. **Pisos de OS: iOS 15+ y Android API 26 (8.0).** El criterio no fue cobertura
   de parque sino **cuánto código condicional se evita** — cada piso que se sube
   borra ramas `if (versión < X)` que nunca se testean. Nota: Flutter tiene su
   propio piso y **sube solo** en cada versión mayor; verificar el mínimo del
   canal estable al hacer el scaffolding y no pelearse con él.

4. **Fronteras FSD: analyzer plugin NATIVO de Dart, no `custom_lint`.**
   **Supersede la decisión 11 del grill 01.** Dart 3.10 incorporó el sistema
   oficial `analysis_server_plugin`, que corre dentro de `dart analyze` /
   `flutter analyze` (sin paso aparte) y dejó a `custom_lint` en camino de
   deprecación. Esto elimina los dos costos que hacían dudar: programar contra
   una API de terceros que se pudre, y perder el feedback en el editor.

5. **Tres reglas, con la taxonomía de Steiger** (el linter oficial de FSD, que
   **no se puede usar**: es JS/TS y necesitaría un parser y un resolver de Dart
   que no tiene):
   - `no-higher-level-imports` — no importar hacia capas superiores.
   - `no-cross-imports` — no importar entre slices hermanos.
   - `no-public-api-sidestep` — no importar más profundo que el barrel de un
     slice ajeno.
   Se descartó el paquete `fsd_lint` de pub.dev: 1 like, ~138 descargas, uploader
   no verificado, y construido sobre `custom_lint` (el camino deprecado).

6. **Cada slice expone un `index.dart` (barrel).** Sin esto, las dos primeras
   reglas garantizan la *dirección* de los imports pero no la *encapsulación*:
   cualquiera puede importar un provider interno de otro slice y bloquear su
   refactor. En Dart no hay privacidad real dentro de un paquete (`lib/src` solo
   aplica entre paquetes), así que la regla es la única defensa.

7. **Config por flavor con `--dart-define-from-file` y un JSON por entorno.**
   `local` y `staging` versionados en el repo, `prod` inyectado por Codemagic.
   Bundle ID / applicationId, nombre e ícono **distintos por flavor**, para tener
   los tres instalados a la vez y no reportar bugs de staging creyendo que son de
   prod. Nota de seguridad: **la anon key de Supabase no es secreta** (es pública
   por diseño; lo que protege es RLS), pero la **`service_role` key nunca toca el
   código Flutter** — vive solo en Edge Functions y CI.

8. **Testing de base: pgTAP descartado. Tests de integración en Dart contra
   Supabase local.** **Supersede la decisión 14 del grill 01.** Razón: pgTAP
   implica lenguaje, framework y toolchain nuevos antes de la primera feature.
   Pero *no* testear la base no era opción: la arquitectura empujó **autorización
   (RLS)** y **dominio (RPC 3-de-4)** adentro de Postgres, así que "solo tests
   unitarios de Dart" apunta a la única capa donde no quedó ninguna de las dos.
   Cobertura mínima acordada: el jugador B no ve el partido del jugador A; con 2
   votos sigue `pending`, con 3 pasa a `validated`, con 1 rechazo va a `disputed`.
   Motivo de fondo: **un bug de RLS no explota, filtra** — devuelve filas de más
   en silencio y ningún test de cliente lo distingue de datos correctos.

9. **CI: un workflow, dos jobs en paralelo, sin filtros por path ni tags.**
   - `app` — `flutter analyze` (que ya incluye las tres reglas FSD) + unitarios
     puros. Feedback en ~1 minuto.
   - `db` — `supabase start` + migraciones + tests de integración.
   Se descartó la variante "tests tageados que corren solo en local": tenía *más*
   piezas (tags, exclusión, una regla de disciplina en el README) y dependía de
   que alguien se acordara. **Simple no es menos cosas corriendo, es menos cosas
   que decidir cada vez.**

10. **Marcador por sets: tabla `match_sets` (una fila por set), no `jsonb`.**
    Coherencia con el motivo por el que se eligió Postgres (grill 01 descartó
    Firebase *porque el dominio es relacional*). Concreto: la spec 08 necesita
    agregar games y sets ganados — con tabla es `SUM` + `GROUP BY`; con jsonb es
    desarmar el array en cada consulta. Además la tabla admite constraints reales
    (unicidad del número de set, rango de games) que jsonb no valida.

11. **Tokens del DS con nombres semánticos**, alineados al vocabulario de
    `ColorScheme` de Material 3 (`surface`, `onSurface`, `primary`, `danger`), no
    literales (`limeGreen`, `darkGrey`). Razones: (a) el día que el verde cambie,
    los literales quedan mintiendo en cincuenta widgets; (b) **tema claro** —
    con semánticos, agregar light después es escribir un segundo mapa de valores
    sin tocar un solo widget; con literales es reescribir todo.

12. **Fuentes empaquetadas como assets, no `google_fonts`.** El paquete descarga
    la tipografía **por red en el primer arranque**. Con offline pragmático
    (decisión 10 del grill 01) y una identidad visual que *es* la condensada, un
    primer arranque sin señal mostraría la fuente por defecto del sistema.

13. **El verde lima exacto no bloquea la 04.** Con un único lugar donde vive el
    token, cambiarlo cuando llegue el `.pen` es una línea. Se arranca con
    placeholder.

14. **El vencimiento a 72h sale de la losa.** Es lógica de la spec 07
    (`cargar-y-validar`), no cimiento. Se documenta el fork sin resolver (ver
    Preguntas abiertas).

## Plan / Próximos pasos

1. Escribir la **spec `02-scaffolding-y-entornos`** con todo lo cerrado acá:
   monorepo `/app` + `/supabase`, 3 flavors con JSON de config, i18n `es`, pisos
   de OS, Sentry, analyzer plugin con las 3 reglas, y los 2 jobs de CI.
2. Confirmar al hacer el scaffolding que el canal estable de Flutter/Dart soporta
   el sistema nativo de analyzer plugins (Dart 3.10+).
3. Seguir con la **03** (schema + RLS + RPC 3-de-4 + tests de integración) y la
   **04** (tokens semánticos + assets de tipografía), que no se bloquean entre sí.

## Supuestos y tradeoffs (elegido vs descartado)

- **Analyzer plugin nativo** ✅ vs `custom_lint` ❌ (en deprecación) vs `fsd_lint`
  ❌ (inmaduro y sobre el camino deprecado) vs Steiger ❌ (JS/TS, no parsea Dart)
  vs chequeo con `rg` en CI ❌ (sin feedback en el editor).
- **Barrel + 3ª regla** ✅ vs solo reglas de dirección ❌ (encapsulación librada al
  honor system). Costo aceptado: mantener los barrels a mano.
- **JSON por flavor versionado** ✅ vs todo por variables de CI ❌ (clonás el repo
  y no podés correr la app hasta que alguien te pase valores que ni son secretos).
- **Tests de integración en Dart** ✅ vs pgTAP ❌ (toolchain nuevo antes de la
  primera feature) vs solo unitarios de Dart ❌ (no cubre ni RLS ni la máquina de
  estados, que viven en Postgres). Tradeoff: menos precisión que pgTAP para
  aislar policies; se acepta a cambio de cero toolchain nuevo.
- **2 jobs siempre** ✅ vs filtros por path ❌ vs tests locales tageados ❌.
- **Tabla `match_sets`** ✅ vs `jsonb` ❌ (agregación incómoda, sin constraints).
  Se descartó el argumento de flexibilidad de jsonb: el punto-a-punto en vivo de
  fase 2 va a ser su propia tabla igual.
- **Tokens semánticos** ✅ vs literales ❌. Costo aceptado: pensar el rol en vez de
  tirar el color.
- **Assets de fuente** ✅ vs `google_fonts` ❌ (descarga en runtime).
- **iOS 15 / API 26** ✅ vs piso más bajo ❌ (más ramas condicionales sin testear;
  un equipo anterior a 2017 tampoco corre bien las animaciones del sorteo).
- **i18n con un locale** ✅ vs multi-idioma real desde el día 1 ⏸️ vs hardcodear
  español ❌.

## Preguntas abiertas

1. **Fijado de versión de Flutter/Dart** — ¿FVM, `.tool-versions`, o solo pin en
   CI? No discutido.
2. **Estrategia de codegen** — `freezed`, `json_serializable`,
   `riverpod_generator`: cuáles entran y si el código generado se commitea o se
   regenera en CI. No discutido.
3. **Riesgo de mismatch flavor ↔ config**: `--flavor prod` con el JSON de staging
   compila sin error y escribe en la base equivocada. Mitigación tentativa (no
   decidida): que el JSON lleve el nombre del entorno y la app lo muestre en
   pantalla en builds no productivos.
4. **Vencimiento 72h (spec 07)**: ¿`pg_cron` que escribe el estado `expired`, o
   estado calculado al leer desde una vista (sin piezas móviles, pero sin momento
   en que disparar un push de "tu partido expiró")?
5. **Plan de Sentry**: el free tier es de 1 usuario. Si el dashboard lo miran dos
   personas, hay que presupuestar el plan pago.
6. **Verde lima exacto y assets de Barlow Condensed** — heredada del grill 01;
   pendiente del `.pen` / MCP de diseño.
