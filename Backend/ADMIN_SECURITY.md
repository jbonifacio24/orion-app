# Admin security bootstrap

Fase 15.0 uses ASP.NET Identity as the only authorization source for the `Admin` role. The domain `Role` and `UserRole` tables are not consulted or synchronized.

At application startup the API creates the Identity role `Admin` if it does not exist. This operation is idempotent and does not create a user or password.

To assign the first administrator, configure an existing Identity user's email through the environment or user secrets:

```text
AdminBootstrap__UserEmail=existing-user@example.com
```

The user must already exist. If the setting is absent, the role is still created but no user is elevated. If the configured user does not exist, startup logs a warning and creates no account.

The role assignment is audited without an actor because startup has no authenticated human actor. Passwords, access tokens, refresh tokens, authorization headers and secrets are never accepted as audit payloads.

Administrative access is currently exposed only through `GET /api/admin/access`, protected by the `AdminAccess` policy. Existing access tokens may retain their old role claims until expiration; refresh tokens are revoked when sessions must be invalidated.