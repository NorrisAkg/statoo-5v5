
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/data/shared_http_error.dart';
import 'package:statoo/features/shared/application/recovery_controller.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/shared/data/shared_service.dart';
import 'package:statoo/features/shared/domain/recovery_code.dart';
import 'package:statoo/features/team/application/team_provider.dart';
import 'package:statoo/features/team/data/team_repository.dart';
import 'package:statoo/features/team/domain/team_info.dart';

class FakeSharedService extends SharedService {
  FakeSharedService({
    required AppDatabase database,
    FlutterSecureStorage? storage,
  }) : super(database, storage: storage);

  Map<String, dynamic> Function({
    required String url,
    required String groupId,
    required String username,
    required String recoveryCode,
    required String newPassword,
    required String newRecoveryCode,
  })? onRecover;

  Future<void> Function(String url, Map<String, dynamic> sessionResult)?
      onEstablishSession;

  int recoverCallCount = 0;
  int establishSessionCallCount = 0;

  Map<String, dynamic>? lastRecoverParams;
  Map<String, dynamic>? lastEstablishSessionParams;

  @override
  Future<Map<String, dynamic>> recover({
    required String url,
    required String groupId,
    required String username,
    required String recoveryCode,
    required String newPassword,
    required String newRecoveryCode,
  }) async {
    recoverCallCount++;
    lastRecoverParams = <String, dynamic>{
      'url': url,
      'groupId': groupId,
      'username': username,
      'recoveryCode': recoveryCode,
      'newPassword': newPassword,
      'newRecoveryCode': newRecoveryCode,
    };
    if (onRecover != null) {
      return onRecover!(
        url: url,
        groupId: groupId,
        username: username,
        recoveryCode: recoveryCode,
        newPassword: newPassword,
        newRecoveryCode: newRecoveryCode,
      );
    }
    return <String, dynamic>{
      'token': 'test_jwt_token',
      'expires_at':
          DateTime.now().add(const Duration(days: 1)).toUtc().toIso8601String(),
      'group_id': groupId,
      'account': <String, dynamic>{
        'id': 'acc_1',
        'username': username,
        'roles': <String>['ADMIN'],
      },
      'recovery_rotated': true,
    };
  }

  @override
  Future<void> establishSession(
    String url,
    Map<String, dynamic> sessionResult,
  ) async {
    establishSessionCallCount++;
    lastEstablishSessionParams = <String, dynamic>{
      'url': url,
      'sessionResult': sessionResult,
    };
    if (onEstablishSession != null) {
      await onEstablishSession!(url, sessionResult);
      return;
    }
    identity = sessionResult;
    baseUrl = url;
    token = sessionResult['token'] as String?;
  }
}

class FakeTeamRepository implements TeamRepository {
  final Map<String, TeamInfo> teams = <String, TeamInfo>{};
  String? activeTeamId;

  @override
  Future<TeamInfo?> getTeamById(String id) async => teams[id];

  @override
  Future<List<TeamInfo>> getAllTeams() async => teams.values.toList();

  @override
  Future<TeamInfo?> getActiveTeam() async =>
      activeTeamId != null ? teams[activeTeamId] : null;

  @override
  Future<String?> getActiveTeamId() async => activeTeamId;

  @override
  Future<void> setActiveTeamId(String id) async {
    activeTeamId = id;
  }

  @override
  Future<TeamInfo?> getTeamInfo() => getActiveTeam();

  @override
  Future<void> saveTeamInfo(TeamInfo team) async {
    teams[team.id] = team;
  }

  @override
  Future<void> deleteTeam(String id) async {
    teams.remove(id);
    if (activeTeamId == id) activeTeamId = null;
  }

  @override
  Future<Map<String, int>> getTeamCounts(String teamId) async =>
      <String, int>{};
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('RecoveryController & Riverpod Integration', () {
    late ProviderContainer container;
    late FakeSharedService fakeSharedService;
    late FakeTeamRepository fakeTeamRepository;
    late Database rawDb;
    late AppDatabase appDb;

    setUp(() async {
      rawDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      appDb = AppDatabase.forTesting(rawDb);
      await appDb.initSchemaForTest(rawDb);

      fakeSharedService = FakeSharedService(database: appDb);
      fakeTeamRepository = FakeTeamRepository();

      container = ProviderContainer(
        overrides: [
          sharedServiceProvider.overrideWithValue(fakeSharedService),
          teamRepositoryProvider.overrideWithValue(fakeTeamRepository),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await rawDb.close();
    });

    group('RecoveryState - Initialisation et Helpers', () {
      test(
        'G-W-T 1.1: L’état initial est idle, isLoading == false, et tous les champs nulls',
        () {
          // Given / When
          final RecoveryState state =
              container.read(recoveryControllerProvider);

          // Then
          expect(state.step, equals(RecoveryStep.idle));
          expect(state.isLoading, isFalse);
          expect(state.newRecoveryCode, isNull);
          expect(state.sessionResult, isNull);
          expect(state.errorMessage, isNull);
        },
      );

      test(
        'G-W-T 1.2: isLoading retourne true uniquement pour submitting et establishingSession',
        () {
          // Given / When / Then
          expect(
            const RecoveryState().isLoading,
            isFalse,
          );
          expect(
            const RecoveryState(step: RecoveryStep.submitting).isLoading,
            isTrue,
          );
          expect(
            const RecoveryState(step: RecoveryStep.awaitingConfirmation)
                .isLoading,
            isFalse,
          );
          expect(
            const RecoveryState(step: RecoveryStep.establishingSession)
                .isLoading,
            isTrue,
          );
          expect(
            const RecoveryState(step: RecoveryStep.completed).isLoading,
            isFalse,
          );
          expect(
            const RecoveryState(step: RecoveryStep.error).isLoading,
            isFalse,
          );
        },
      );

      test(
        'G-W-T 1.3: copyWith permet la mise à jour granulaire de l’état',
        () {
          // Given
          const RecoveryState initial = RecoveryState.initial();

          // When
          final RecoveryState updated = initial.copyWith(
            step: RecoveryStep.submitting,
            errorMessage: 'Un message',
          );

          // Then
          expect(updated.step, equals(RecoveryStep.submitting));
          expect(updated.errorMessage, equals('Un message'));
          expect(updated.newRecoveryCode, isNull);
          expect(updated.sessionResult, isNull);
        },
      );
    });

    group('submitRecovery() - Validations Locales (Fast-Fail)', () {
      test(
        'G-W-T 2.1: Rejette un code de récupération vide sans appel réseau',
        () async {
          // Given / When
          final bool success = await container
              .read(recoveryControllerProvider.notifier)
              .submitRecovery(
                url: 'https://api.statoo.app',
                groupId: 'grp_1',
                username: 'alex',
                recoveryCode: '',
                newPassword: 'ValidPassword123!',
                confirmPassword: 'ValidPassword123!',
              );

          // Then
          expect(success, isFalse);
          final RecoveryState state =
              container.read(recoveryControllerProvider);
          expect(state.step, equals(RecoveryStep.error));
          expect(state.errorMessage, contains('Code de récupération'));
          expect(fakeSharedService.recoverCallCount, equals(0));
        },
      );

      test(
        'G-W-T 2.2: Rejette un code de récupération trop court sans appel réseau',
        () async {
          // Given / When
          final bool success = await container
              .read(recoveryControllerProvider.notifier)
              .submitRecovery(
                url: 'https://api.statoo.app',
                groupId: 'grp_1',
                username: 'alex',
                recoveryCode: '2345-6789',
                newPassword: 'ValidPassword123!',
                confirmPassword: 'ValidPassword123!',
              );

          // Then
          expect(success, isFalse);
          final RecoveryState state =
              container.read(recoveryControllerProvider);
          expect(state.step, equals(RecoveryStep.error));
          expect(state.errorMessage, contains('Code de récupération'));
          expect(fakeSharedService.recoverCallCount, equals(0));
        },
      );

      test(
        'G-W-T 2.3: Rejette un code avec caractères interdits sans appel réseau',
        () async {
          // Given (contient les caractères '0' et 'O' non conformes Crockford)
          const String invalidCharsCode = '0000-OOOO-2345-6789';

          // When
          final bool success = await container
              .read(recoveryControllerProvider.notifier)
              .submitRecovery(
                url: 'https://api.statoo.app',
                groupId: 'grp_1',
                username: 'alex',
                recoveryCode: invalidCharsCode,
                newPassword: 'ValidPassword123!',
                confirmPassword: 'ValidPassword123!',
              );

          // Then
          expect(success, isFalse);
          final RecoveryState state =
              container.read(recoveryControllerProvider);
          expect(state.step, equals(RecoveryStep.error));
          expect(fakeSharedService.recoverCallCount, equals(0));
        },
      );

      test(
        'G-W-T 2.4: Rejette un mismatch entre mot de passe et confirmation sans appel réseau',
        () async {
          // Given / When
          final bool success = await container
              .read(recoveryControllerProvider.notifier)
              .submitRecovery(
                url: 'https://api.statoo.app',
                groupId: 'grp_1',
                username: 'alex',
                recoveryCode: '2345-6789-ABCD-EFGH',
                newPassword: 'ValidPassword123!',
                confirmPassword: 'DifferentPassword456!',
              );

          // Then
          expect(success, isFalse);
          final RecoveryState state =
              container.read(recoveryControllerProvider);
          expect(state.step, equals(RecoveryStep.error));
          expect(state.errorMessage, contains('mots de passe'));
          expect(fakeSharedService.recoverCallCount, equals(0));
        },
      );

      test(
        'G-W-T 2.5: Rejette un mot de passe trop court (<8 chars) sans appel réseau',
        () async {
          // Given / When
          final bool success = await container
              .read(recoveryControllerProvider.notifier)
              .submitRecovery(
                url: 'https://api.statoo.app',
                groupId: 'grp_1',
                username: 'alex',
                recoveryCode: '2345-6789-ABCD-EFGH',
                newPassword: 'Ab1!',
                confirmPassword: 'Ab1!',
              );

          // Then
          expect(success, isFalse);
          final RecoveryState state =
              container.read(recoveryControllerProvider);
          expect(state.step, equals(RecoveryStep.error));
          expect(state.errorMessage, contains('critères de sécurité'));
          expect(fakeSharedService.recoverCallCount, equals(0));
        },
      );

      test(
        'G-W-T 2.6: Rejette un mot de passe sans majuscule sans appel réseau',
        () async {
          // Given / When
          final bool success = await container
              .read(recoveryControllerProvider.notifier)
              .submitRecovery(
                url: 'https://api.statoo.app',
                groupId: 'grp_1',
                username: 'alex',
                recoveryCode: '2345-6789-ABCD-EFGH',
                newPassword: 'secretpassword123!',
                confirmPassword: 'secretpassword123!',
              );

          // Then
          expect(success, isFalse);
          expect(
            container.read(recoveryControllerProvider).step,
            equals(RecoveryStep.error),
          );
          expect(fakeSharedService.recoverCallCount, equals(0));
        },
      );

      test(
        'G-W-T 2.7: Rejette un mot de passe sans minuscule sans appel réseau',
        () async {
          // Given / When
          final bool success = await container
              .read(recoveryControllerProvider.notifier)
              .submitRecovery(
                url: 'https://api.statoo.app',
                groupId: 'grp_1',
                username: 'alex',
                recoveryCode: '2345-6789-ABCD-EFGH',
                newPassword: 'SECRETPASSWORD123!',
                confirmPassword: 'SECRETPASSWORD123!',
              );

          // Then
          expect(success, isFalse);
          expect(
            container.read(recoveryControllerProvider).step,
            equals(RecoveryStep.error),
          );
          expect(fakeSharedService.recoverCallCount, equals(0));
        },
      );

      test(
        'G-W-T 2.8: Rejette un mot de passe sans chiffre sans appel réseau',
        () async {
          // Given / When
          final bool success = await container
              .read(recoveryControllerProvider.notifier)
              .submitRecovery(
                url: 'https://api.statoo.app',
                groupId: 'grp_1',
                username: 'alex',
                recoveryCode: '2345-6789-ABCD-EFGH',
                newPassword: 'SecretPasswordNoDigit!',
                confirmPassword: 'SecretPasswordNoDigit!',
              );

          // Then
          expect(success, isFalse);
          expect(
            container.read(recoveryControllerProvider).step,
            equals(RecoveryStep.error),
          );
          expect(fakeSharedService.recoverCallCount, equals(0));
        },
      );

      test(
        'G-W-T 2.9: Rejette un mot de passe identique au nom d’utilisateur sans appel réseau',
        () async {
          // Given / When
          final bool success = await container
              .read(recoveryControllerProvider.notifier)
              .submitRecovery(
                url: 'https://api.statoo.app',
                groupId: 'grp_1',
                username: 'alex1234',
                recoveryCode: '2345-6789-ABCD-EFGH',
                newPassword: 'Alex1234',
                confirmPassword: 'Alex1234',
              );

          // Then
          expect(success, isFalse);
          expect(
            container.read(recoveryControllerProvider).step,
            equals(RecoveryStep.error),
          );
          expect(fakeSharedService.recoverCallCount, equals(0));
        },
      );
    });

    group('submitRecovery() - Génération de Code & Appel Réseau', () {
      test(
        'G-W-T 3.1 - 3.4: Génère automatiquement un code, transite par submitting et atteint awaitingConfirmation',
        () async {
          // Given
          final List<RecoveryStep> observedSteps = <RecoveryStep>[];
          container.listen(
            recoveryControllerProvider,
            (_, next) => observedSteps.add(next.step),
            fireImmediately: true,
          );

          const String currentCode = '2345-6789-ABCD-EFGH';

          // When
          final bool success = await container
              .read(recoveryControllerProvider.notifier)
              .submitRecovery(
                url: 'https://api.statoo.app',
                groupId: 'grp_test',
                username: 'alex',
                recoveryCode: ' 2345 6789 abcd efgh ', // non normalisé
                newPassword: 'ValidPassword123!',
                confirmPassword: 'ValidPassword123!',
              );

          // Then
          expect(success, isTrue);
          expect(observedSteps, contains(RecoveryStep.submitting));
          expect(observedSteps.last, equals(RecoveryStep.awaitingConfirmation));

          final RecoveryState state =
              container.read(recoveryControllerProvider);
          expect(state.step, equals(RecoveryStep.awaitingConfirmation));
          expect(state.isLoading, isFalse);
          expect(state.errorMessage, isNull);
          expect(state.sessionResult, isNotNull);

          // Vérification de la génération du nouveau code
          expect(state.newRecoveryCode, isNotNull);
          expect(state.newRecoveryCode, isNot(equals(currentCode)));
          expect(
            RecoveryCode.isValid(
              RecoveryCode.normalize(state.newRecoveryCode!),
            ),
            isTrue,
          );

          // Vérification des paramètres reçus par SharedService.recover
          expect(fakeSharedService.recoverCallCount, equals(1));
          final Map<String, dynamic> params =
              fakeSharedService.lastRecoverParams!;
          expect(params['url'], equals('https://api.statoo.app'));
          expect(params['groupId'], equals('grp_test'));
          expect(params['username'], equals('alex'));
          expect(params['recoveryCode'], equals('2345-6789-ABCD-EFGH')); // normalisé
          expect(params['newRecoveryCode'], equals(state.newRecoveryCode));
        },
      );
    });

    group('submitRecovery() - Gestion des Erreurs API & Réseau', () {
      test(
        'G-W-T 4.1: Erreur 401 SharedApiException passe à error avec message explicite',
        () async {
          // Given
          fakeSharedService.onRecover = ({
            required url,
            required groupId,
            required username,
            required recoveryCode,
            required newPassword,
            required newRecoveryCode,
          }) {
            throw const SharedApiException(
              401,
              'Récupération impossible. Vérifiez vos informations.',
            );
          };

          // When
          final bool success = await container
              .read(recoveryControllerProvider.notifier)
              .submitRecovery(
                url: 'https://api.statoo.app',
                groupId: 'grp_1',
                username: 'alex',
                recoveryCode: '2345-6789-ABCD-EFGH',
                newPassword: 'ValidPassword123!',
                confirmPassword: 'ValidPassword123!',
              );

          // Then
          expect(success, isFalse);
          final RecoveryState state =
              container.read(recoveryControllerProvider);
          expect(state.step, equals(RecoveryStep.error));
          expect(state.errorMessage, contains('Récupération impossible'));
          expect(state.sessionResult, isNull);
          expect(state.newRecoveryCode, isNull);
        },
      );

      test(
        'G-W-T 4.2: Erreur 429 SharedApiException passe à error avec message de limitation',
        () async {
          // Given
          fakeSharedService.onRecover = ({
            required url,
            required groupId,
            required username,
            required recoveryCode,
            required newPassword,
            required newRecoveryCode,
          }) {
            throw const SharedApiException(429, 'Trop de tentatives.');
          };

          // When
          final bool success = await container
              .read(recoveryControllerProvider.notifier)
              .submitRecovery(
                url: 'https://api.statoo.app',
                groupId: 'grp_1',
                username: 'alex',
                recoveryCode: '2345-6789-ABCD-EFGH',
                newPassword: 'ValidPassword123!',
                confirmPassword: 'ValidPassword123!',
              );

          // Then
          expect(success, isFalse);
          final RecoveryState state =
              container.read(recoveryControllerProvider);
          expect(state.step, equals(RecoveryStep.error));
          expect(state.errorMessage, contains('Trop de tentatives'));
        },
      );

      test('G-W-T 4.3: Erreur 422 SharedApiException passe à error', () async {
        // Given
        fakeSharedService.onRecover = ({
          required url,
          required groupId,
          required username,
          required recoveryCode,
          required newPassword,
          required newRecoveryCode,
        }) {
          throw const SharedApiException(422, 'Format de code invalide.');
        };

        // When
        final bool success = await container
              .read(recoveryControllerProvider.notifier)
              .submitRecovery(
                url: 'https://api.statoo.app',
                groupId: 'grp_1',
                username: 'alex',
                recoveryCode: '2345-6789-ABCD-EFGH',
                newPassword: 'ValidPassword123!',
                confirmPassword: 'ValidPassword123!',
              );

        // Then
        expect(success, isFalse);
        final RecoveryState state =
            container.read(recoveryControllerProvider);
        expect(state.step, equals(RecoveryStep.error));
        expect(state.errorMessage, contains('Format de code'));
      });

      test(
        'G-W-T 4.4: SharedNetworkException passe à error avec message de connectivité',
        () async {
          // Given
          fakeSharedService.onRecover = ({
            required url,
            required groupId,
            required username,
            required recoveryCode,
            required newPassword,
            required newRecoveryCode,
          }) {
            throw const SharedNetworkException();
          };

          // When
          final bool success = await container
              .read(recoveryControllerProvider.notifier)
              .submitRecovery(
                url: 'https://api.statoo.app',
                groupId: 'grp_1',
                username: 'alex',
                recoveryCode: '2345-6789-ABCD-EFGH',
                newPassword: 'ValidPassword123!',
                confirmPassword: 'ValidPassword123!',
              );

          // Then
          expect(success, isFalse);
          final RecoveryState state =
              container.read(recoveryControllerProvider);
          expect(state.step, equals(RecoveryStep.error));
          expect(
            state.errorMessage,
            contains('Impossible de joindre Statoo'),
          );
        },
      );

      test(
        'G-W-T 4.5: Exception inconnue passe à error sans crasher l’application',
        () async {
          // Given
          fakeSharedService.onRecover = ({
            required url,
            required groupId,
            required username,
            required recoveryCode,
            required newPassword,
            required newRecoveryCode,
          }) {
            throw Exception('Erreur inattendue');
          };

          // When
          final bool success = await container
              .read(recoveryControllerProvider.notifier)
              .submitRecovery(
                url: 'https://api.statoo.app',
                groupId: 'grp_1',
                username: 'alex',
                recoveryCode: '2345-6789-ABCD-EFGH',
                newPassword: 'ValidPassword123!',
                confirmPassword: 'ValidPassword123!',
              );

          // Then
          expect(success, isFalse);
          final RecoveryState state =
              container.read(recoveryControllerProvider);
          expect(state.step, equals(RecoveryStep.error));
          expect(state.errorMessage, isNotNull);
        },
      );
    });

    group('confirmCodeAndConnect() - Confirmation et Établissement', () {
      test(
        'G-W-T 5.1: Échoue avec StateError si appelé hors awaitingConfirmation',
        () async {
          // Given (état initial = idle)
          expect(
            container.read(recoveryControllerProvider).step,
            equals(RecoveryStep.idle),
          );

          // When / Then
          await expectLater(
            () => container
                .read(recoveryControllerProvider.notifier)
                .confirmCodeAndConnect(),
            throwsA(isA<StateError>()),
          );
        },
      );

      test(
        'G-W-T 5.2 - 5.7: Établit la session, sélectionne la team locale, rafraîchit les droits et complète',
        () async {
          // Given
          const String targetGroupId = 'team_local_123';
          await fakeTeamRepository.saveTeamInfo(
            TeamInfo(
              id: targetGroupId,
              name: 'Les Invincibles',
              createdAt: DateTime.now(),
            ),
          );

          await container
              .read(recoveryControllerProvider.notifier)
              .submitRecovery(
                url: 'https://api.statoo.app',
                groupId: targetGroupId,
                username: 'alex',
                recoveryCode: '2345-6789-ABCD-EFGH',
                newPassword: 'ValidPassword123!',
                confirmPassword: 'ValidPassword123!',
              );

          final List<int> revisionEvents = <int>[];
          container.listen(
            sharedStatusProvider,
            (_, next) => revisionEvents.add(next),
          );

          final List<RecoveryStep> confirmSteps = <RecoveryStep>[];
          container.listen(
            recoveryControllerProvider,
            (_, next) => confirmSteps.add(next.step),
          );

          // When
          await container
              .read(recoveryControllerProvider.notifier)
              .confirmCodeAndConnect();

          // Then
          expect(confirmSteps, contains(RecoveryStep.establishingSession));
          expect(confirmSteps.last, equals(RecoveryStep.completed));

          final RecoveryState state =
              container.read(recoveryControllerProvider);
          expect(state.step, equals(RecoveryStep.completed));
          expect(state.isLoading, isFalse);

          // Établissement SharedService
          expect(fakeSharedService.establishSessionCallCount, equals(1));
          expect(
            fakeSharedService.lastEstablishSessionParams?['url'],
            equals('https://api.statoo.app'),
          );

          // Sélection de la team active
          expect(container.read(activeTeamIdProvider), equals(targetGroupId));

          // Rafraîchissement des permissions
          expect(revisionEvents, isNotEmpty);
        },
      );

      test(
        'G-W-T 5.5: Ne modifie pas l’équipe active si non enregistrée localement',
        () async {
          // Given (team inconnue du repo local)
          const String remoteOnlyGroup = 'team_remote_999';

          await container
              .read(recoveryControllerProvider.notifier)
              .submitRecovery(
                url: 'https://api.statoo.app',
                groupId: remoteOnlyGroup,
                username: 'alex',
                recoveryCode: '2345-6789-ABCD-EFGH',
                newPassword: 'ValidPassword123!',
                confirmPassword: 'ValidPassword123!',
              );

          // When
          await container
              .read(recoveryControllerProvider.notifier)
              .confirmCodeAndConnect();

          // Then
          expect(
            container.read(recoveryControllerProvider).step,
            equals(RecoveryStep.completed),
          );
          expect(
            container.read(activeTeamIdProvider),
            isNot(equals(remoteOnlyGroup)),
          );
        },
      );

      test(
        'G-W-T 5.8: Échec pendant establishSession passe à l’état error',
        () async {
          // Given
          fakeSharedService.onEstablishSession =
              (url, result) {
            throw const SharedNetworkException();
          };

          await container
              .read(recoveryControllerProvider.notifier)
              .submitRecovery(
                url: 'https://api.statoo.app',
                groupId: 'grp_1',
                username: 'alex',
                recoveryCode: '2345-6789-ABCD-EFGH',
                newPassword: 'ValidPassword123!',
                confirmPassword: 'ValidPassword123!',
              );

          // When
          await container
              .read(recoveryControllerProvider.notifier)
              .confirmCodeAndConnect();

          // Then
          final RecoveryState state =
              container.read(recoveryControllerProvider);
          expect(state.step, equals(RecoveryStep.error));
          expect(state.errorMessage, isNotNull);
          expect(state.isLoading, isFalse);
        },
      );
    });

    group('reset() et Cycle de Vie Notifier', () {
      test('G-W-T 6.1: reset() réinitialise l’état depuis error', () async {
        // Given
        await container
            .read(recoveryControllerProvider.notifier)
            .submitRecovery(
              url: 'https://api.statoo.app',
              groupId: 'grp_1',
              username: 'alex',
              recoveryCode: 'invalid',
              newPassword: 'ValidPassword123!',
              confirmPassword: 'ValidPassword123!',
            );
        expect(
          container.read(recoveryControllerProvider).step,
          equals(RecoveryStep.error),
        );

        // When
        container.read(recoveryControllerProvider.notifier).reset();

        // Then
        final RecoveryState state =
            container.read(recoveryControllerProvider);
        expect(state.step, equals(RecoveryStep.idle));
        expect(state.errorMessage, isNull);
        expect(state.sessionResult, isNull);
        expect(state.newRecoveryCode, isNull);
      });

      test('G-W-T 6.2: reset() réinitialise l’état depuis completed', () async {
        // Given
        await container
            .read(recoveryControllerProvider.notifier)
            .submitRecovery(
              url: 'https://api.statoo.app',
              groupId: 'grp_1',
              username: 'alex',
              recoveryCode: '2345-6789-ABCD-EFGH',
              newPassword: 'ValidPassword123!',
              confirmPassword: 'ValidPassword123!',
            );
        await container
            .read(recoveryControllerProvider.notifier)
            .confirmCodeAndConnect();
        expect(
          container.read(recoveryControllerProvider).step,
          equals(RecoveryStep.completed),
        );

        // When
        container.read(recoveryControllerProvider.notifier).reset();

        // Then
        final RecoveryState state =
            container.read(recoveryControllerProvider);
        expect(state.step, equals(RecoveryStep.idle));
        expect(state.errorMessage, isNull);
      });
    });
  });
}
