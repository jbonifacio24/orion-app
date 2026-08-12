sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;
}

final class NetworkException extends AppException {
  const NetworkException(super.message);
}

final class UnknownException extends AppException {
  const UnknownException(super.message);
}
