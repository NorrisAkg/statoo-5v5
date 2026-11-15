// A11Y-003 et A11Y-004 (audit 14/11/2026) : 16 IconButton et 1 FloatingActionButton
// sans nom accessible, 15 champs nommés seulement par leur texte d'exemple. Ce test
// parcourt `lib/` pour qu'un nouveau bouton icône ou un nouveau champ ne revienne pas
// sans nom. Les tests de widget (commands_test, players) vérifient le rendu réel.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Texte des arguments de l'appel qui commence à [open] (parenthèse ouvrante), en
/// ignorant les parenthèses des chaînes et des commentaires.
String callArguments(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final c = source[i];
    if (c == '/' && i + 1 < source.length && source[i + 1] == '/') {
      i = source.indexOf('\n', i);
      if (i < 0) break;
      continue;
    }
    if (c == "'" || c == '"') {
      final triple = source.startsWith(c * 3, i);
      final end = triple
          ? source.indexOf(c * 3, i + 3)
          : _closing(source, i, c);
      i = triple ? end + 2 : end;
      continue;
    }
    if (c == '(') depth++;
    if (c == ')' && --depth == 0) return source.substring(open, i + 1);
  }
  throw StateError('parenthèse non fermée à $open');
}

int _closing(String source, int start, String quote) {
  for (var i = start + 1; i < source.length; i++) {
    if (source[i] == r'\') {
      i++;
    } else if (source[i] == quote) {
      return i;
    }
  }
  throw StateError('chaîne non fermée à $start');
}

/// Appels de [widget] (et de ses constructeurs nommés) dont les arguments ne
/// satisfont pas [named]. Résultat : `fichier:ligne`.
List<String> unnamed(
  RegExp widget,
  bool Function(String source, int start, String arguments) named,
) {
  final offenders = <String>[];
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where(
        (f) => !f.path.endsWith('.g.dart') && !f.path.endsWith('.freezed.dart'),
      );
  for (final file in files) {
    final source = file.readAsStringSync();
    for (final match in widget.allMatches(source)) {
      final arguments = callArguments(source, match.end - 1);
      if (!named(source, match.start, arguments)) {
        final line =
            '\n'.allMatches(source.substring(0, match.start)).length + 1;
        offenders.add('${file.path.replaceAll(r'\', '/')}:$line');
      }
    }
  }
  return offenders..sort();
}

/// Arguments nommés de premier niveau d'un appel ([arguments] commence par `(`) :
/// nom → (position de la valeur dans [arguments], valeur sans espaces autour).
Map<String, (int, String)> namedArguments(String arguments) {
  final result = <String, (int, String)>{};
  var depth = 0;
  var start = 1;
  void flush(int end) {
    final part = arguments.substring(start, end);
    // Les commentaires qui précèdent l'argument ne font pas partie de son nom.
    final match = RegExp(r'^(?:\s*//[^\n]*\n)*\s*(\w+)\s*:\s*')
        .firstMatch(part);
    if (match != null) {
      result[match.group(1)!] = (
        start + match.end,
        part.substring(match.end).trim(),
      );
    }
    start = end + 1;
  }

  for (var i = 0; i < arguments.length; i++) {
    final c = arguments[i];
    if (c == '/' && i + 1 < arguments.length && arguments[i + 1] == '/') {
      i = arguments.indexOf('\n', i);
      if (i < 0) break;
      continue;
    }
    if (c == "'" || c == '"') {
      final triple = arguments.startsWith(c * 3, i);
      i = triple
          ? arguments.indexOf(c * 3, i + 3) + 2
          : _closing(arguments, i, c);
      continue;
    }
    if ('([{'.contains(c)) depth++;
    if (')]}'.contains(c)) {
      depth--;
      if (depth == 0) flush(i);
    }
    if (c == ',' && depth == 1) flush(i);
  }
  return result;
}

bool _present(Map<String, (int, String)> arguments, String name) {
  final value = arguments[name]?.$2;
  return value != null && value.isNotEmpty && value != 'null';
}

/// Un champ est nommé par `labelText`/`label` de sa décoration (premier niveau), ou par
/// un `Semantics(label: …)` dont l'enfant direct est le champ (motif de
/// `create_team_screen.dart`) et qui ne masque pas ses descendants.
bool fieldIsNamed(String source, int start, String arguments) {
  final decoration = namedArguments(arguments)['decoration']?.$2 ?? '';
  final call = RegExp(r'^(?:const\s+)?[\w.]+\(').firstMatch(decoration);
  if (call != null) {
    final inner = namedArguments(callArguments(decoration, call.end - 1));
    if (_present(inner, 'labelText') || _present(inner, 'label')) return true;
  }
  for (final wrapper in RegExp(
    r'\b(Semantics|LabeledField)\(',
  ).allMatches(source.substring(0, start))) {
    final open = wrapper.end - 1;
    final wrapped = namedArguments(callArguments(source, open));
    final child = wrapped['child'];
    if (child != null &&
        open + child.$1 == start &&
        // LabeledField : libellé obligatoire, affiché et porté par un Semantics.
        (_present(wrapped, 'label') || wrapper.group(1) == 'LabeledField') &&
        wrapped['excludeSemantics']?.$2 != 'true') {
      return true;
    }
  }
  return false;
}

/// Un bouton icône est nommé par son propre `tooltip` non nul.
bool buttonIsNamed(String source, int start, String arguments) =>
    _present(namedArguments(arguments), 'tooltip');

void main() {
  test('A11Y003-01 chaque IconButton a un tooltip', () {
    expect(unnamed(RegExp(r'\bIconButton(\.\w+)?\('), buttonIsNamed), isEmpty);
  });

  test('A11Y003-02 chaque FloatingActionButton a un tooltip', () {
    expect(
      unnamed(RegExp(r'\bFloatingActionButton(\.\w+)?\('), buttonIsNamed),
      isEmpty,
    );
  });

  test('A11Y004-01 chaque champ de saisie a un nom permanent', () {
    expect(
      unnamed(RegExp(r'\b(TextField|TextFormField)\('), fieldIsNamed),
      isEmpty,
    );
  });

  // Revue : le scanner acceptait des noms qui n'en sont pas.
  test(
    'A11Y003-03 un tooltip nul ou porté par un widget imbriqué ne compte pas',
    () {
      const source = '''
IconButton(tooltip: 'Fermer', icon: Icon(x));
IconButton(tooltip: null, icon: Icon(x));
IconButton(icon: Tooltip(message: 'm', child: Icon(x)), onPressed: f);
IconButton(icon: Icon(x), onPressed: () => show(tooltip: 'y'));
''';
      expect(_verdicts(source, 'IconButton', buttonIsNamed), [
        true,
        false,
        false,
        false,
      ]);
    },
  );

  test('A11Y004-02 seuls labelText/label de la décoration ou un Semantics direct comptent', () {
    const source = '''
Semantics(button: true, child: Text('x'));
Semantics(label: 'Nom', child: Text('y'));
TextField(decoration: InputDecoration(hintText: 'Karim (ex.)'));
Semantics(container: true, child: TextField());
Semantics(label: 'Surnom', child: TextField());
TextField(decoration: const InputDecoration(labelText: 'Ville'));
TextField(decoration: InputDecoration(labelText: null));
TextField(decoration: InputDecoration(suffixIcon: TextButton.icon(label: Text('Afficher'))));
Semantics(label: 'Bloc', child: Column(children: [TextField()]));
Semantics(label: 'Caché', excludeSemantics: true, child: TextField());
TextField(decoration: InputDecoration(label: Text('Code')));
TextField(
  // Commentaire avant l'argument.
  decoration: InputDecoration(labelText: 'Montant'),
);
LabeledField(label: 'Rechercher un membre', child: TextField());
LabeledField(label: 'Bloc', child: Column(children: [TextField()]));
''';
    expect(_verdicts(source, 'TextField', fieldIsNamed), [
      false, // exemple seul
      false, // Semantics sans label
      true, // Semantics(label:) direct
      true, // labelText
      false, // labelText nul
      false, // `label:` d'un widget imbriqué
      false, // Semantics qui englobe un conteneur, pas le champ
      false, // Semantics qui masque le champ
      true, // label: widget
      true, // commentaire avant decoration:
      true, // LabeledField direct (libellé visible + Semantics)
      false, // LabeledField qui englobe un conteneur
    ]);
  });
}

List<bool> _verdicts(
  String source,
  String widget,
  bool Function(String source, int start, String arguments) named,
) => [
  for (final match in RegExp('\\b$widget\\(').allMatches(source))
    named(source, match.start, callArguments(source, match.end - 1)),
];
