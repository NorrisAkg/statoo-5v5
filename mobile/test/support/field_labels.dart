import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// A11Y-004 (revue) : le libellé [label] d'un champ reste entier (aucun texte coupé par
/// des points de suspension), au repos puis une fois le champ focalisé, et nomme le
/// champ pour les lecteurs d'écran. Le champ est celui dont le nœud de saisie commence
/// par [label]. Si le libellé n'est pas encore construit (liste paresseuse), la page
/// défile dans [scrollable] jusqu'à lui.
Future<void> expectWholeFieldLabel(
  WidgetTester tester,
  String label, {
  Finder? scrollable,
}) async {
  final semantics = tester.ensureSemantics();
  try {
    final text = find.text(label);
    if (text.evaluate().isEmpty) {
      // `text` et non `text.first` : `.first` d'un finder vide lève une erreur.
      await tester.scrollUntilVisible(
        text,
        120,
        scrollable: scrollable ?? find.byType(Scrollable).first,
      );
    }
    expect(text, findsWidgets, reason: '« $label » doit être affiché');
    await tester.ensureVisible(text.first);
    await tester.pumpAndSettle();
    bool cut() => tester
        .renderObjectList<RenderParagraph>(find.text(label))
        .any((paragraph) => paragraph.didExceedMaxLines);
    expect(cut(), isFalse, reason: '« $label » coupé au repos');

    final field = find.byType(TextField).evaluate().where((element) {
      final editable = find.descendant(
        of: find.byWidget(element.widget),
        matching: find.byType(EditableText),
      );
      return tester.getSemantics(editable).label.startsWith(label);
    }).toList();
    expect(field, hasLength(1), reason: 'un champ nommé « $label »');
    await tester.tap(find.byWidget(field.single.widget));
    await tester.pumpAndSettle();
    expect(cut(), isFalse, reason: '« $label » coupé, champ focalisé');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  } finally {
    semantics.dispose();
  }
}
