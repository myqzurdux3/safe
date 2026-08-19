import 'package:flutter_test/flutter_test.dart';
import 'package:safe/model/entry_text.dart';

/// Même forme que le texte réel visé par la refonte: des blocs titrés, des
/// commentaires intercalés, l'ordre du document qui compte.
const reference = '''
courrier:
personne@example.invalid
correcthorsebattery

note libre entre deux blocs

banque:
titulaire@example.invalid
double authentification active

deuxieme note libre

wifi:
un-mot-de-passe-quelconque
''';

void main() {
  test(
    'le texte de référence donne cinq groupes dans l\'ordre du document',
    () {
      final groups = parseEntryText(reference);
      expect(groups.length, 5);

      expect(groups[0].title, 'courrier');
      expect(groups[0].lines, [
        'personne@example.invalid',
        'correcthorsebattery',
      ]);

      expect(groups[1].isComment, isTrue);
      expect(groups[1].lines, ['note libre entre deux blocs']);

      expect(groups[2].title, 'banque');
      expect(groups[2].lines, [
        'titulaire@example.invalid',
        'double authentification active',
      ]);

      expect(groups[3].isComment, isTrue);
      expect(groups[3].lines, ['deuxieme note libre']);

      expect(groups[4].title, 'wifi');
      expect(groups[4].lines, ['un-mot-de-passe-quelconque']);
    },
  );

  test('les compteurs comptent les groupes et les lignes de contenu', () {
    final groups = parseEntryText(reference);
    expect(countBlocks(groups), 5);
    expect(countLines(groups), 7);
    expect(describeGroups(groups), '5 blocs · 7 lignes');
  });

  test('un titre de 44 caractères ouvre un bloc, 45 non', () {
    final court = '${'a' * 43}:'; // 44 caractères avec le deux-points
    expect(court.length, 44);
    expect(parseEntryText('$court\nvaleur').single.title, 'a' * 43);

    final long = '${'a' * 44}:'; // 45 caractères
    expect(long.length, 45);
    final groups = parseEntryText('$long\nvaleur');
    expect(groups.single.isComment, isTrue);
    expect(groups.single.lines, [long, 'valeur']);
  });

  test('une ligne vide ferme le bloc courant', () {
    final groups = parseEntryText('bloc:\nun\n\napres');
    expect(groups.length, 2);
    expect(groups[0].title, 'bloc');
    expect(groups[0].lines, ['un']);
    expect(groups[1].isComment, isTrue);
    expect(groups[1].lines, ['apres']);
  });

  test('les lignes vides consécutives ne créent pas de groupe', () {
    expect(parseEntryText('\n\n\n'), isEmpty);
    expect(parseEntryText(''), isEmpty);
    expect(parseEntryText('   \n\t\n'), isEmpty);
  });

  test(
    'un deux-points seul donne un bloc au titre vide, écarté s\'il est vide',
    () {
      // Le prototype de référence écarte un groupe dont le titre est vide et qui
      // n'a aucune ligne; il garde le même groupe dès qu'une ligne le suit.
      expect(parseEntryText(':'), isEmpty);
      final groups = parseEntryText(':\nvaleur');
      expect(groups.single.title, '');
      expect(groups.single.lines, ['valeur']);
    },
  );

  test('chaque ligne est nettoyée de ses espaces et de son retour chariot', () {
    // Un texte collé depuis Windows arrive avec des \r en fin de ligne.
    final groups = parseEntryText('bloc:\r\n  valeur  \r\n');
    expect(groups.single.title, 'bloc');
    expect(groups.single.lines, ['valeur']);
  });

  test('un texte sans deux-points est un seul commentaire', () {
    final groups = parseEntryText('juste une note\net sa suite');
    expect(groups.single.isComment, isTrue);
    expect(groups.single.lines, ['juste une note', 'et sa suite']);
  });

  test('le singulier est respecté dans les compteurs', () {
    expect(describeGroups(parseEntryText('un:\nx')), '1 bloc · 1 ligne');
    expect(describeGroups(const []), '0 bloc · 0 ligne');
  });

  test('les groupes rendus ne sont pas modifiables', () {
    final groups = parseEntryText('bloc:\nvaleur');
    expect(() => groups.single.lines.add('injection'), throwsUnsupportedError);
  });
}
