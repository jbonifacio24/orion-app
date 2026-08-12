# MotoHub

MotoHub is a multiplatform application for motorcycle users.

## FASE 1

This repository currently contains the project foundation only:

- Flutter application in `frontend/` using Clean Architecture, Material 3, BLoC/Cubit, GetIt, Dio and GoRouter.
- ASP.NET Core solution in `Backend/` split into Domain, Application, Infrastructure and Api.
- No business features are implemented.

## Validation

From `frontend/`:

```text
flutter pub get
flutter analyze
flutter test
```

From the repository root:

```text
dotnet build MotoHub.sln
```
