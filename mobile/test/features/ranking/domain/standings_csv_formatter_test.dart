import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/features/ranking/domain/standing_entry.dart';
import 'package:statoo/features/ranking/domain/standings_csv_formatter.dart';

void main() {
  const sampleEntry1 = StandingEntry(
    rank: 1,
    playerId: 'p1',
    name: 'Karim Benali',
    nickname: 'Kaka',
    isActive: true,
    matchesPlayed: 10,
    wins: 8,
    draws: 1,
    losses: 1,
    points: 25,
    goals: 14,
    assists: 6,
  );

  const sampleEntry2 = StandingEntry(
    rank: 2,
    playerId: 'p2',
    name: 'Lucas Dupont',
    isActive: true,
    matchesPlayed: 9,
    wins: 6,
    draws: 2,
    losses: 1,
    points: 20,
    goals: 7,
    assists: 3,
  );

  group('StandingsCsvFormatter', () {
    test(r'commence par le BOM UTF-8 (\uFEFF) pour compatibilité Excel', () {
      const formatter = StandingsCsvFormatter();
      final csv = formatter.format([sampleEntry1]);

      expect(csv.startsWith('\uFEFF'), isTrue);
    });

    test(r'lignes terminées par CRLF (\r\n) et en-tête standard', () {
      const formatter = StandingsCsvFormatter();
      final csv = formatter.format(<StandingEntry>[]);

      expect(csv, '\uFEFFRang;Nom;Surnom;Points;Matchs Joués;Victoires;Nuls;Défaites;Buts;Passes Décisives\r\n');
    });

    test('formate une ligne nominale standard avec séparateur point-virgule', () {
      const formatter = StandingsCsvFormatter();
      final csv = formatter.format([sampleEntry1]);

      final lines = csv.split('\r\n');
      expect(lines.length, 3); // BOM+header, ligne 1, ligne vide finale
      expect(
        lines[1],
        '1;Karim Benali;Kaka;25;10;8;1;1;14;6',
      );
    });

    test('gère les champs optionnels/nulls (nickname absent -> champ vide)', () {
      const formatter = StandingsCsvFormatter();
      final csv = formatter.format([sampleEntry2]);

      final lines = csv.split('\r\n');
      expect(
        lines[1],
        '2;Lucas Dupont;;20;9;6;2;1;7;3',
      );
    });

    test('échappe les séparateurs présents dans les champs texte avec guillemets', () {
      const formatter = StandingsCsvFormatter();
      const trickyEntry = StandingEntry(
        rank: 3,
        playerId: 'p3',
        name: 'Martin; Paul',
        nickname: 'Double;Trouble',
        isActive: true,
        matchesPlayed: 4,
        wins: 2,
        draws: 1,
        losses: 1,
        points: 7,
        goals: 2,
        assists: 1,
      );

      final csv = formatter.format([trickyEntry]);
      final lines = csv.split('\r\n');
      expect(lines[1], '3;"Martin; Paul";"Double;Trouble";7;4;2;1;1;2;1');
    });

    test('échappe et double les guillemets existants (" -> "")', () {
      const formatter = StandingsCsvFormatter();
      const trickyEntry = StandingEntry(
        rank: 4,
        playerId: 'p4',
        name: 'Jean-Luc "The Boss"',
        nickname: 'Le "Kid"',
        isActive: true,
        matchesPlayed: 2,
        wins: 1,
        draws: 0,
        losses: 1,
        points: 3,
        goals: 1,
        assists: 0,
      );

      final csv = formatter.format([trickyEntry]);
      final lines = csv.split('\r\n');
      expect(
        lines[1],
        '4;"Jean-Luc ""The Boss""";"Le ""Kid""";3;2;1;0;1;1;0',
      );
    });

    test(r'échappe les retours à la ligne \r\n et \n dans les noms ou surnoms', () {
      const formatter = StandingsCsvFormatter();
      const multilineEntry = StandingEntry(
        rank: 5,
        playerId: 'p5',
        name: 'Alexandre\nLeGrand',
        nickname: 'King\r\nKong',
        isActive: true,
        matchesPlayed: 1,
        wins: 1,
        draws: 0,
        losses: 0,
        points: 3,
        goals: 3,
        assists: 0,
      );

      final csv = formatter.format([multilineEntry]);

      // Le BOM initial est présent
      expect(csv.startsWith('\uFEFF'), isTrue);
      // Les sauts de ligne sont emballés dans des guillemets conformément à la RFC 4180
      expect(csv.contains('"Alexandre\nLeGrand"'), isTrue);
      expect(csv.contains('"King\r\nKong"'), isTrue);
    });

    test('supporte un séparateur alternatif (ex: virgule ",")', () {
      const formatter = StandingsCsvFormatter(separator: ',');
      final csv = formatter.format([sampleEntry1]);

      final lines = csv.split('\r\n');
      expect(lines[0], '\uFEFFRang,Nom,Surnom,Points,Matchs Joués,Victoires,Nuls,Défaites,Buts,Passes Décisives');
      expect(lines[1], '1,Karim Benali,Kaka,25,10,8,1,1,14,6');
    });

    test('permet de désactiver le BOM UTF-8 si nécessaire', () {
      const formatter = StandingsCsvFormatter(includeBom: false);
      final csv = formatter.format([sampleEntry1]);

      expect(csv.startsWith('\uFEFF'), isFalse);
      expect(csv.startsWith('Rang;Nom;'), isTrue);
    });
  });
}
