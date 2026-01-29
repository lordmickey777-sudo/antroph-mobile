import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antroph_mobile/core/auth/state/auth_state.dart';
import 'package:antroph_mobile/core/auth/widgets/auth_sheet_content.dart';
import 'package:antroph_mobile/widgets/app_bottom_sheet.dart';

/// Result of an auth guard check.
enum AuthGuardResult {
  /// User was already authenticated.
  authenticated,

  /// User successfully logged in via the sheet.
  loginSuccessful,

  /// User chose to continue as guest (action should be blocked).
  guestContinue,

  /// User dismissed the sheet without action.
  dismissed,
}

/// Shows an authentication sheet if the user is not authenticated.
///
/// Returns [AuthGuardResult.authenticated] immediately if user is already logged in.
/// Otherwise shows a login/signup sheet and returns the appropriate result.
///
/// [actionDescription] is shown in the sheet header, e.g. "add stories to your playlist"
Future<AuthGuardResult> showAuthGuardSheet(
  BuildContext context,
  WidgetRef ref, {
  String? actionDescription,
}) async {
  // Check if already authenticated
  final authState = ref.read(authControllerProvider);
  if (authState.value != null) {
    return AuthGuardResult.authenticated;
  }

  // Show the auth sheet
  final result = await showAppBottomSheet<AuthGuardResult>(
    context: context,
    enableDrag: true,
    builder: (context, scrollController) => AuthSheetContent(
      actionDescription: actionDescription,
      scrollController: scrollController,
    ),
  );

  return result ?? AuthGuardResult.dismissed;
}

/// Helper to wrap an async action with auth guard.
///
/// If authenticated, executes the action and returns its result.
/// If not authenticated, shows the auth sheet and only executes
/// the action if login is successful.
///
/// Returns null if user continues as guest or dismisses.
Future<T?> withAuthGuard<T>({
  required BuildContext context,
  required WidgetRef ref,
  required Future<T> Function() action,
  String? actionDescription,
}) async {
  final result = await showAuthGuardSheet(
    context,
    ref,
    actionDescription: actionDescription,
  );

  if (result == AuthGuardResult.authenticated ||
      result == AuthGuardResult.loginSuccessful) {
    return action();
  }

  return null;
}
