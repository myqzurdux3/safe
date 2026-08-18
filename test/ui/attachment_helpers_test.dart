import 'package:flutter_test/flutter_test.dart';
import 'package:safe/ui/attachments_section.dart';

void main() {
  group('formatBytes', () {
    test('sous le kilo-octet, en octets', () {
      expect(formatBytes(0), '0 o');
      expect(formatBytes(1023), '1023 o');
    });

    test('au-delà, en kilo-octets avec une virgule décimale', () {
      // Virgule et non point: le reste de l'interface est en français.
      expect(formatBytes(1024), '1,0 ko');
      expect(formatBytes(1536), '1,5 ko');
      expect(formatBytes(1024 * 1024 - 1), '1024,0 ko');
    });

    test('au-delà du mégaoctet, en mégaoctets', () {
      expect(formatBytes(1024 * 1024), '1,0 Mo');
      expect(formatBytes(25 * 1024 * 1024), '25,0 Mo');
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
