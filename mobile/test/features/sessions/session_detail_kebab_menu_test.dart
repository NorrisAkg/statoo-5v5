import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:remixicon/remixicon.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/core/widgets/primary_button.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/sessions/data/sessions_repository.dart';
import 'package:statoo/features/sessions/domain/participation.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/domain/session_summary.dart';
import 'package:statoo/features/sessions/presentation/session_detail_screen.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/team/application/team_provider.dart';

class _FakeSessionDetailRepository implements SessionsRepository {
  _FakeSessionDetailRepository({
    required this.session,
    required this.participants,
    this.activeId,
  });

  final Session session;
  final List<SessionParticipantDetail> participants;
  final String? activeId;

  @override
  Future<Session?> getSession(String id, {required String teamId}) async => session;

  @override
  Future<List<SessionParticipantDetail>> getSessionParticipants(String sessionId, {required String teamId}) async =>
      participants;

  @override
  Future<String?> getActiveSessionId({required String teamId}) async => activeId ?? session.id;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  final playedAt = DateTime(2026, 9, 26, 20, 30);

  final activeDraftSession = Session(
    id: 's_active',
    playedAt: playedAt,
    scoreA: 3,
    scoreB: 2,
    result: MatchResult.teamA,
  );

  final closedSession = Session(
    id: 's_closed',
    playedAt: playedAt,
    status: SessionStatus.closed,
    scoreA: 3,
    scoreB: 2,
    result: MatchResult.teamA,
  );

  final waitingDraftSession = Session(
    id: 's_waiting_draft',
    playedAt: playedAt,
    scoreA: 0,
    scoreB: 0,
  );

  final testParticipants = [
    const SessionParticipantDetail(
      participation: Participation(
        id: 'pt_1',
        sessionId: 's_active',
        playerId: 'p1',
        team: Team.a,
        goals: 2,
        assists: 1,
      ),
      playerName: 'Alice Buteur',
    ),
    const SessionParticipantDetail(
      participation: Participation(
        id: 'pt_2',
        sessionId: 's_active',
        playerId: 'p2',
        team: Team.a,
        goals: 1,
        yellowCards: 1,
      ),
      playerName: 'Bob Milieu',
    ),
    const SessionParticipantDetail(
      participation: Participation(
        id: 'pt_3',
        sessionId: 's_active',
        playerId: 'p3',
        team: Team.b,
        goals: 2,
        redCards: 1,
      ),
      playerName: 'Charlie Attaquant',
    ),
    const SessionParticipantDetail(
      participation: Participation(
        id: 'pt_4',
        sessionId: 's_active',
        playerId: 'p4',
        team: Team.b,
      ),
      playerName: 'David Defenseur',
    ),
  ];

  Widget createWidget({
    required SessionsRepository repo,
    bool writable = true,
    String sessionId = 's_active',
    String? activeId = 's_active',
    ThemeData? theme,
    TextScaler? textScaler,
    Size? surfaceSize,
  }) {
    final router = GoRouter(
      initialLocation: '/seances/$sessionId',
      routes: [
        GoRoute(
          path: '/seances/:id',
          builder: (context, state) => SessionDetailScreen(
            sessionId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/seances/:id/finances',
          builder: (context, state) => Scaffold(
            appBar: AppBar(title: const Text('Point financier')),
            body: Text('Page Finances pour ${state.pathParameters['id']}'),
          ),
        ),
        GoRoute(
          path: '/seances',
          builder: (context, state) => const Scaffold(
            body: Text('Liste des séances'),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        sessionsRepositoryProvider.overrideWithValue(repo),
        activeSessionIdProvider.overrideWith((ref) async => activeId),
        activeTeamIdProvider.overrideWith(() => ActiveTeamIdNotifier(initialValue: 'team_test')),
        canWriteSessionProvider((domain: 'sport', sessionId: sessionId))
            .overrideWith((ref) async => writable),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: surfaceSize ?? const Size(393, 852),
          textScaler: textScaler ?? TextScaler.noScaling,
        ),
        child: MaterialApp.router(
          routerConfig: router,
          theme: theme ?? AppTheme.darkTheme,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('fr', 'FR')],
        ),
      ),
    );
  }

  group('Groupe 1 : AppBar et menu Kebab (Présence & Remplacement icône stop)', () {
    testWidgets("1.1 : Sur séance active avec droit écriture, l'icône stop est retirée et le menu kebab est présent", (tester) async {
      final repo = _FakeSessionDetailRepository(session: activeDraftSession, participants: testParticipants);

      await tester.pumpWidget(createWidget(repo: repo));
      await tester.pumpAndSettle();

      expect(find.byIcon(Remix.stop_circle_line), findsNothing);
      expect(find.byIcon(Remix.more_2_fill), findsOneWidget);
      expect(find.byTooltip('Options de la séance'), findsOneWidget);
    });

    testWidgets("1.2 : L'ouverture du menu kebab affiche les 4 entrées attendues", (tester) async {
      final repo = _FakeSessionDetailRepository(session: activeDraftSession, participants: testParticipants);
      await tester.pumpWidget(createWidget(repo: repo));
      await tester.pumpAndSettle();

      final kebabButton = find.byTooltip('Options de la séance');
      await tester.tap(kebabButton.evaluate().isNotEmpty ? kebabButton : find.byIcon(Remix.more_2_fill));
      await tester.pumpAndSettle();

      expect(find.textContaining('Clôtur'), findsWidgets);
      expect(find.text('Point financier'), findsOneWidget);
      expect(find.text('Faits de jeu'), findsOneWidget);
      expect(find.text('Suppression'), findsOneWidget);
    });

    testWidgets("1.3 : Sur séance fermée, le menu kebab est également présent dans l'AppBar", (tester) async {
      final repo = _FakeSessionDetailRepository(session: closedSession, participants: testParticipants, activeId: 's_other');
      await tester.pumpWidget(createWidget(repo: repo, sessionId: 's_closed', activeId: 's_other'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Remix.stop_circle_line), findsNothing);
      expect(find.byIcon(Remix.more_2_fill), findsOneWidget);
    });
  });

  group('Groupe 2 : Corps de page (Nettoyage des boutons doublons dans ListView)', () {
    testWidgets('2.1 : Le bouton OutlinedButton "Point financier" est retiré du corps de page', (tester) async {
      final repo = _FakeSessionDetailRepository(session: activeDraftSession, participants: testParticipants);

      await tester.pumpWidget(createWidget(repo: repo));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Point financier'), findsNothing);
    });

    testWidgets('2.2 : Le bouton textuel dangereux "Supprimer ce match" est retiré du corps de page', (tester) async {
      final repo = _FakeSessionDetailRepository(session: activeDraftSession, participants: testParticipants);

      await tester.pumpWidget(createWidget(repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer ce match'), findsNothing);
    });

    testWidgets('2.3 : Pour une séance active, le gros bouton principal vert "Clôturer la séance" reste présent en bas de page', (tester) async {
      final repo = _FakeSessionDetailRepository(session: activeDraftSession, participants: testParticipants);

      await tester.pumpWidget(createWidget(repo: repo));
      await tester.pumpAndSettle();

      final closeButton = find.widgetWithText(PrimaryButton, 'Clôturer la séance');
      await tester.scrollUntilVisible(closeButton, 200);
      expect(closeButton, findsOneWidget);
    });

    testWidgets('2.4 : Pour une séance fermée, le bouton textuel "Supprimer la séance" est retiré du corps', (tester) async {
      final repo = _FakeSessionDetailRepository(session: closedSession, participants: testParticipants);

      await tester.pumpWidget(createWidget(repo: repo, sessionId: 's_closed', activeId: null));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer la séance'), findsNothing);
    });

    testWidgets('2.5 : Pour un brouillon en attente, le bouton textuel "Supprimer le brouillon" est retiré du corps', (tester) async {
      final repo = _FakeSessionDetailRepository(session: waitingDraftSession, participants: testParticipants, activeId: 'other_active');

      await tester.pumpWidget(createWidget(repo: repo, sessionId: 's_waiting_draft', activeId: 'other_active'));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer le brouillon'), findsNothing);
    });
  });

  group('Groupe 3 : Comportement des actions du menu Kebab', () {
    testWidgets("3.1 : L'action \"Clôture\" du kebab ouvre la boîte de dialogue de confirmation de clôture", (tester) async {
      final repo = _FakeSessionDetailRepository(session: activeDraftSession, participants: testParticipants);
      await tester.pumpWidget(createWidget(repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Options de la séance').evaluate().isNotEmpty
          ? find.byTooltip('Options de la séance')
          : find.byIcon(Remix.more_2_fill));
      await tester.pumpAndSettle();

      final closeItem = find.textContaining('Clôtur').last;
      await tester.tap(closeItem);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Clôturer la séance ?'), findsOneWidget);
    });

    testWidgets("3.2 : L'action \"Point financier\" du kebab navigue vers /seances/:id/finances", (tester) async {
      final repo = _FakeSessionDetailRepository(session: activeDraftSession, participants: testParticipants);
      await tester.pumpWidget(createWidget(repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Options de la séance').evaluate().isNotEmpty
          ? find.byTooltip('Options de la séance')
          : find.byIcon(Remix.more_2_fill));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Point financier'));
      await tester.pumpAndSettle();

      expect(find.text('Page Finances pour s_active'), findsOneWidget);
    });

    testWidgets("3.3 : L'action \"Faits de jeu\" ouvre une BottomSheet récapitulant les événements (buteurs, passeurs, cartons)", (tester) async {
      final repo = _FakeSessionDetailRepository(session: activeDraftSession, participants: testParticipants);
      await tester.pumpWidget(createWidget(repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Options de la séance').evaluate().isNotEmpty
          ? find.byTooltip('Options de la séance')
          : find.byIcon(Remix.more_2_fill));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Faits de jeu'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.textContaining('Faits de jeu'), findsWidgets);
      expect(find.textContaining('Alice Buteur'), findsWidgets);
      expect(find.textContaining('Charlie Attaquant'), findsWidgets);
    });

    testWidgets("3.4 : L'action \"Suppression\" déclenche la confirmation de suppression de séance", (tester) async {
      final repo = _FakeSessionDetailRepository(session: activeDraftSession, participants: testParticipants);
      await tester.pumpWidget(createWidget(repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Options de la séance').evaluate().isNotEmpty
          ? find.byTooltip('Options de la séance')
          : find.byIcon(Remix.more_2_fill));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Suppression'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Supprimer'), findsWidgets);
    });
  });

  group('Groupe 4 : Permissions et mode lecture seule (_writable == false)', () {
    testWidgets('4.1 : En lecture seule, le kebab reste accessible mais "Clôture" et "Suppression" sont désactivées/masquées', (tester) async {
      final repo = _FakeSessionDetailRepository(session: activeDraftSession, participants: testParticipants);
      await tester.pumpWidget(createWidget(repo: repo, writable: false));
      await tester.pumpAndSettle();

      final kebab = find.byTooltip('Options de la séance').evaluate().isNotEmpty
          ? find.byTooltip('Options de la séance')
          : find.byIcon(Remix.more_2_fill);
      expect(kebab, findsOneWidget);
      await tester.tap(kebab);
      await tester.pumpAndSettle();

      expect(find.text('Point financier'), findsOneWidget);
      expect(find.text('Faits de jeu'), findsOneWidget);

      final suppressionItem = find.ancestor(of: find.text('Suppression'), matching: find.byType(PopupMenuItem<String>));
      if (suppressionItem.evaluate().isNotEmpty) {
        final widget = tester.widget<PopupMenuItem<String>>(suppressionItem.first);
        expect(widget.enabled, isFalse);
      } else {
        expect(find.text('Suppression'), findsNothing);
      }
    });
  });

  group('Groupe 5 : Responsive & Accessibilité (320dp, 393dp, textScalers)', () {
    testWidgets('5.1 : Écran 320dp, Dark Theme, textScale 1.0 : Aucun overflow', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeSessionDetailRepository(session: activeDraftSession, participants: testParticipants);
      await tester.pumpWidget(createWidget(
        repo: repo,
        surfaceSize: const Size(320, 640),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Détail séance'), findsOneWidget);
    });

    testWidgets('5.2 : Écran 393dp, Light Theme, textScale 1.3 : Aucun overflow', (tester) async {
      tester.view.physicalSize = const Size(393 * 3.0, 852 * 3.0);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeSessionDetailRepository(session: activeDraftSession, participants: testParticipants);
      await tester.pumpWidget(createWidget(
        repo: repo,
        surfaceSize: const Size(393, 852),
        textScaler: const TextScaler.linear(1.3),
        theme: AppTheme.lightTheme,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('5.3 : Écran 393dp, Large Accessibility (textScale 2.0) : Aucun overflow', (tester) async {
      tester.view.physicalSize = const Size(393 * 3.0, 852 * 3.0);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeSessionDetailRepository(session: activeDraftSession, participants: testParticipants);
      await tester.pumpWidget(createWidget(
        repo: repo,
        surfaceSize: const Size(393, 852),
        textScaler: const TextScaler.linear(2),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
