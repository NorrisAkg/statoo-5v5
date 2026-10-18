import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/features/shared/data/collective_access.dart';
import 'package:statoo/features/settings/presentation/collective_access_section.dart';

import '../shared/collective_access_test.dart' show FakeShared;

class MemoryAccess extends CollectiveAccess {
  MemoryAccess() : super(FakeShared(), '#12345678');
  bool saved = false;
  bool permitted = true;
  String? received;
  Object? failure;
  int writes = 0;
  @override
  bool get allowed => permitted;
  @override
  Future<bool> hasSaved() async => saved;
  @override
  Future<void> remember(String password) async {
    writes++;
    if (failure != null) throw failure!;
    received = password;
    saved = true;
  }

  @override
  Future<String> copyText(String name) async => 'Explicit access for $name';
  @override
  Future<void> forget() async {
    saved = false;
  }
}

class ManagerMemoryAccess extends MemoryAccess {
  int resets = 0;
  @override
  String? get managerAccountId => 'manager';
  @override
  Future<void> regenerate() async {
    resets++;
    saved = true;
  }
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  testWidgets('GES09 copy confirmation stays visible inside manager dialog', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final access = ManagerMemoryAccess()..saved = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  content: CollectiveAccessSection(
                    access: access,
                    groupName: 'Atlas',
                  ),
                ),
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copier les accès'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Accès copiés'),
      ),
      findsOneWidget,
    );
  });
  testWidgets(
    'GES03/04 regeneration requires confirmation and can be cancelled',
    (tester) async {
      final access = ManagerMemoryAccess();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CollectiveAccessSection(access: access, groupName: 'Atlas'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Renseigner le mot de passe existant'), findsOneWidget);
      await tester.tap(find.text('Générer un nouveau mot de passe'));
      await tester.pumpAndSettle();
      expect(find.text('Remplacer le mot de passe ?'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(access.resets, 0);
      await tester.tap(find.text('Générer un nouveau mot de passe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remplacer et mémoriser'));
      await tester.pumpAndSettle();
      expect(access.resets, 1);
      expect(find.text('Copier les accès'), findsOneWidget);
    },
  );
  testWidgets(
    'ACC05 explicit verification and copy; password never displayed afterwards',
    (tester) async {
      final access = MemoryAccess();
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: CollectiveAccessSection(
                access: access,
                groupName: 'Atlas',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Renseigner le mot de passe commun'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );
      await tester.enterText(find.byType(TextField), 'Members-2026');
      await tester.tap(find.text('Vérifier et mémoriser'));
      await tester.pumpAndSettle();
      expect(access.received, 'Members-2026');
      expect(find.text('Members-2026'), findsNothing);
      expect(calls.where((c) => c.method == 'Clipboard.setData'), isEmpty);
      await tester.tap(find.text('Copier les accès'));
      await tester.pumpAndSettle();
      expect(
        calls.where((c) => c.method == 'Clipboard.setData').single.arguments,
        {'text': 'Explicit access for Atlas'},
      );
      expect(find.text('Accès copiés'), findsOneWidget);
    },
  );
  testWidgets('ACC03 hidden from non Admin', (tester) async {
    final access = MemoryAccess()..permitted = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: CollectiveAccessSection(access: access, groupName: 'Atlas'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Accès des membres'), findsNothing);
  });
  testWidgets(
    'ACC07 clipboard failure has no success; retry remains possible',
    (tester) async {
      final access = MemoryAccess()..saved = true;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData')
            throw PlatformException(code: 'denied');
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CollectiveAccessSection(access: access, groupName: 'Atlas'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copier les accès'));
      await tester.pumpAndSettle();
      expect(find.text('Accès copiés'), findsNothing);
      expect(
        find.text(
          'Impossible de terminer cette action sur cet appareil. Réessayez.',
        ),
        findsOneWidget,
      );
      expect(access.saved, isTrue);
    },
  );
  testWidgets(
    'ACC07/08 failed storage stays in form and cancel preserves old access',
    (tester) async {
      final access = MemoryAccess()
        ..saved = true
        ..failure = PlatformException(
          code: 'storage',
          message: 'sensitive-details',
        );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CollectiveAccessSection(access: access, groupName: 'Atlas'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vérifier un autre mot de passe'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Members-2026');
      await tester.tap(find.text('Vérifier et mémoriser'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Impossible de terminer cette action sur cet appareil. Réessayez.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('sensitive-details'), findsNothing);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(access.saved, isTrue);
      expect(access.writes, 1);
      expect(find.text('Members-2026'), findsNothing);
    },
  );
  for (final width in [320.0, 393.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        for (final managerCase in [false, true]) {
          testWidgets(
            'ACC10/GES08 layout $width $scale $mode manager=$managerCase',
            (tester) async {
              tester.view.physicalSize = Size(width, 800);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              await tester.pumpWidget(
                MaterialApp(
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: mode,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      viewInsets: const EdgeInsets.only(bottom: 280),
                    ),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: SingleChildScrollView(
                      child: CollectiveAccessSection(
                        access: managerCase
                            ? (ManagerMemoryAccess()..saved = true)
                            : (MemoryAccess()..saved = true),
                        groupName: 'Un groupe avec un nom très long',
                        managerName:
                            'gestionnaire-avec-un-identifiant-très-long',
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(find.text('Copier les accès'), findsOneWidget);
              expect(tester.takeException(), isNull);
              await tester.ensureVisible(
                find.text('Vérifier un autre mot de passe'),
              );
              await tester.tap(find.text('Vérifier un autre mot de passe'));
              await tester.pumpAndSettle();
              expect(find.byType(TextField), findsOneWidget);
              await tester.ensureVisible(find.text('Vérifier et mémoriser'));
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
}
