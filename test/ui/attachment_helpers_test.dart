import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/l10n/app_localizations.dart';
import 'package:safe/ui/attachments_section.dart';

void main() {
  group('formatBytes', () {
    late L fr;
    late L en;

    setUpAll(() async {
      fr = await L.delegate.load(const Locale('fr'));
      en = await L.delegate.load(const Locale('en'));
    });

    test('sous le kilo-octet, en octets', () {
      expect(formatBytes(fr, 0), '0 o');
      expect(formatBytes(fr, 1023), '1023 o');
      expect(formatBytes(en, 1023), '1023 B');
    });

    test('au-delà, en kilo-octets', () {
      expect(formatBytes(fr, 1024), '1,0 ko');
      expect(formatBytes(fr, 1536), '1,5 ko');
      // Espace fine insécable (U+202F) entre les milliers: c'est ce que pose
      // `intl` en français, et non l'espace ordinaire.
      expect(formatBytes(fr, 1024 * 1024 - 1), '1\u202f024,0 ko');
    });

    test('au-delà du mégaoctet, en mégaoctets', () {
      expect(formatBytes(fr, 1024 * 1024), '1,0 Mo');
      expect(formatBytes(fr, 25 * 1024 * 1024), '25,0 Mo');
    });

    test('le séparateur décimal suit la langue', () {
      // Virgule en français, point en anglais. Un `replaceAll` codé en dur
      // donnait « 1,5 kB » à un lecteur anglophone.
      expect(formatBytes(fr, 1536), '1,5 ko');
      expect(formatBytes(en, 1536), '1.5 kB');
    });
  });

  group('guessMimeType', () {
    test('les images reconnues décident de l\'aperçu', () {
      for (final name in ['photo.jpg', 'PHOTO.JPEG', 'a.png', 'b.GIF']) {
        expect(guessMimeType(name), startsWith('image/'), reason: name);
      }
    });

    test('les autres types connus', () {
      expect(guessMimeType('facture.pdf'), 'application/pdf');
      expect(guessMimeType('notes.md'), 'text/plain');
      expect(guessMimeType('notes.TXT'), 'text/plain');
    });

    test('inconnu ou sans extension: type générique, jamais une image', () {
      // Un faux positif ici enverrait un binaire quelconque dans
      // `Image.memory`, qui lèverait au moment de l'afficher.
      expect(guessMimeType('archive.zip'), 'application/octet-stream');
      expect(guessMimeType('sansextension'), 'application/octet-stream');
      expect(guessMimeType(''), 'application/octet-stream');
      expect(guessMimeType('.cache'), 'application/octet-stream');
    });

    test('un nom trompeur ne force pas le type', () {
      expect(guessMimeType('image.png.exe'), 'application/octet-stream');
    });
  });
}
