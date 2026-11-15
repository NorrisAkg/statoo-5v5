import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Détecte un texte UTF-8 relu en Windows-1252 puis réenregistré en UTF-8
/// (« Ã© » au lieu de « é », « â€” » au lieu de « — »), ainsi que le BOM,
/// brut ou lui-même mal encodé (« ï»¿ »).
final RegExp _mojibake = RegExp(
  '[\u00C2\u00C3][\u0080-\u00BF\u0152\u0153\u0160\u0161\u0178\u017D\u017E'
  '\u0192\u02C6\u02DC\u2013-\u203A\u20AC\u2122]|\u00E2\u20AC'
  '|\u00C3 |\u00C5[\u201C\u2019]|\uFEFF|\u00EF\u00BB\u00BF',
);

List<String> _mojibakeLines(String source) {
  final hits = <String>[];
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (_mojibake.hasMatch(lines[i])) hits.add('${i + 1}: ${lines[i].trim()}');
  }
  return hits;
}

void main() {
  group('ENC01 détecteur de mojibake', () {
    test('signale les séquences doublement encodées', () {
      // é, É, à (insécable conservée), ·, —
      expect(_mojibakeLines("Text('D\u00C3\u00A9tail')"), hasLength(1));
      expect(_mojibakeLines("'\u00C3\u2030quipes'"), hasLength(1));
      expect(_mojibakeLines("'commencer \u00C3\u00A0 saisir'"), hasLength(1));
      expect(_mojibakeLines("'2 \u00C2\u00B7 1'"), hasLength(1));
      expect(_mojibakeLines("'Buts \u00E2\u20AC\u201D passes'"), hasLength(1));
      // à dont l'insécable a été remplacée par une espace normale
      expect(_mojibakeLines("'commencer \u00C3 saisir'"), hasLength(1));
      // œ et Œ
      expect(
        _mojibakeLines("'\u00C5\u201Cuvre, \u00C5\u2019il'"),
        hasLength(1),
      );
      // BOM brut ou mal encodé
      expect(_mojibakeLines("\uFEFFimport 'x.dart';"), hasLength(1));
      expect(
        _mojibakeLines("\u00EF\u00BB\u00BFimport 'x.dart';"),
        hasLength(1),
      );
    });

    test('accepte le français correctement encodé', () {
      expect(
        _mojibakeLines(
          "Text('Détail séance · Clôture — « Équipes » à saisir, prête, élève, "
          "œuvre, Œil, ÂGE, Ça')",
        ),
        isEmpty,
      );
    });
  });

  test('ENC02 aucun fichier de lib/ ne contient de texte mal encodé', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      for (final hit in _mojibakeLines(file.readAsStringSync())) {
        offenders.add('${file.path}:$hit');
      }
    }
    expect(offenders, isEmpty, reason: offenders.take(20).join('\n'));
  });
}
