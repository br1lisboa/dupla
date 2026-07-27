# PadelAPP — Descomposición en specs (etapas)

**Date:** 2026-07-18

## Resumen

Sesión de grill para cortar el árbol de decisiones cerrado en
`01-stack-arquitectura-fundamentos.md` en **specs ejecutables**. No se
tomaron decisiones de stack nuevas: se definió *cómo* dividir en etapas para
empezar a escribir specs, el orden por dependencias, dónde aterrizan los temas
transversales, y dónde se resuelve cada pregunta abierta del grill 01.

## Decisiones clave

1. **Estrategia de corte: híbrido (horizontal primero, luego vertical).**
   Los cimientos que no son feature y bloquean todo van como specs
   horizontales (por capa). Recién sobre esa losa, las features se especifican
   verticales (end-to-end, atravesando su rebanada FSD). Razón: una feature
   vertical no puede arrancar sin schema ni theme; forzar todo vertical desde
   el día 1 cargaría deuda de cimientos en las primeras specs.

2. **Losa horizontal = 3 specs (02, 03, 04).** Los transversales de config
   (custom_lint, CI mínima) viven **dentro** del scaffolding, no como spec
   suelta.

3. **Features verticales = 05–09.** Cada tema transversal (push FCM, deep
   linking, offline queue) **aterriza en la feature que lo estrena**, no como
   spec de infraestructura huérfana.

4. **Jugador-mínimo en el sorteo (06).** Los 4 jugadores del partido se
   seleccionan por **búsqueda simple de usuarios** (nombre/email), sin
   depender del grafo de amigos. Esto **desacopla 06 de 09** y preserva el
   orden. El grafo social rico (09) luego enchufa "elegir desde amigos" como
   atajo sobre el selector ya existente.

5. **CI/CD crece por spec.** Arranca mínima en la 02 (lint + test) y cada spec
   agrega lo suyo. No es una spec monolítica al final.

## Plan / Secuencia de specs

### Losa horizontal (cimientos)

- **`02-scaffolding-y-entornos`** — repo `/app` (Flutter, flavors
  `--dart-define`) + `/supabase` (CLI init), 3 entornos (local Docker /
  staging / prod), **custom_lint con reglas de fronteras FSD**, esqueleto CI
  (lint + test). *Bloquea todo lo demás → primera.*
- **`03-nucleo-dominio`** — schema (`matches`, `match_players`,
  `match_results`, `result_validations`, `device_tokens`), RLS, RPC de
  validación **3-de-4** + pgTAP. *Corazón del dato; todas las features
  verticales dependen de estas tablas.*
- **`04-design-system`** — `ThemeData`/`ColorScheme`/`TextTheme`, verde lima +
  Barlow Condensed, componentes base. *Bloquea toda UI; puede ir en paralelo a
  la 03 (no se bloquean entre sí).*

### Features verticales

- **`05-auth-y-signup`** — email+password (verificación) + Sign in with Apple +
  Google; flujo signup (email→datos→nivel); **gate de navegación go_router**
  (redirect por estado de auth). *Sin sesión no hay nada → primera vertical.*
- **`06-partido-y-sorteo`** — crear partido 2v2, **selector de jugadores por
  búsqueda** (jugador-mínimo), sorteo con balanceo por nivel + animación.
  *Depende sólo de que existan usuarios (05).*
- **`07-cargar-y-validar`** — cargar marcador por sets, máquina de estados
  **3-de-4**, **push FCM** (primer uso real), **deep linking** (push→pantalla
  validación), **offline queue** (cargar resultado sin señal → sync). *Corazón
  funcional; acá aterrizan push + deeplink + offline juntos.*
- **`08-stats-e-historial`** — agregación vía RPC, dashboard, historial.
  *Depende de tener resultados `validated`.*
- **`09-amigos-y-perfil`** — grafo de amigos (modelo a decidir), perfil,
  config; enchufa "elegir desde amigos" sobre el selector de 06. *Menos
  acoplado; puede ir más tarde o en paralelo.*

## Mapeo de preguntas abiertas (grill 01) → spec dueña

| Pregunta abierta | Se decide en | ¿Bloquea? |
|---|---|---|
| i18n / multi-idioma (`flutter_localizations` sí/no) | **02** | Sí (leve) — decidir en 02 para evitar retrofit |
| Versiones mínimas OS (iOS/Android) | **02** | Sí (leve) — config del esqueleto |
| Verde lima exacto + assets Barlow (extraer del `.pen`) | **04** | No |
| Modelo amigos (bidireccional vs follow) | **09** | No |
| Algoritmo exacto de balanceo del sorteo | **06** | No |
| Import diseño `.pen` (MCP pencil) | transversal UI (04/06/07…) | No — requiere MCP pencil conectado |

Nada bloquea el arranque salvo **i18n** y **versiones mínimas OS**, que se
resuelven *dentro* de la 02 (son config del esqueleto), no antes.

## Supuestos y tradeoffs (elegido vs descartado)

- **Híbrido horizontal→vertical** ✅ vs todo-vertical desde día 1 ❌ (deuda de
  cimientos en specs iniciales) vs todo-horizontal ❌ (valor funcional tardío).
- **custom_lint dentro de 02** ✅ vs spec propia ❌ (es config, no feature).
- **CI/CD incremental por spec** ✅ vs spec monolítica de CI al final ❌.
- **Jugador-mínimo en 06 (buscador plano)** ✅ vs mover amigos (09) antes del
  sorteo ❌ (reordena la secuencia y acopla 06→09). Tradeoff: selector crudo en
  el MVP de 06, mejorado luego por 09.
- **Transversales aterrizan en su feature** ✅ vs specs de infraestructura
  sueltas (push/deeplink/offline) ❌ (huérfanas, sin dueño funcional).
- **03 y 04 en paralelo** ✅ (no se bloquean) vs estrictamente secuencial ❌.

## Próximo paso

Escribir la **spec `02-scaffolding-y-entornos`** (primera de la losa), cerrando
en ella las dos decisiones que bloquean: i18n y versiones mínimas de OS.

## Preguntas abiertas

Ninguna nueva. Las heredadas del grill 01 quedan asignadas a su spec dueña
(ver tabla de mapeo) y se resuelven al llegar a esa spec.
