import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/biometric_guard.dart';
import '../../core/security/collection_lock_service.dart';

Future<bool> ensureCollectionLockPinConfigured(
  BuildContext context,
  WidgetRef ref,
) async {
  final lockService = ref.read(collectionLockServiceProvider);
  if (await lockService.hasPin()) return true;
  if (!context.mounted) return false;

  final firstController = TextEditingController();
  final secondController = TextEditingController();
  String? errorText;

  final created = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Set lock PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create a 4-digit PIN for private collections. You can reset it from settings.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: firstController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'PIN',
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: secondController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Confirm PIN',
                counterText: '',
              ),
            ),
            if (errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                errorText!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final first = firstController.text.trim();
              final second = secondController.text.trim();
              if (!lockService.isValidPin(first)) {
                setDialogState(
                  () => errorText = 'PIN must be exactly 4 digits.',
                );
                return;
              }
              if (first != second) {
                setDialogState(() => errorText = 'PINs do not match.');
                return;
              }
              await lockService.setPin(first);
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Set PIN'),
          ),
        ],
      ),
    ),
  );

  firstController.dispose();
  secondController.dispose();
  return created == true;
}

Future<bool> authenticateCollectionUnlock(
  BuildContext context,
  WidgetRef ref, {
  required String reason,
}) async {
  final biometricGuard = ref.read(biometricGuardProvider);
  final canBiometric = await biometricGuard.canUseBiometrics();

  // Fallback to in-app PIN
  final lockService = ref.read(collectionLockServiceProvider);
  final hasPin = await lockService.hasPin();
  if (!context.mounted) return false;
  if (!hasPin) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No PIN is set. Set a lock PIN from settings to use private collections.',
          ),
        ),
      );
    }
    return false;
  }

  final pinController = TextEditingController();
  String? errorText;

  final unlocked = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unlock with PIN',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text('Enter your 4-digit PIN to unlock this collection.'),
              const SizedBox(height: 12),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'PIN',
                  counterText: '',
                  errorText: errorText,
                  errorMaxLines: 2,
                ),
                onSubmitted: (_) async {
                  final pin = pinController.text.trim();
                  final valid = await lockService.verifyPin(pin);
                  if (valid) {
                    if (!sheetContext.mounted) return;
                    Navigator.pop(sheetContext, true);
                    return;
                  }
                  setSheetState(() => errorText = 'Incorrect PIN.');
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final pin = pinController.text.trim();
                    final valid = await lockService.verifyPin(pin);
                    if (valid) {
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext, true);
                      return;
                    }
                    setSheetState(() => errorText = 'Incorrect PIN.');
                  },
                  child: const Text('Unlock'),
                ),
              ),
              if (canBiometric)
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () async {
                      final unlocked = await biometricGuard.authenticate(
                        reason: reason,
                        biometricOnly: true,
                      );
                      if (unlocked && sheetContext.mounted) {
                        Navigator.pop(sheetContext, true);
                      }
                    },
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Use Fingerprint'),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  pinController.dispose();
  if (unlocked == true) return true;
  return false;
}
