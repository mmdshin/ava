import 'package:flutter/material.dart';
import 'package:ava_web/data/api_client.dart';

/// App-wide snackbars, usable from providers (no BuildContext needed).
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showAppMessage(String message) {
  appMessengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Shows a friendly message for an error from the server.
void showApiError(Object error) {
  showAppMessage(
    error is ApiException
        ? error.userMessage
        : const ApiException(0, 'error').userMessage,
  );
}
