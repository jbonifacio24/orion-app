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

## Google Sign-In

The login screen supports Google on Flutter Web and Android. The public client ID is configured in `frontend/lib/core/constants/environment_config.dart` and `Backend/MotoHub.Api/appsettings.Development.json`. Register every Web origin in Google Cloud, including `http://localhost:3000` and `http://localhost:8080` for local development, plus the deployed site origin.

Run Flutter Web normally:

```text
cd frontend
flutter run -d chrome --web-port=8080
```

For Android, create an Android OAuth client in Google Cloud with application ID `com.example.motohub` and the SHA-1 fingerprints for each signing key (debug and release). The API uses the Web client ID as the expected ID-token audience.

Google sign-in links a verified Google email to an existing MotoHub account with the same email. New Google users receive a MotoHub profile and the default `User` role. The existing password login remains available.
