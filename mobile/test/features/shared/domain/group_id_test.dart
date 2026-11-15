import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/features/shared/domain/group_id.dart';

void main() {
  group('UX-003 normalizeGroupId', () {
    test('ajoute le # devant 8 chiffres', () {
      expect(normalizeGroupId('13120987'), '#13120987');
    });
    test('laisse un identifiant déjà correct', () {
      expect(normalizeGroupId('#13120987'), '#13120987');
    });
    test('ignore les espaces, tabulations et espaces insécables', () {
      expect(normalizeGroupId(' 1312 0987\n'), '#13120987');
      expect(normalizeGroupId('\t# 13120987\u00a0'), '#13120987');
      expect(normalizeGroupId('#\u00a013120987'), '#13120987');
    });
    test('ignore les caractères invisibles d’un copier-coller', () {
      expect(normalizeGroupId('\u200b13120987'), '#13120987');
      expect(normalizeGroupId('\ufeff#13120987\u200b'), '#13120987');
    });
    test('ne touche pas aux autres formats (groupes historiques)', () {
      for (final raw in ['1312098', '131209870', 'historical', '##13120987', '#1312098a']) {
        expect(normalizeGroupId(raw), raw);
      }
    });
    test('vide reste vide', () {
      expect(normalizeGroupId(' \u200b '), '');
    });
  });
}
