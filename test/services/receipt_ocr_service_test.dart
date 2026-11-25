import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studenthold_app/services/receipt_ocr_service.dart';

void main() {
  final service = ReceiptOcrService.instance;

  group('ReceiptOcrService: Tunisian Dinar (DT) Number Parsing', () {
    test('parses 3-decimal millimes with dot and comma', () {
      expect(ReceiptOcrService.parseDtPrice('12.500'), 12.5);
      expect(ReceiptOcrService.parseDtPrice('12,500'), 12.5);
      expect(ReceiptOcrService.parseDtPrice('0.850'), 0.85);
      expect(ReceiptOcrService.parseDtPrice('0,750 DT'), 0.75);
    });

    test('parses 2-decimal and 1-decimal DT values', () {
      expect(ReceiptOcrService.parseDtPrice('4,20'), 4.2);
      expect(ReceiptOcrService.parseDtPrice('12.50 DT'), 12.5);
      expect(ReceiptOcrService.parseDtPrice('8.9 DT'), 8.9);
      expect(ReceiptOcrService.parseDtPrice('15.000 TND'), 15.0);
    });

    test('returns null for non-numeric or noise strings', () {
      expect(ReceiptOcrService.parseDtPrice(''), isNull);
      expect(ReceiptOcrService.parseDtPrice('CARREFOUR'), isNull);
      expect(ReceiptOcrService.parseDtPrice('TOTAL TTC'), isNull);
      expect(ReceiptOcrService.parseDtPrice('MF: 12345/A'), isNull);
    });
  });

  group('ReceiptOcrService: Spatial Line Grouping (Left Text + Right Price Columns)', () {
    test('groups multi-column thermal receipt lines within 22.0 px vertical tolerance', () {
      final ocrLines = [
        const OcrLine(
          text: 'MG PROXI KELIBIA',
          boundingBox: Rect.fromLTWH(20, 50, 180, 20),
        ),
        // Item 1: Left name, Right two-column prices
        const OcrLine(
          text: '1 POPCORN CAR',
          boundingBox: Rect.fromLTWH(20, 100, 140, 20),
        ),
        const OcrLine(
          text: '3.410 3.410',
          boundingBox: Rect.fromLTWH(220, 102, 100, 20),
        ),
        // Item 2: Left name, Right unit price + line total
        const OcrLine(
          text: '2 NOUILLE MIGO',
          boundingBox: Rect.fromLTWH(20, 130, 140, 20),
        ),
        const OcrLine(
          text: '1.180 2.360',
          boundingBox: Rect.fromLTWH(220, 131, 100, 20),
        ),
        // Total line: Left spaced out total label, Right total amount
        const OcrLine(
          text: '= T O T A L ( 8)',
          boundingBox: Rect.fromLTWH(20, 180, 150, 20),
        ),
        const OcrLine(
          text: '9.970',
          boundingBox: Rect.fromLTWH(240, 182, 60, 20),
        ),
      ];

      final grouped = service.groupLinesSpatially(ocrLines, yTolerance: 22.0);

      expect(grouped.length, 4);
      expect(grouped[0], 'MG PROXI KELIBIA');
      expect(grouped[1], '1 POPCORN CAR 3.410 3.410');
      expect(grouped[2], '2 NOUILLE MIGO 1.180 2.360');
      expect(grouped[3], '= T O T A L ( 8) 9.970');
    });

    test('parseOcrLines accurately parses full MG PROXI KELIBIA structured receipt', () {
      final ocrLines = [
        const OcrLine(
          text: 'MG PROXI KELIBIA',
          boundingBox: Rect.fromLTWH(20, 30, 180, 22),
        ),
        const OcrLine(
          text: 'MAGASIN GENERAL',
          boundingBox: Rect.fromLTWH(20, 58, 160, 20),
        ),
        const OcrLine(
          text: 'CAISSE: 02  CAISSIER: 104',
          boundingBox: Rect.fromLTWH(20, 85, 200, 18),
        ),
        // Item 1
        const OcrLine(
          text: '1 POPCORN CAR',
          boundingBox: Rect.fromLTWH(20, 120, 140, 20),
        ),
        const OcrLine(
          text: '3.410 3.410',
          boundingBox: Rect.fromLTWH(220, 122, 100, 20),
        ),
        // Item 2
        const OcrLine(
          text: '2 NOUILLE MIGO',
          boundingBox: Rect.fromLTWH(20, 150, 140, 20),
        ),
        const OcrLine(
          text: '1.180 2.360',
          boundingBox: Rect.fromLTWH(220, 152, 100, 20),
        ),
        // Item 3 with integer in name
        const OcrLine(
          text: '1 TIMBRE 100 M',
          boundingBox: Rect.fromLTWH(20, 180, 140, 20),
        ),
        const OcrLine(
          text: '0.100 0.100',
          boundingBox: Rect.fromLTWH(220, 181, 100, 20),
        ),
        // Spaced out total
        const OcrLine(
          text: '= T O T A L ( 8)',
          boundingBox: Rect.fromLTWH(20, 220, 150, 20),
        ),
        const OcrLine(
          text: '5.870',
          boundingBox: Rect.fromLTWH(240, 221, 60, 20),
        ),
        // Payment line
        const OcrLine(
          text: 'CARTE BANCAIRE',
          boundingBox: Rect.fromLTWH(20, 250, 140, 20),
        ),
        const OcrLine(
          text: '5.870',
          boundingBox: Rect.fromLTWH(240, 251, 60, 20),
        ),
      ];

      final result = service.parseOcrLines(ocrLines);

      expect(result.merchant, 'MG PROXI KELIBIA');
      expect(result.items.length, 3);

      expect(result.items[0].name, '1x POPCORN CAR');
      expect(result.items[0].price, 3.410);

      expect(result.items[1].name, '2x NOUILLE MIGO');
      expect(result.items[1].price, 2.360);

      expect(result.items[2].name, '1x TIMBRE 100 M');
      expect(result.items[2].price, 0.100);

      expect(result.total, 5.870);
    });
  });

  group('ReceiptOcrService: Spaced-Out T O T A L & Payment Fallbacks', () {
    test('extracts spaced-out "= T O T A L (  8)    9.970" total', () {
      const receipt = '''
MG PROXI KELIBIA
1 POPCORN CAR 3.410 3.410
2 NOUILLE MIGO 1.180 2.360
= T O T A L (  8)    9.970
CARTE BANCAIRE 9.970
''';

      final result = service.parseRawText(receipt);

      expect(result.merchant, 'MG PROXI KELIBIA');
      expect(result.total, 9.970);
      expect(result.items.length, 2);
      expect(result.items[0].price, 3.410);
      expect(result.items[1].price, 2.360);
    });

    test('extracts total from secondary payment line when TOTAL keyword is missing', () {
      const receiptWithoutTotal = '''
AZIZA SUPERETTE
FROMAGE BLANC 2.100 2.100
JUS D ORANGE 1.800 1.800
CARTE BANCAIRE 3.900
''';

      final result = service.parseRawText(receiptWithoutTotal);

      expect(result.merchant, 'AZIZA SUPERETTE');
      expect(result.total, 3.900);
      expect(result.items.length, 2);
    });
  });

  group('ReceiptOcrService: Two-Column Unit Price & Line Total Extraction', () {
    test('always selects rightmost decimal price as line total and strips unit price', () {
      const receipt = '''
MG PROXI KELIBIA
2 NOUILLE MIGO 1.180 2.360
1 TIMBRE 100 M 0.100 0.100
TOTAL 2.460
''';

      final result = service.parseRawText(receipt);

      expect(result.items.length, 2);
      expect(result.items[0].name, '2x NOUILLE MIGO');
      expect(result.items[0].price, 2.360);

      expect(result.items[1].name, '1x TIMBRE 100 M');
      expect(result.items[1].price, 0.100);
      expect(result.total, 2.460);
    });

    test('never populates empty placeholder items when line has no valid price', () {
      const receiptWithNoise = '''
MONOPRIX LAFAYETTE
AVENUE DE LA LIBERTE
CAISSE 01 CAISSIER 22
MERCI POUR VOTRE VISITE
RECLAMATION: 71 000 000
PAIN BAGUETTE 0.850
YAOURT 0.650
NET A PAYER 1.500
''';

      final result = service.parseRawText(receiptWithNoise);

      expect(result.merchant, 'MONOPRIX LAFAYETTE');
      expect(result.items.length, 2);
      expect(result.items.any((it) => it.name.isEmpty || it.price <= 0), isFalse);
    });
  });
}
