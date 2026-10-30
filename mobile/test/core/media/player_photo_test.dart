import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/core/media/player_photo.dart';
import 'package:statoo/core/widgets/player_avatar.dart';

const png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('selection uses actual image type and embedded bytes', () async {
    expect(
      await PlayerPhoto.encode(base64Decode(png)),
      'data:image/png;base64,$png',
    );
  });
  test('valid JPEG is portable', () async {
    const encoded =
        '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAACAAIDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDkqKKK84/Sj//Z';
    expect(
      await PlayerPhoto.encode(base64Decode(encoded)),
      'data:image/jpeg;base64,$encoded',
    );
  });
  test('valid WEBP is portable', () async {
    const encoded =
        'UklGRjoAAABXRUJQVlA4IC4AAACwAQCdASoCAAIAAUAmJaACdLoABiIAAP7xTa9fAFP2f/3jP/7jP/7jP/kQAAAA';
    expect(
      await PlayerPhoto.encode(base64Decode(encoded)),
      'data:image/webp;base64,$encoded',
    );
  });
  test('extreme aspect ratio is rejected before decoding', () async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAEAEAAAABCAYAAACx4wBCAAAAKklEQVR4nO3DQQ0AAAwDofNvupOxDyS0mqqqqqqqqqqqqqqqqqqqqvr/AITl49Ak3alAAAAAAElFTkSuQmCC',
    );
    await expectLater(
      PlayerPhoto.encode(bytes),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'dimensions',
          contains('4096'),
        ),
      ),
    );
  });
  test('too many bytes rejected before decoding', () async {
    await expectLater(
      PlayerPhoto.encode(Uint8List(PlayerPhoto.maxBytes + 1)),
      throwsFormatException,
    );
  });
  test('non-image is rejected', () async {
    await expectLater(
      PlayerPhoto.encode(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });
  test('misleading MIME is rejected', () async {
    await expectLater(
      PlayerPhoto.decode('data:image/jpeg;base64,$png'),
      throwsFormatException,
    );
  });
  test('excessive dimensions rejected', () async {
    final bytes = base64Decode(png);
    ByteData.sublistView(bytes).setUint32(16, 100000);
    await expectLater(PlayerPhoto.encode(bytes), throwsFormatException);
  });
  for (final width in [320.0, 393.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('avatar fits $width $scale dark=$dark', (tester) async {
          tester.view.resetPhysicalSize();
          tester.view.physicalSize = Size(width, 600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? ThemeData.dark() : ThemeData.light(),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: const Scaffold(
                  body: Row(
                    children: [
                      PlayerAvatar(
                        source: 'data:image/png;base64,$png',
                        initial: 'AL',
                        baseColor: Colors.green,
                        size: 48,
                      ),
                      Expanded(child: Text('Alexandre Nom composé très long')),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump();
          expect(find.byType(Image), findsOneWidget);
          expect(tester.getSize(find.byType(PlayerAvatar)), const Size(48, 48));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets(
    'changed source does not display previous portrait while loading',
    (tester) async {
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('statoo-avatar-'),
      ))!;
      final file = (await tester.runAsync(
        () => File('${dir.path}/photo.png').writeAsBytes(base64Decode(png)),
      ))!;
      addTearDown(() => dir.delete(recursive: true));
      Widget portrait(String source, String initial) => MaterialApp(
        home: Scaffold(
          body: PlayerAvatar(
            source: source,
            initial: initial,
            baseColor: Colors.green,
          ),
        ),
      );
      await tester.pumpWidget(portrait('data:image/png;base64,$png', 'AA'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      await tester.pumpWidget(portrait(file.path, 'BB'));
      expect(find.text('BB'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
    },
  );
  testWidgets('broken photo falls back to initials', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlayerAvatar(
            source: 'data:image/png;base64,broken',
            initial: 'AB',
            baseColor: Colors.green,
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.text('AB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
