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
    // Les compteurs, pas leur mise en mots: celle-ci dépend de la langue.
    expect(countBlocks(groups), 5);
    expect(countLines(groups), 7);
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
    expect(countBlocks(parseEntryText('un:\nx')), 1);
    expect(countLines(parseEntryText('un:\nx')), 1);
    expect(countBlocks(const []), 0);
    expect(countLines(const []), 0);
  });

  test('les groupes rendus ne sont pas modifiables', () {
    final groups = parseEntryText('bloc:\nvaleur');
    expect(() => groups.single.lines.add('injection'), throwsUnsupportedError);
  });

  test('les lignes brutes gardent les espaces de bord', () {
    // L'affichage rogne; le coffre garde. Copier la version rognée collerait
    // un mot de passe faux, sans que rien ne le signale.
    final groups = parseEntryText('courrier:\n  secret bordé  \n');
    expect(groups.single.lines, ['secret bordé']);
    expect(groups.single.rawLines, ['  secret bordé  ']);
  });

  test('le retour chariot de Windows ne rejoint pas les lignes brutes', () {
    // Il termine la ligne, il n'en fait pas partie: collé avec le reste, il
    // se retrouverait dans un champ de mot de passe.
    final groups = parseEntryText('courrier:\r\n  secret  \r\n');
    expect(groups.single.rawLines, ['  secret  ']);
  });

  test('lignes brutes et lignes affichées vont deux par deux', () {
    for (final group in parseEntryText(reference)) {
      expect(group.rawLines.length, group.lines.length);
    }
  });

  test('un groupe construit sans lignes brutes retombe sur ses lignes', () {
    const group = EntryGroup(title: 'courrier', lines: ['a']);
    expect(group.rawLines, ['a']);
  });
}
