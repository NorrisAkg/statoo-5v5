import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/shared_http_error.dart';
import '../../team/application/team_provider.dart';
import '../domain/password_policy.dart';
import '../domain/recovery_code.dart';
import 'shared_providers.dart';

enum RecoveryStep {
  idle,
  submitting,
  awaitingConfirmation,
  establishingSession,
  completed,
  error,
}

const Object _sentinel = Object();

class RecoveryState {
  const RecoveryState({
    this.step = RecoveryStep.idle,
    this.newRecoveryCode,
    this.sessionResult,
    this.errorMessage,
  });

  const RecoveryState.initial() : this();

  final RecoveryStep step;
  final String? newRecoveryCode;
  final Map<String, dynamic>? sessionResult;
  final String? errorMessage;

  bool get isLoading =>
      step == RecoveryStep.submitting ||
      step == RecoveryStep.establishingSession;

  RecoveryState copyWith({
    RecoveryStep? step,
    Object? newRecoveryCode = _sentinel,
    Object? sessionResult = _sentinel,
    Object? errorMessage = _sentinel,
  }) =>
      RecoveryState(
        step: step ?? this.step,
        newRecoveryCode: identical(newRecoveryCode, _sentinel)
            ? this.newRecoveryCode
            : newRecoveryCode as String?,
        sessionResult: identical(sessionResult, _sentinel)
            ? this.sessionResult
            : sessionResult as Map<String, dynamic>?,
        errorMessage: identical(errorMessage, _sentinel)
            ? this.errorMessage
            : errorMessage as String?,
      );
}

class RecoveryController extends Notifier<RecoveryState> {
  String? _lastUrl;

  @override
  RecoveryState build() => const RecoveryState.initial();

  Future<bool> submitRecovery({
    required String url,
    required String groupId,
    required String username,
    required String recoveryCode,
    required String newPassword,
    required String confirmPassword,
  }) async {
    _lastUrl = url;

    final trimmedCode = recoveryCode.trim();
    final normalizedCode = RecoveryCode.normalize(trimmedCode);
    if (trimmedCode.isEmpty || !RecoveryCode.isValid(normalizedCode)) {
      state = state.copyWith(
        step: RecoveryStep.error,
        errorMessage: 'Code de récupération invalide ou incomplet.',
        sessionResult: null,
        newRecoveryCode: null,
      );
      return false;
    }

    if (newPassword != confirmPassword) {
      state = state.copyWith(
        step: RecoveryStep.error,
        errorMessage: 'Les mots de passe ne correspondent pas.',
        sessionResult: null,
        newRecoveryCode: null,
      );
      return false;
    }

    final passwordResult = PasswordPolicy.validate(
      newPassword,
      username: username,
    );
    if (!passwordResult.isValid) {
      state = state.copyWith(
        step: RecoveryStep.error,
        errorMessage:
            'Le mot de passe ne respecte pas les critères de sécurité.',
        sessionResult: null,
        newRecoveryCode: null,
      );
      return false;
    }

    String newRecoveryCode;
    do {
      newRecoveryCode = RecoveryCodeGenerator.generate();
    } while (RecoveryCode.normalize(newRecoveryCode) == normalizedCode);

    state = state.copyWith(
      step: RecoveryStep.submitting,
      errorMessage: null,
      sessionResult: null,
      newRecoveryCode: null,
    );

    try {
      final sharedService = ref.read(sharedServiceProvider);
      final formattedNormalizedCode = RecoveryCode.format(normalizedCode);
      final result = await sharedService.recover(
        url: url,
        groupId: groupId,
        username: username,
        recoveryCode: formattedNormalizedCode,
        newPassword: newPassword,
        newRecoveryCode: newRecoveryCode,
      );

      state = state.copyWith(
        step: RecoveryStep.awaitingConfirmation,
        newRecoveryCode: newRecoveryCode,
        sessionResult: result,
        errorMessage: null,
      );
      return true;
    } on SharedApiException catch (e) {
      state = state.copyWith(
        step: RecoveryStep.error,
        errorMessage: e.message.isNotEmpty ? e.message : 'Erreur API',
        sessionResult: null,
        newRecoveryCode: null,
      );
      return false;
    } on SharedNetworkException catch (e) {
      state = state.copyWith(
        step: RecoveryStep.error,
        errorMessage: e.toString(),
        sessionResult: null,
        newRecoveryCode: null,
      );
      return false;
    } on Object catch (e) {
      state = state.copyWith(
        step: RecoveryStep.error,
        errorMessage: e.toString(),
        sessionResult: null,
        newRecoveryCode: null,
      );
      return false;
    }
  }

  Future<void> confirmCodeAndConnect() async {
    if (state.step != RecoveryStep.awaitingConfirmation ||
        state.sessionResult == null) {
      throw StateError('Aucune session en attente de confirmation.');
    }

    state = state.copyWith(
      step: RecoveryStep.establishingSession,
      errorMessage: null,
    );

    try {
      final sharedService = ref.read(sharedServiceProvider);
      await sharedService.establishSession(_lastUrl ?? '', state.sessionResult!);

      final targetGroup = state.sessionResult!['group_id'] as String?;
      if (targetGroup != null) {
        final teamRepo = ref.read(teamRepositoryProvider);
        final team = await teamRepo.getTeamById(targetGroup);
        if (team != null) {
          await ref.read(activeTeamIdProvider.notifier).selectTeam(targetGroup);
        }
      }

      ref.read(sharedStatusProvider.notifier).refresh();

      state = state.copyWith(
        step: RecoveryStep.completed,
        errorMessage: null,
      );
    } on Object catch (e) {
      state = state.copyWith(
        step: RecoveryStep.error,
        errorMessage: e is SharedNetworkException
            ? e.toString()
            : e is SharedApiException
                ? e.message
                : e.toString(),
      );
    }
  }

  void reset() {
    state = const RecoveryState.initial();
  }
}

final recoveryControllerProvider =
    NotifierProvider<RecoveryController, RecoveryState>(
      RecoveryController.new,
    );
