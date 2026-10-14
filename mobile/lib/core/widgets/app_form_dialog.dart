import 'package:flutter/material.dart';

/// Returns after the dialog and its closing transition have been removed.
///
/// Callers can then read and dispose their text controllers without a closing
/// TextField trying to listen to an already disposed controller.
Future<T?> showAppFormDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
  );
  final result = await navigator.push<T>(route);
  await route.completed;
  return result;
}
