sealed class AppFailure implements Exception {
  const AppFailure(this.message);

  final String message;
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}

final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure(super.message);
}

final class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure(super.message);
}

final class ConflictFailure extends AppFailure {
  const ConflictFailure(super.message);
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure(super.message);
}

final class RateLimitFailure extends AppFailure {
  const RateLimitFailure(super.message);
}

final class ServerFailure extends AppFailure {
  const ServerFailure(super.message);
}

final class ServiceUnavailableFailure extends AppFailure {
  const ServiceUnavailableFailure(super.message);
}

final class TimeoutFailure extends AppFailure {
  const TimeoutFailure(super.message);
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message);
}

final class SerializationFailure extends AppFailure {
  const SerializationFailure(super.message);
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure(super.message);
}