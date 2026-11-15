// A11Y-001 (audit 14/11/2026) : sur Flutter web, l'élément focalisé au clavier ne se
// distinguait de son état normal qu'avec un contraste de 1,15:1 (WCAG 2.4.7 et 1.4.11).
// Ces tests mesurent les pixels autour de l'élément focalisé, avant et après le focus :
// chaque côté doit changer avec un contraste d'au moins 3:1.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/core/widgets/browser_app_frame.dart';

const _root = Key('root');

class _Shot {
  _Shot(this.width, this.bytes);
  final int width;
  final ByteData bytes;

  double luminance(Offset point) {
    final i = (point.dy.floor() * width + point.dx.floor()) * 4;
    double channel(int offset) {
      final c = bytes.getUint8(i + offset) / 255;
      return c <= 0.03928
          ? c / 12.92
          : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * channel(0) + 0.7152 * channel(1) + 0.0722 * channel(2);
  }
}

Future<_Shot> _shot(WidgetTester tester) async {
  await tester.pump();
  return (await tester.runAsync(() async {
    final image = await captureImage(find.byKey(_root).evaluate().single);
    final bytes = await image.toByteData();
    return _Shot(image.width, bytes!);
  }))!;
}

double _contrast(double a, double b) =>
    (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);

/// Pour chaque côté de [rect], le meilleur contraste trouvé entre [before] et [after]
/// sur une bande de 1 px à l'intérieur jusqu'à 6 px à l'extérieur, au milieu du côté.
List<double> _sides(_Shot before, _Shot after, Rect rect) {
  final samples = <List<Offset>>[
    [for (var d = -1; d <= 6; d++) Offset(rect.center.dx, rect.top - d - 0.5)],
    [
      for (var d = -1; d <= 6; d++)
        Offset(rect.right + d + 0.5, rect.center.dy),
    ],
    [
      for (var d = -1; d <= 6; d++)
        Offset(rect.center.dx, rect.bottom + d + 0.5),
    ],
    [for (var d = -1; d <= 6; d++) Offset(rect.left - d - 0.5, rect.center.dy)],
  ];
  return [
    for (final side in samples)
      side
          .map((p) => _contrast(before.luminance(p), after.luminance(p)))
          .reduce(math.max),
  ];
}

Matcher get _visibleRing => everyElement(greaterThanOrEqualTo(3.0));
Matcher get _noRing => everyElement(lessThan(3.0));

Widget _app(
  Widget body, {
  bool dark = true,
  bool web = false,
  PreferredSizeWidget? appBar,
}) => RepaintBoundary(
  key: _root,
  child: MaterialApp(
    theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
    debugShowCheckedModeBanner: false,
    builder: (context, child) => BrowserAppFrame(enabled: web, child: child!),
    home: Scaffold(appBar: appBar, body: body),
  ),
);

/// Meilleur contraste entre deux captures sur tous les pixels de [area].
double _maxChange(_Shot before, _Shot after, Rect area) {
  var best = 1.0;
  for (var y = area.top.floor(); y < area.bottom.floor(); y++) {
    for (var x = area.left.floor(); x < area.right.floor(); x++) {
      final p = Offset(x + 0.5, y + 0.5);
      best = math.max(best, _contrast(before.luminance(p), after.luminance(p)));
    }
  }
  return best;
}

Widget _buttons({List<FocusNode>? nodes, VoidCallback? onFirst}) => Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextButton(
        focusNode: nodes?[0],
        onPressed: onFirst ?? () {},
        child: const Text('Passer'),
      ),
      const SizedBox(height: 40),
      FilledButton(
        focusNode: nodes?[1],
        onPressed: () {},
        child: const Text('Suivant'),
      ),
    ],
  ),
);

Rect _focused() => FocusManager.instance.primaryFocus!.rect;

Future<void> _tab(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(393, 852)
      ..devicePixelRatio = 1;
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  for (final dark in [true, false]) {
    testWidgets('A11Y001-01 Tab rend le focus visible (≥ 3:1) dark=$dark', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_buttons(), dark: dark));
      final before = await _shot(tester);
      await _tab(tester);
      final rect = _focused();
      expect(rect.overlaps(tester.getRect(find.text('Passer'))), isTrue);
      expect(_sides(before, await _shot(tester), rect), _visibleRing);
    });
  }

  testWidgets(
    'A11Y001-02 le bouton principal rempli a aussi un focus visible',
    (tester) async {
      await tester.pumpWidget(_app(_buttons()));
      final before = await _shot(tester);
      await _tab(tester);
      await _tab(tester);
      final rect = _focused();
      expect(rect.overlaps(tester.getRect(find.text('Suivant'))), isTrue);
      expect(_sides(before, await _shot(tester), rect), _visibleRing);
    },
  );

  testWidgets('A11Y001-03 le focus quitte visuellement le bouton précédent', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_buttons()));
    final before = await _shot(tester);
    await _tab(tester);
    final first = _focused();
    await _tab(tester);
    expect(_sides(before, await _shot(tester), first), _noRing);
  });

  testWidgets(
    'A11Y001-04 au toucher, un focus programmatique ne dessine pas d’anneau',
    (tester) async {
      final nodes = [FocusNode(), FocusNode()];
      addTearDown(() {
        for (final node in nodes) {
          node.dispose();
        }
      });
      await tester.pumpWidget(_app(_buttons(nodes: nodes)));
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(FocusManager.instance.highlightMode, FocusHighlightMode.touch);
      final before = await _shot(tester);
      nodes[1].requestFocus();
      await tester.pumpAndSettle();
      expect(_sides(before, await _shot(tester), nodes[1].rect), _noRing);
    },
  );

  testWidgets('A11Y001-05 l’anneau disparaît quand le focus est retiré', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_buttons()));
    final before = await _shot(tester);
    await _tab(tester);
    final rect = _focused();
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();
    expect(_sides(before, await _shot(tester), rect), _noRing);
  });

  testWidgets('A11Y001-06 l’anneau suit l’élément quand la page défile', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        ListView(
          controller: controller,
          children: [
            for (var i = 0; i < 30; i++)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 12,
                ),
                child: OutlinedButton(
                  onPressed: () {},
                  child: Text('Ligne $i'),
                ),
              ),
          ],
        ),
      ),
    );
    await _tab(tester);
    await _tab(tester);
    controller.jumpTo(30);
    await tester.pumpAndSettle();
    final rect = _focused();
    // Référence : même position de défilement, sans focus.
    final focused = await _shot(tester);
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();
    expect(_sides(await _shot(tester), focused, rect), _visibleRing);
  });

  testWidgets(
    'A11Y001-07 l’anneau n’intercepte ni les appuis ni les sémantiques',
    (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(_app(_buttons(onFirst: () => taps++)));
      // Tous les nœuds sémantiques, pas seulement ceux de la racine.
      int nodes() => find.semantics.byPredicate((_) => true).evaluate().length;
      final nodesBefore = nodes();
      await _tab(tester);
      await tester.tap(find.text('Passer'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(nodes(), nodesBefore);
      handle.dispose();
    },
  );

  for (final dark in [true, false]) {
    testWidgets(
      'A11Y001-08 sur le web, l’anneau reste aligné sous le bandeau du navigateur dark=$dark',
      (tester) async {
        await tester.pumpWidget(_app(_buttons(), web: true, dark: dark));
        final before = await _shot(tester);
        await _tab(tester);
        expect(_sides(before, await _shot(tester), _focused()), _visibleRing);
      },
    );
  }

  // Revue : l'anneau, peint au-dessus de tout, débordait sur l'AppBar quand l'élément
  // focalisé défilait dessous.
  testWidgets(
    'A11Y001-11 un élément défilé sous l’AppBar ne dessine rien sur l’AppBar',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          appBar: AppBar(title: const Text('Joueurs')),
          ListView(
            controller: controller,
            children: [
              for (var i = 0; i < 30; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 12,
                  ),
                  child: OutlinedButton(
                    onPressed: () {},
                    child: Text('Ligne $i'),
                  ),
                ),
            ],
          ),
        ),
      );
      await _tab(tester);
      final top = tester.getRect(find.byType(ListView)).top;
      // Le premier bouton passe entièrement au-dessus de la zone de défilement.
      controller.jumpTo(_focused().bottom - top + 8);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.context?.mounted, isTrue);
      final focused = await _shot(tester);
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pumpAndSettle();
      final appBar = tester.getRect(find.byType(AppBar));
      expect(_maxChange(await _shot(tester), focused, appBar), lessThan(3.0));
    },
  );

  testWidgets(
    'A11Y001-12 un élément à moitié masqué garde l’anneau sur sa partie visible',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          appBar: AppBar(title: const Text('Joueurs')),
          ListView(
            controller: controller,
            children: [
              for (var i = 0; i < 30; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 12,
                  ),
                  child: OutlinedButton(
                    onPressed: () {},
                    child: Text('Ligne $i'),
                  ),
                ),
            ],
          ),
        ),
      );
      await _tab(tester);
      final top = tester.getRect(find.byType(ListView)).top;
      controller.jumpTo(_focused().center.dy - top);
      await tester.pumpAndSettle();
      final rect = _focused();
      final focused = await _shot(tester);
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pumpAndSettle();
      final sides = _sides(await _shot(tester), focused, rect);
      // Côtés gauche, droit et bas visibles ; le haut est sous l'AppBar.
      expect([sides[1], sides[2], sides[3]], _visibleRing);
      final appBar = tester.getRect(find.byType(AppBar));
      expect(_maxChange(await _shot(tester), focused, appBar), lessThan(3.0));
    },
  );

  testWidgets(
    'A11Y001-13 un bouton de dialogue focalisé au clavier a un anneau visible',
    (tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Confirmer'),
                    actions: [
                      TextButton(
                        onPressed: () {},
                        child: const Text('Annuler'),
                      ),
                    ],
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
      final before = await _shot(tester);
      await _tab(tester);
      final rect = _focused();
      expect(rect.overlaps(tester.getRect(find.text('Annuler'))), isTrue);
      expect(_sides(before, await _shot(tester), rect), _visibleRing);
    },
  );

  testWidgets(
    'A11Y001-14 l’anneau suit la taille affichée d’un élément mis à l’échelle',
    (tester) async {
      await tester.pumpWidget(
        _app(
          Center(
            child: Transform.scale(
              scale: 0.5,
              child: FilledButton(
                onPressed: () {},
                child: const Text('Suivant'),
              ),
            ),
          ),
        ),
      );
      final before = await _shot(tester);
      await _tab(tester);
      final shown = tester.getRect(find.byType(FilledButton));
      expect(_sides(before, await _shot(tester), shown), _visibleRing);
    },
  );

  testWidgets(
    'A11Y001-09 l’élément focalisé retiré de l’arbre ne laisse ni anneau ni erreur',
    (tester) async {
      await tester.pumpWidget(_app(_buttons()));
      await _tab(tester);
      final rect = _focused();
      await tester.pumpWidget(_app(const SizedBox.expand()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final empty = await _shot(tester);
      // Les boutons ont disparu : on compare à une capture du même écran vide, sans focus.
      await tester.pumpWidget(_app(const SizedBox.expand(key: Key('autre'))));
      await tester.pumpAndSettle();
      expect(_sides(await _shot(tester), empty, rect), _noRing);
    },
  );

  testWidgets(
    'A11Y001-10 un champ de saisie garde sa bordure de focus, sans anneau en double',
    (tester) async {
      await tester.pumpWidget(
        _app(const Padding(padding: EdgeInsets.all(40), child: TextField())),
      );
      final before = await _shot(tester);
      await _tab(tester);
      final field = tester.getRect(find.byType(TextField));
      // Hors de la bordure du champ : pas d'anneau supplémentaire.
      expect(_sides(before, await _shot(tester), field.inflate(3)), _noRing);
    },
  );
}
