import 'package:flutter/material.dart';

const String kLocationPermissionRationale =
    'We use your location to help set the delivery address accurately and assist the courier in reaching you.';

Future<bool> showLocationPermissionRationaleDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Location Permission'),
        content: const Text(kLocationPermissionRationale),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue'),
          ),
        ],
      );
    },
  );

  return result ?? false;
}
