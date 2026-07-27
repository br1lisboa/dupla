# PadelAPP — Stack, arquitectura y fundamentos

**Date:** 2026-07-18

## Resumen

Sesión de grill para definir tecnologías, arquitectura y fundamentos de PadelAPP:
app mobile (iOS + Android) social y de tracking de partidos de padel. Punto de
partida: proyecto greenfield (vacío) + un PDF de diseño (export Pencil) que describe
las pantallas — signup (email→datos→nivel), login, home/dashboard, stats+historial,
sorteo (con animación), amigos, perfil, config, y carga de resultado con validación
"3 de 4". Estética: dark, verde lima, tipografía Barlow Condensed.

Se recorrió el árbol de decisiones de punta a punta: framework, backend, design
system, frontera cliente/servidor, estado, navegación, modelo de dominio, auth, push,
offline, estructura de repo, arquitectura de carpetas, entornos/CI-CD, OTA,
observabilidad y testing.

## Decisiones clave

1. **Framework mobile: Flutter.** Un solo codebase iOS+Android; la animación del
   sorteo se resuelve bien sin nativo. **Expo queda descartado por incompatibilidad**
   (Expo es exclusivo de React Native, no existe "Flutter + Expo").

2. **Backend: Supabase all-in.** Postgres + Auth + Realtime + Storage + Edge Functions
   (Deno/TS) + RLS, sin servicio propio que desplegar. Se evaluó y descartó Node
   aparte (un servicio más de mantener) y backend Dart/Serverpod (ecosistema chico).
   La lógica de negocio vive en **Edge Functions y/o RPC/funciones de Postgres**.
   Razón: dominio relacional + necesidad de realtime, con mínima superficie de ops.

3. **Design System propio** con `ThemeData` + Material 3 customizado. El diseño ya trae
   tokens (dark, verde lima, Barlow Condensed) que mapean 1:1 a `ColorScheme`/`TextTheme`.
   **Tailwind NO aplica** (es CSS/web; Flutter no tiene DOM ni CSS).

4. **Frontera cliente↔backend: híbrida por regla.** Flutter habla **directo con Supabase**
   (SDK + RLS) para lo commodity (auth, lecturas simples, realtime de validación/carga en
   vivo). La **lógica de negocio con privilegio o reglas** (sorteo, transición de
   validación, agregación de stats) va por Edge Functions / RPC. Regla: si RLS alcanza,
   directo; si necesita reglas/privilegio, por función.

5. **Estado: Riverpod v2 (code-gen).** Desacopla estado de UI, testeable sin widgets,
   y envuelve streams de realtime en providers.

6. **Navegación: `go_router`** (oficial). Redirect por estado de auth para el gate
   signup/login/home + deep linking para que la push abra la pantalla de validación.

7. **Modelo del núcleo (dominio):**
   - Partido **2v2 fijo** (4 jugadores). Sin formatos alternativos en MVP.
   - Resultado = **marcador por sets**, cargado por 1 jugador al terminar.
   - **Validación 3-de-4:** resultado nace `pending`; el que carga cuenta como 1
     confirmación; **3 confirmaciones → `validated`**; **1 rechazo → `disputed`**
     (congelado, corregible/reabrible); **timeout 72h sin 3 → `expired`** (no suma).
   - **Nivel autodeclarado** en signup; ajuste automático (ELO/ranking) = fase 2.
   - Transición de estado vía **RPC/trigger de Postgres** (atómica, pegada al dato).
   - Tablas base: `matches`, `match_players` (4, equipo A/B), `match_results`,
     `result_validations` (voto por jugador), `device_tokens`.

8. **Auth: email+password (con verificación) + Sign in with Apple + Google.**
   Nota de plataforma: incluir Google **obliga** a ofrecer Apple en iOS (App Store
   guideline 4.8).

9. **Push: FCM como transporte + Edge Function.** FCM cubre iOS y Android; disparo por
   trigger/webhook de Postgres al nacer una validación `pending` → Edge Function envía a
   los device tokens de los otros 3. FCM es **solo transporte**, no reintroduce Firebase
   como backend.

10. **Offline pragmático.** Cola local de escrituras críticas (cargar resultado sin señal
    → sync al reconectar, UI optimista) + caché de lecturas vía Riverpod. **No**
    offline-first bidireccional completo (over-engineering para el dominio).

11. **Repo único** (`/app` Flutter + `/supabase` migraciones+Edge Functions).
    **Arquitectura: FSD adaptado lean** — 4 capas `app / features / entities / shared`
    con dirección de imports forzada por **`custom_lint`** y sin imports entre slices
    hermanos. Segments por slice: `ui` · `model` (Riverpod) · `data` (repos → Supabase).
    Se descartó FSD canónico (7 capas): `processes` deprecada, `pages` redundante con
    go_router, y `widgets` como capa choca con la nomenclatura de Flutter.

12. **Entornos + CI/CD:** 3 entornos (`local` Supabase CLI/Docker, `staging`, `prod`),
    migraciones SQL versionadas aplicadas por **Supabase CLI** en CI, flavors Flutter con
    `--dart-define`. **GitHub Actions** para lint/custom_lint/tests/deploy de migraciones;
    **Codemagic** para build/firma/distribución mobile (TestFlight / Play Internal).

13. **Observabilidad: solo Sentry** (errores cliente + Edge Functions). Analytics de
    producto fuera del MVP.

14. **Testing (pirámide por costo de bug):** fuerte en **unit de dominio** (máquina de
    estados 3-de-4, balanceo del sorteo) y **RLS/RPC con pgTAP**; liviano en widget tests
    y `integration_test` (signup, cargar→validar). Sin perseguir % de cobertura.

## Plan / Next steps

1. Scaffolding del repo: `/app` (Flutter, flavors) + `/supabase` (CLI init, migraciones,
   Edge Functions).
2. Definir el DS: `ThemeData`/`ColorScheme`/`TextTheme` con verde lima + Barlow Condensed
   (extraer color exacto y fuente del diseño `PadelAPP Screens.dc.html`).
3. Modelar el schema inicial + RLS + RPC de validación 3-de-4 (con pgTAP).
4. Configurar `custom_lint` con las reglas de fronteras FSD.
5. Auth (email + Apple + Google) y flujo de signup.
6. Importar/implementar el diseño `PadelAPP Screens.dc.html` → widgets Flutter
   (en sesión nueva; requiere el MCP de diseño, hoy no conectado).

## Supuestos y tradeoffs (elegido vs descartado)

- **Flutter** ✅ vs React Native/Expo ❌ (RN incompatible con la elección) vs nativo puro ❌.
- **Supabase all-in** ✅ vs Supabase+Node ❌ (un servicio más) vs Node puro+Postgres ❌
  vs Firebase ❌ (NoSQL, dominio relacional) vs Dart/Serverpod ❌ (ecosistema chico).
- **DS propio (ThemeData+M3)** ✅ vs Tailwind ❌ (no aplica a Flutter) vs Material/Cupertino
  puros sin tokens ❌.
- **Riverpod** ✅ vs Bloc ❌ (más ceremonia) vs Provider ❌.
- **go_router** ✅ vs Navigator 2.0 a mano ❌ vs auto_route ❌.
- **FSD adaptado lean** ✅ vs FSD canónico ❌ (capas tóxicas/redundantes en Flutter) vs
  feature-first plano ❌ (sin hogar para entidades compartidas → basurero o acoplamiento).
- **FCM** ✅ vs OneSignal ❌ (tercero extra).
- **Offline pragmático** ✅ vs online-only ❌ vs offline-first completo ❌.
- **Codemagic** ✅ vs Fastlane en GitHub Actions ❌ (más setup de signing).
- **Solo Sentry** ✅; PostHog/analytics ⏸️ fuera del MVP.
- **Shorebird (OTA)** ⏸️ anotado para fase 2 (no crítico en MVP; límites: solo Dart).

## Fase 2 (anotado, fuera del MVP)

- Carga de resultado **punto a punto en vivo**.
- **ELO / ranking** por resultados (ajuste automático de nivel).
- **Shorebird** (OTA code push).
- **PostHog** / analytics de producto.

## Preguntas abiertas

1. **i18n / idioma:** ¿solo español o multi-idioma desde el inicio? (no discutido)
2. **Versiones mínimas de OS** (iOS / Android) objetivo. (no discutido)
3. **Color exacto del verde lima** y assets de Barlow Condensed — pendientes de extraer
   del diseño `PadelAPP Screens.dc.html`.
4. **Modelo de "amigos":** ¿solicitud bidireccional (aceptar) o follow unidireccional?
5. **Sorteo:** criterio exacto de balanceo por nivel (definido conceptualmente, falta el
   algoritmo).
6. **Import del diseño:** el MCP `claude_design` no está conectado en esta sesión; el
   import/implementación de `PadelAPP Screens.dc.html` queda para una sesión nueva.
