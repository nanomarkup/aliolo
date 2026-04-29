import 'package:dio/dio.dart';

String formatApiErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is DioException) {
    final backendError = _extractBackendError(error.response?.data);
    if (backendError != null && backendError.isNotEmpty) {
      return backendError;
    }

    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      switch (statusCode) {
        case 400:
          return 'The request could not be completed.';
        case 401:
          return 'You are not signed in.';
        case 403:
          return 'You do not have permission to do that.';
        case 404:
          return 'The requested item was not found.';
        case 408:
          return 'The request timed out. Please try again.';
      }

      if (statusCode >= 500) {
        return 'The server is unavailable right now. Please try again.';
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The request timed out. Please try again.';
      case DioExceptionType.connectionError:
        return 'Network error. Check your connection and try again.';
      case DioExceptionType.cancel:
        return 'The request was canceled.';
      case DioExceptionType.badCertificate:
        return 'A secure connection could not be established.';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    if (error.message != null && error.message!.trim().isNotEmpty) {
      return error.message!.trim();
    }

    return fallback;
  }

  return fallback;
}

String? _extractBackendError(dynamic data) {
  if (data is Map && data['error'] != null) {
    return data['error'].toString().trim();
  }
  if (data is String && data.trim().isNotEmpty) {
    return data.trim();
  }
  return null;
}
