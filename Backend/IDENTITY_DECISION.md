# Identity decision

## Decision

MotoHub will use ASP.NET Core Identity in the authentication phase, with a custom `User` domain entity kept independent from Identity's persistence model.

The infrastructure layer will own the adapter between the Identity user/store model and the domain `User`. Password hashes, security stamps, login lockout data and Identity role data will not be added to the domain entity.

## Scope boundary

FASE 2 defines persistence entities and relationships only. It does not register Identity, authentication middleware, JWT handlers, login endpoints or password workflows.

## Consequences

- The current `User`, `Role`, `UserRole` and `RefreshToken` entities remain valid for the database foundation.
- Identity integration must be introduced through Infrastructure adapters in the authentication phase.
- Passwords and password hashes must never be stored in the current domain model.
- The authentication phase must decide whether Identity tables replace the current user tables or are introduced through a controlled migration before implementation.
