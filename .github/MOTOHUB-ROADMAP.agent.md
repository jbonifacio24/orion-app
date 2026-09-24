# MotoHub Development Roadmap

## Estado

FASE 1  — Foundation                  ✅
FASE 2  — Database / Entities         ✅
FASE 3  — Authentication              ✅
FASE 4  — Flutter Foundation          ✅
FASE 5  — Profile / Motorcycles       ✅
FASE 6  — Marketplace                 ✅
FASE 7  — Workshops + Map             ✅

FASE 8  — Theft System                ⏳
FASE 9  — Notifications               ⏳
FASE 10 — SignalR Chat                ⏳
FASE 11 — Community                   ⏳
FASE 12 — News                        ⏳
FASE 13 — Referrals                   ⏳
FASE 14 — VIP                         ⏳
FASE 15 — Administration              ⏳
FASE 16 — Testing                     ⏳
FASE 17 — Docker                      ⏳
FASE 18 — Optimization & Security     ⏳


# FASE 8 — THEFT SYSTEM

Objetivo:
Sistema de reporte de motos robadas.

Entidades existentes a inspeccionar:
- TheftReport
- TheftAlertRecipient
- Motorcycle
- User

El Architect debe determinar el alcance real después de inspeccionar
el repositorio.

Posible división:

8A — Backend
8B — Flutter

IMPORTANTE:
Esta división no se considera aprobada hasta el análisis del Architect.


# FASE 9 — NOTIFICATIONS

Objetivo:
Sistema de notificaciones de MotoHub.

Revisar integración con:
- Theft System
- usuarios
- Notification existente
- futuras notificaciones push

Posible división:

9A — Backend
9B — Flutter
9C — Push notifications

El Architect determinará la división definitiva.


# FASE 10 — SIGNALR CHAT

Objetivo:
Mensajería en tiempo real.

Revisar:
- Conversation
- ConversationParticipant
- Message
- MessageAttachment
- SignalR
- autenticación JWT

Posible división:

10A — Backend Chat
10B — SignalR
10C — Flutter Chat


# FASE 11 — COMMUNITY

Objetivo:
Comunidad de motociclistas.

Revisar:
- Post
- PostComment
- PostLike
- User

Posible división:

11A — Backend
11B — Flutter


# FASE 12 — NEWS

Objetivo:
Noticias para la comunidad.

Revisar:
- News
- NewsCategory

Posible división:

12A — Backend
12B — Flutter


# FASE 13 — REFERRALS

Objetivo:
Sistema de referidos y recompensas.

Revisar:
- Referral
- ReferralReward

Posible división:

13A — Backend
13B — Flutter


# FASE 14 — VIP

Objetivo:
Sistema de usuarios/suscripciones VIP.

Revisar:
- Subscription
- roles/claims
- funcionalidades premium

Posible división:

14A — Backend
14B — Flutter


# FASE 15 — ADMINISTRATION

Objetivo:
Administración de MotoHub.

El Architect debe analizar qué funciones administrativas son necesarias
según las funcionalidades realmente implementadas en fases anteriores.

Puede incluir administración de:

- usuarios;
- talleres;
- marketplace;
- reportes;
- noticias;
- contenido;
- suscripciones;
- moderación.

No implementar automáticamente todo lo anterior.
El Architect define el scope.


# FASE 16 — TESTING

Objetivo:
Revisión global de cobertura y calidad.

Analizar:

- Unit tests
- Integration tests
- Functional tests
- Widget tests
- API tests
- Auth
- Marketplace
- Workshops
- Theft
- Notifications
- Chat
- Community
- etc.

El Architect debe identificar gaps reales antes de añadir tests.


# FASE 17 — DOCKER

Objetivo:
Containerización del sistema.

Analizar primero:

- Backend/API
- base de datos
- configuración
- secrets
- environments
- Dockerfile
- Docker Compose
- health checks
- volumes
- networking

No crear infraestructura hasta aprobar arquitectura.


# FASE 18 — OPTIMIZATION & SECURITY

Objetivo:
Hardening y optimización final.

Revisar:

- Authentication
- Authorization
- JWT
- Refresh tokens
- rate limiting
- CORS
- headers
- secrets
- logging
- validation
- database indexes
- query performance
- pagination
- caching
- concurrency
- uploads
- OWASP
- dependencies
- Flutter security
- performance

No cambiar arquitectura sin análisis previo.


# REGLA PARA TODAS LAS FASES

Cada fase comienza SIEMPRE con:

@motohub-architect

El Architect:

1. inspecciona el repositorio REAL;
2. determina qué ya existe;
3. determina qué falta;
4. propone subfases;
5. propone Backend/Flutter;
6. analiza entidades y contratos;
7. analiza seguridad;
8. propone tests;
9. identifica riesgos;
10. propone archivos a crear/modificar.

El Architect no implementa cuando existe una decisión arquitectónica
bloqueante o una ambigüedad que requiere decisión del usuario.

Si no existe una decisión bloqueante, el Developer puede continuar
automáticamente con la implementación aprobada por el alcance solicitado.


# WORKFLOW OBLIGATORIO

Para CADA fase/subfase:

ARCHITECT
↓
DECISIÓN ARQUITECTÓNICA SIN BLOQUEO
↓
DEVELOPER AUTOMÁTICAMENTE
↓
VALIDATION
↓
CODE REVIEW
↓
CORRECTIONS
↓
VALIDATION
↓
FINAL CODE REVIEW
↓
USER COMMIT/PUSH
↓
STOP


# REGLA DE AVANCE

Nunca avanzar automáticamente a la siguiente fase.

Ejemplo:

FASE 8A aprobada
≠ autorización para FASE 8B.

FASE 8 completa
≠ autorización para FASE 9.

Siempre esperar instrucción explícita del usuario.


# REGLA DE SCOPE

El roadmap define intención, NO implementación definitiva.

El estado REAL del repositorio es la fuente de verdad.

Si existe conflicto entre este roadmap y el código real, o una decisión
arquitectónica bloqueante:

1. detener implementación;
2. reportar la diferencia;
3. Architect propone solución;
4. esperar decisión explícita del usuario.


# GIT

Los agentes NO deben ejecutar automáticamente:

git commit
git push

Después de Code Review aprobado:

reportar un commit message sugerido y detenerse.

El usuario controla el commit/push.