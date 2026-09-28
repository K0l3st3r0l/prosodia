import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prosodia/core/database/app_database.dart';
import 'package:prosodia/core/reading_texts_seed.dart';
import 'package:prosodia/features/assessment/presentation/widgets/reading_cover.dart';

/// Una lectura sin portada no rompe nada: cae al arte de respaldo en silencio.
/// Por eso se verifica acá, al agregar textos, y no en la tablet.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('cada lectura sembrada tiene su portada en assets', () async {
    await seedReadingTexts(db);
    final texts = await db.select(db.readingTexts).get();

    expect(texts, isNotEmpty);
    final missing = [
      for (final text in texts)
        if (!File(readingCoverImagePath(text)).existsSync())
          readingCoverImagePath(text),
    ];
    expect(missing, isEmpty);
  });

  test('1° básico mantiene la secuencia anual al final de su nivel', () async {
    await seedReadingTexts(db);
    final titles = (await db.getTextsByNivel('1')).map((t) => t.titulo);

    expect(
      titles.skip(titles.length - 3),
      ['La paloma y la pera', 'Un día en casa', 'El zapatero'],
    );
  });

  test('volver a sembrar no duplica lecturas', () async {
    await seedReadingTexts(db);
    final first = await db.select(db.readingTexts).get();
    await seedReadingTexts(db);
    final second = await db.select(db.readingTexts).get();

    expect(second, hasLength(first.length));
  });
}
