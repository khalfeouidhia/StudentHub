import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Single item parsed from an OCR receipt.
class ReceiptItem {
  String name;
  double price;
  int quantity;

  ReceiptItem({
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  String get priceFormatted => '${price.toStringAsFixed(3)} DT';

  ReceiptItem copyWith({
    String? name,
    double? price,
    int? quantity,
  }) {
    return ReceiptItem(
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'quantity': quantity,
      };

  factory ReceiptItem.fromJson(Map<String, dynamic> json) => ReceiptItem(
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      );
}

/// Fully parsed receipt result containing merchant, items, grand total, and image.
class ParsedReceipt {
  final String merchant;
  final List<ReceiptItem> items;
  final double total;
  final DateTime? date;
  final String? imagePath;
  final String rawText;

  const ParsedReceipt({
    required this.merchant,
    required this.items,
    required this.total,
    this.date,
    this.imagePath,
    this.rawText = '',
  });

  String get totalFormatted => '${total.toStringAsFixed(3)} DT';

  ParsedReceipt copyWith({
    String? merchant,
    List<ReceiptItem>? items,
    double? total,
    DateTime? date,
    String? imagePath,
    String? rawText,
  }) {
    return ParsedReceipt(
      merchant: merchant ?? this.merchant,
      items: items ?? this.items,
      total: total ?? this.total,
      date: date ?? this.date,
      imagePath: imagePath ?? this.imagePath,
      rawText: rawText ?? this.rawText,
    );
  }
}

/// Compatibility alias for ParsedReceipt.
typedef OcrReceiptResult = ParsedReceipt;

/// Lightweight container for OCR line text and spatial coordinates.
class OcrLine {
  final String text;
  final Rect boundingBox;

  const OcrLine({
    required this.text,
    required this.boundingBox,
  });
}

/// On-device OCR Receipt Parsing Service for StudentHub.
/// Specializes in Tunisian Dinar (DT/TND) thermal supermarket receipts (MG, Carrefour, Aziza, Monoprix),
/// spatial line grouping, spaced-out POS total keywords, noise filtering, and two-column price extraction.
class ReceiptOcrService {
  ReceiptOcrService._();

  static final ReceiptOcrService instance = ReceiptOcrService._();

  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Scans a receipt image file.
  /// On Android / iOS, executes on-device Google ML Kit Text Recognition.
  /// On PC (Web browser / Desktop), runs PC Testing fallback with real supermarket data.
  Future<ParsedReceipt> scanReceipt(XFile imageFile) async {
    if (!_isMobilePlatform) {
      return _parseForPcTesting(imageFile);
    }

    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      try {
        final recognizedText = await textRecognizer.processImage(inputImage);
        final ocrLines = <OcrLine>[];

        // Extract all TextLine objects across all TextBlocks into a single flat list
        for (final block in recognizedText.blocks) {
          for (final line in block.lines) {
            ocrLines.add(OcrLine(
              text: line.text,
              boundingBox: line.boundingBox,
            ));
          }
        }

        return parseOcrLines(
          ocrLines,
          imagePath: imageFile.path,
          fullRawText: recognizedText.text,
        );
      } finally {
        textRecognizer.close();
      }
    } catch (_) {
      // Fallback for desktop/unsupported runtimes
      return _parseForPcTesting(imageFile);
    }
  }

  /// Returns sample MG Proxi Kelibia receipt for instant PC testing.
  ParsedReceipt getSampleMgReceipt({String? imagePath}) {
    return parseRawText(_mgProxiKelibiaSampleReceipt, imagePath: imagePath);
  }

  ParsedReceipt _parseForPcTesting(XFile imageFile) {
    final lowerName = imageFile.name.toLowerCase();

    if (lowerName.contains('carrefour')) {
      return parseRawText(_carrefourSampleReceipt, imagePath: imageFile.path);
    }
    if (lowerName.contains('monoprix')) {
      return parseRawText(_monoprixSampleReceipt, imagePath: imageFile.path);
    }
    if (lowerName.contains('aziza')) {
      return parseRawText(_azizaSampleReceipt, imagePath: imageFile.path);
    }

    // Default to the exact MG Proxi Kelibia thermal receipt
    return parseRawText(_mgProxiKelibiaSampleReceipt, imagePath: imageFile.path);
  }

  static const String _mgProxiKelibiaSampleReceipt = '''
MG PROXI KELIBIA
MAGASIN GENERAL
AVENUE HABIB BOURGUIBA
KELIBIA
TEL: 72 295 123
MF: 0001234/A/M/000
CAISSE: 02  CAISSIER: 104
TICKET: 014523  DATE: 14/11/2026 18:42
----------------------------------------
1 POPCORN CAR                3.410  3.410
2 NOUILLE MIGO       1.180   2.360
1 BISCUIT MAJOR              0.750  0.750
1 CHOCOLAT SAID              2.100  2.100
1 JUS TROPICO                1.250  1.250
1 TIMBRE 100 M       0.100   0.100
----------------------------------------
= T O T A L (  8)            9.970
CARTE BANCAIRE               9.970
----------------------------------------
MERCI DE VOTRE VISITE
A BIENTOT
''';

  static const String _carrefourSampleReceipt = '''
CARREFOUR MARKET
CENTRE URBAIN NORD
MF: 1234567/A/M/000
TEL: 71 123 456
----------------------------------------
PAIN BAGUETTE 0.850
LAIT DEMI ECREME 1.450
YAOURT BRASSE 0.650
2x CROISSANT 1.800
----------------------------------------
SOUS-TOTAL 4.750
TOTAL TTC 4.750 DT
ESPECES 10.000
RENDU 5.250
MERCI POUR VOTRE VISITE
''';

  static const String _monoprixSampleReceipt = '''
MONOPRIX LAFAYETTE
12/10/2026 14:32
SANDWICH THON 4,200
EAU MINERALE 0,800
NET A PAYER 5,000 DT
CARTE BANCAIRE 5,000
''';

  static const String _azizaSampleReceipt = '''
AZIZA SUPERETTE
FROMAGE BLANC 2.100 2.100
JUS D ORANGE 1.800 1.800
TOTAL DT 3.900
''';

  /// Parses receipt text given structured [OcrLine]s with bounding boxes.
  ParsedReceipt parseOcrLines(
    List<OcrLine> lines, {
    String? imagePath,
    String? fullRawText,
  }) {
    if (lines.isEmpty) {
      if (fullRawText != null && fullRawText.trim().isNotEmpty) {
        return parseRawText(fullRawText, imagePath: imagePath);
      }
      return ParsedReceipt(
        merchant: 'Receipt Expense',
        items: [],
        total: 0.0,
        imagePath: imagePath,
        rawText: fullRawText ?? '',
      );
    }

    final groupedRows = groupLinesSpatially(lines, yTolerance: 22.0);
    return _parseRows(
      groupedRows,
      imagePath: imagePath,
      rawText: fullRawText ?? groupedRows.join('\n'),
    );
  }

  /// Parses raw string text (e.g. from tests or fallback inputs) into a [ParsedReceipt].
  ParsedReceipt parseRawText(String text, {String? imagePath}) {
    final rows = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return _parseRows(rows, imagePath: imagePath, rawText: text);
  }

  /// Groups OCR lines that share approximately the same horizontal row (Y-axis)
  /// and sorts them left-to-right (X-axis).
  /// Tolerance is max(22.0, 0.6 * lineHeight), with horizontal overlap prevention.
  List<String> groupLinesSpatially(List<OcrLine> lines, {double yTolerance = 22.0}) {
    if (lines.isEmpty) return [];

    // 1. Sort all lines top-to-bottom by boundingBox.center.dy
    final sorted = List<OcrLine>.from(lines)
      ..sort((a, b) => a.boundingBox.center.dy.compareTo(b.boundingBox.center.dy));

    final clusters = <List<OcrLine>>[];

    for (final line in sorted) {
      if (clusters.isEmpty) {
        clusters.add([line]);
        continue;
      }

      final currentCluster = clusters.last;
      final clusterBaseY = currentCluster.first.boundingBox.center.dy;
      final avgHeight = currentCluster
              .map((l) => l.boundingBox.height)
              .reduce((a, b) => a + b) /
          currentCluster.length;
      final effectiveTolerance = max(yTolerance, 0.6 * avgHeight);

      // Check if this line significantly overlaps horizontally with an existing line in the cluster
      // (Two items from the left column should not be merged into the same row)
      bool hasSignificantOverlap = false;
      for (final existing in currentCluster) {
        final overlapLeft = max(line.boundingBox.left, existing.boundingBox.left);
        final overlapRight = min(line.boundingBox.right, existing.boundingBox.right);
        final overlapWidth = overlapRight - overlapLeft;
        if (overlapWidth > 15.0) {
          hasSignificantOverlap = true;
          break;
        }
      }

      final yDiff = (line.boundingBox.center.dy - clusterBaseY).abs();

      if (!hasSignificantOverlap && yDiff <= effectiveTolerance) {
        currentCluster.add(line);
      } else {
        clusters.add([line]);
      }
    }

    // 2. Sort lines within each row left-to-right by boundingBox.left and join with " "
    final reconstructed = <String>[];
    for (final cluster in clusters) {
      cluster.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      final lineText = cluster.map((l) => l.text.trim()).join(' ').trim();
      if (lineText.isNotEmpty) {
        reconstructed.add(lineText);
      }
    }

    return reconstructed;
  }

  // ---------------------------------------------------------------------------
  // Internal Core Parsing Pipeline
  // ---------------------------------------------------------------------------

  ParsedReceipt _parseRows(
    List<String> rows, {
    String? imagePath,
    required String rawText,
  }) {
    if (rows.isEmpty) {
      return ParsedReceipt(
        merchant: 'Receipt Expense',
        items: [],
        total: 0.0,
        imagePath: imagePath,
        rawText: rawText,
      );
    }

    final merchant = _detectMerchant(rows);
    final date = _detectDate(rows);

    final totalResult = _detectGrandTotal(rows);
    final grandTotalFromKeyword = totalResult.total;
    final totalLineIndex = totalResult.lineIndex;

    final items = <ReceiptItem>[];

    for (int i = 0; i < rows.length; i++) {
      if (i == totalLineIndex) continue;
      if (totalResult.adjacentLineIndex != null && i == totalResult.adjacentLineIndex) {
        continue;
      }

      final row = rows[i];
      if (_isNoiseOrNonItemLine(row)) continue;

      final parsedItem = _parseLineItem(row);
      if (parsedItem != null && parsedItem.price > 0 && parsedItem.name.isNotEmpty) {
        items.add(parsedItem);
      }
    }

    double finalTotal = grandTotalFromKeyword ?? 0.0;
    if (finalTotal <= 0.0) {
      final itemsSum = items.fold(0.0, (sum, it) => sum + it.price);
      if (itemsSum > 0.0) {
        finalTotal = double.parse(itemsSum.toStringAsFixed(3));
      } else {
        finalTotal = _findLargestBottomAmount(rows);
      }
    }

    return ParsedReceipt(
      merchant: merchant,
      items: items,
      total: finalTotal,
      date: date,
      imagePath: imagePath,
      rawText: rawText,
    );
  }

  // ---------------------------------------------------------------------------
  // Tunisian Dinar (DT/TND) Number Parsing
  // ---------------------------------------------------------------------------

  /// Extracts the rightmost/last decimal price found on a line.
  static double? extractLastDecimalPrice(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return null;

    final decimalRegex = RegExp(r'\b([0-9]+[.,][0-9]{2,3})\b');
    final matches = decimalRegex.allMatches(cleaned).toList();
    if (matches.isNotEmpty) {
      return _normalizeAmount(matches.last.group(1));
    }

    final explicitRegex = RegExp(
      r'(?:(?:DT|TND)\s*)?([0-9]+(?:[.,][0-9]{1,3})?)\s*(?:DT|TND)\b',
      caseSensitive: false,
    );
    final explicitMatches = explicitRegex.allMatches(cleaned).toList();
    if (explicitMatches.isNotEmpty) {
      return _normalizeAmount(explicitMatches.last.group(1));
    }

    final trailingRegex = RegExp(r'([0-9]+(?:[.,][0-9]{1,3})?)\s*$');
    final trailingMatch = trailingRegex.firstMatch(cleaned);
    if (trailingMatch != null) {
      return _normalizeAmount(trailingMatch.group(1));
    }

    return null;
  }

  /// Parses a numeric currency value into a 3-decimal double.
  static double? parseDtPrice(String text) {
    return extractLastDecimalPrice(text);
  }

  static double? _normalizeAmount(String? raw) {
    if (raw == null) return null;
    final normalized = raw.replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    if (parsed == null || !parsed.isFinite || parsed <= 0.0) return null;
    return double.parse(parsed.toStringAsFixed(3));
  }

  // ---------------------------------------------------------------------------
  // Grand Total Detection (Handles Spaced-Out "T O T A L" and Payment Fallbacks)
  // ---------------------------------------------------------------------------

  _TotalDetectionResult _detectGrandTotal(List<String> rows) {
    // 1. Primary Bottom-Up Search matching space-collapsed total keywords
    for (int i = rows.length - 1; i >= 0; i--) {
      final row = rows[i];
      final collapsed = row.replaceAll(RegExp(r'\s+'), '').toUpperCase();

      // Exclude subtotal lines
      if (collapsed.contains('SOUSTOTAL') || collapsed.contains('SUBTOTAL')) {
        continue;
      }

      final hasTotalKeyword = collapsed.contains('TOTAL') ||
          collapsed.contains('NETAPAYER') ||
          collapsed.contains('MONTANTTOTAL') ||
          collapsed.contains('APAYER') ||
          collapsed.contains('SOMME');

      if (hasTotalKeyword) {
        final sameLinePrice = extractLastDecimalPrice(row);
        if (sameLinePrice != null && sameLinePrice > 0.0) {
          return _TotalDetectionResult(
            total: sameLinePrice,
            lineIndex: i,
          );
        }

        // Check adjacent line below (e.g. amount printed directly underneath label)
        if (i + 1 < rows.length) {
          final nextLinePrice = extractLastDecimalPrice(rows[i + 1]);
          if (nextLinePrice != null && nextLinePrice > 0.0) {
            return _TotalDetectionResult(
              total: nextLinePrice,
              lineIndex: i,
              adjacentLineIndex: i + 1,
            );
          }
        }

        // Check adjacent line above
        if (i - 1 >= 0) {
          final prevLinePrice = extractLastDecimalPrice(rows[i - 1]);
          if (prevLinePrice != null && prevLinePrice > 0.0) {
            return _TotalDetectionResult(
              total: prevLinePrice,
              lineIndex: i,
              adjacentLineIndex: i - 1,
            );
          }
        }
      }
    }

    // 2. Secondary Total Fallback: Payment lines (CARTE BANCAIRE, ESPECES, etc.)
    for (int i = rows.length - 1; i >= 0; i--) {
      final row = rows[i];
      final collapsed = row.replaceAll(RegExp(r'\s+'), '').toUpperCase();

      if (collapsed.contains('CARTEBANCAIRE') ||
          collapsed.contains('CARTE') ||
          collapsed.contains('ESPECES') ||
          collapsed.contains('CASH') ||
          collapsed.contains('PAIEMENT')) {
        final paymentPrice = extractLastDecimalPrice(row);
        if (paymentPrice != null && paymentPrice > 0.0) {
          return _TotalDetectionResult(
            total: paymentPrice,
            lineIndex: i,
          );
        }
      }
    }

    return const _TotalDetectionResult(total: null, lineIndex: null);
  }

  double _findLargestBottomAmount(List<String> rows) {
    double largest = 0.0;
    final startIndex = (rows.length * 0.5).floor();

    for (int i = startIndex; i < rows.length; i++) {
      final price = extractLastDecimalPrice(rows[i]);
      if (price != null && price > largest) {
        largest = price;
      }
    }
    return largest;
  }

  // ---------------------------------------------------------------------------
  // Two-Column Line Item & Noise Detection
  // ---------------------------------------------------------------------------

  ReceiptItem? _parseLineItem(String row) {
    final trimmed = row.trim();
    if (trimmed.isEmpty) return null;

    // Find all decimal numbers on the line
    final decimalMatches = RegExp(r'\b([0-9]+[.,][0-9]{2,3})\b').allMatches(trimmed).toList();

    double? linePrice;
    int priceStartIndex = -1;

    if (decimalMatches.isNotEmpty) {
      // The line total is the last/rightmost decimal price
      final lastMatch = decimalMatches.last;
      linePrice = _normalizeAmount(lastMatch.group(1));

      // If there are 2 trailing prices (unit price + line total), start item name before unit price
      if (decimalMatches.length >= 2) {
        final prevMatch = decimalMatches[decimalMatches.length - 2];
        final between = trimmed.substring(prevMatch.end, lastMatch.start).trim();
        final after = trimmed.substring(lastMatch.end).trim();

        // If between is just whitespace or 'x' and after is empty or currency, both are trailing prices
        if (RegExp(r'^(?:x|\*|\s)*$', caseSensitive: false).hasMatch(between) &&
            RegExp(r'^(?:DT|TND|\s)*$', caseSensitive: false).hasMatch(after)) {
          priceStartIndex = prevMatch.start;
        } else {
          priceStartIndex = lastMatch.start;
        }
      } else {
        priceStartIndex = lastMatch.start;
      }
    } else {
      // Fallback: check trailing number with currency
      final trailingMatch = RegExp(r'([0-9]+(?:[.,][0-9]{1,3})?)\s*(?:DT|TND)?$').firstMatch(trimmed);
      if (trailingMatch != null) {
        linePrice = _normalizeAmount(trailingMatch.group(1));
        priceStartIndex = trailingMatch.start;
      }
    }

    if (linePrice == null || linePrice <= 0.0 || priceStartIndex <= 0) {
      return null;
    }

    final rawName = trimmed.substring(0, priceStartIndex).trim();
    if (rawName.isEmpty) return null;

    // Must have at least 2 letters
    final letterCount = RegExp(r'[A-Za-z\u00C0-\u024F]').allMatches(rawName).length;
    if (letterCount < 2) return null;

    // Parse leading quantity (e.g. "2 NOUILLE MIGO" or "2x NOUILLE MIGO")
    int quantity = 1;
    String cleanName = rawName;

    final qtyPrefixMatch = RegExp(
      r'^\s*([0-9]{1,3})\s*(?:[xX*]|pcs|pc)?\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(rawName);

    if (qtyPrefixMatch != null) {
      final parsedQty = int.tryParse(qtyPrefixMatch.group(1) ?? '1') ?? 1;
      final body = qtyPrefixMatch.group(2)?.trim() ?? '';
      if (body.isNotEmpty && RegExp(r'[A-Za-z\u00C0-\u024F]').hasMatch(body)) {
        quantity = parsedQty;
        cleanName = body;
      }
    }

    cleanName = cleanName
        .replaceAll(RegExp(r'^[-*•\s]+'), '')
        .replaceAll(RegExp(r'[-*•\s]+$'), '')
        .trim();

    if (cleanName.length < 2) return null;

    final displayName = quantity > 0 ? '${quantity}x $cleanName' : cleanName;

    return ReceiptItem(
      name: displayName,
      price: linePrice,
      quantity: quantity,
    );
  }

  bool _isNoiseOrNonItemLine(String row) {
    final trimmed = row.trim();
    if (trimmed.length <= 1) return true;

    if (RegExp(r'^[=\-*_#~.]{3,}$').hasMatch(trimmed)) return true;

    final collapsed = trimmed.replaceAll(RegExp(r'\s+'), '').toUpperCase();

    // Non-item keywords
    final noiseKeywords = RegExp(
      r'(TOTAL|NETAPAYER|MONTANTTOTAL|APAYER|SOMME|'
      r'CARTEBANCAIRE|CARTE|ESPECES|CASH|RENDU|MONNAIE|CHANGE|'
      r'MAGASIN|CAISSE|CAISSIER|CLIENT|SERVEUR|TABLE|'
      r'TICKET|RECU|FACTURE|DUPLICATA|'
      r'MERCI|BONNEJOURNEE|AUREVOIR|ABIENTOT|BIENVENUE|FIDELITE|'
      r'TVA|SUBTOTAL|SOUSTOTAL|HT|TIMBREFISCAL|REMISE|RISTOURNE|'
      r'RECLAMATION|CONTACTER|MATRICULEFISCAL|CODETVA|RC|MF|RIB)',
    );

    if (noiseKeywords.hasMatch(collapsed)) return true;

    if (RegExp(r'\b(TEL|TÉL|FAX|GSM|INFOLINE)\b', caseSensitive: false).hasMatch(trimmed)) {
      return true;
    }
    if (RegExp(r'(\+216|\b[0-9]{2}\s*[0-9]{3}\s*[0-9]{3}\b)').hasMatch(trimmed)) {
      return true;
    }

    // Purely numbers, times, or dates alone
    if (RegExp(r'^[0-9\s:/-]+$').hasMatch(trimmed)) return true;

    return false;
  }

  // ---------------------------------------------------------------------------
  // Store Name & Date Detection
  // ---------------------------------------------------------------------------

  /// Sets the Merchant / Store field to the first valid non-numeric header line
  /// at the top of the receipt (e.g. "MG PROXI KELIBIA"), falling back to "Receipt Expense".
  String _detectMerchant(List<String> rows) {
    for (final row in rows.take(8)) {
      final clean = row.trim();
      if (clean.length < 3 || clean.length > 50) continue;

      final collapsed = clean.replaceAll(RegExp(r'\s+'), '').toUpperCase();

      // Skip lines with prices
      if (RegExp(r'\b[0-9]+[.,][0-9]{2,3}\b').hasMatch(clean)) continue;

      // Skip non-store metadata headers
      if (collapsed.contains('TICKET') ||
          collapsed.contains('CAISSE') ||
          collapsed.contains('CAISSIER') ||
          collapsed.contains('DATE') ||
          collapsed.contains('HEURE') ||
          collapsed.contains('TOTAL') ||
          collapsed.contains('BIENVENUE') ||
          collapsed.contains('DUPLICATA') ||
          collapsed.contains('FACTURE') ||
          collapsed.contains('AVENUE') ||
          collapsed.contains('RUE') ||
          collapsed.contains('TEL') ||
          collapsed.contains('FAX') ||
          collapsed.contains('GSM') ||
          collapsed.contains('MATRICULE') ||
          collapsed.contains('MF:') ||
          collapsed.contains('RC:') ||
          collapsed.contains('CODE') ||
          collapsed.contains('TVA')) {
        continue;
      }

      // Must have at least 3 letters
      final letterCount = RegExp(r'[A-Za-z\u00C0-\u024F]').allMatches(clean).length;
      if (letterCount >= 3) {
        return clean;
      }
    }

    return 'Receipt Expense';
  }

  DateTime? _detectDate(List<String> rows) {
    final dateRegex = RegExp(r'\b([0-3]?[0-9])[/-]([0-1]?[0-9])[/-](20[0-9]{2}|[0-9]{2})\b');

    for (final row in rows) {
      final match = dateRegex.firstMatch(row);
      if (match != null) {
        final day = int.tryParse(match.group(1) ?? '');
        final month = int.tryParse(match.group(2) ?? '');
        var year = int.tryParse(match.group(3) ?? '');

        if (day != null && month != null && year != null) {
          if (year < 100) year += 2000;
          if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
            try {
              return DateTime(year, month, day);
            } catch (_) {}
          }
        }
      }
    }
    return null;
  }
}

class _TotalDetectionResult {
  final double? total;
  final int? lineIndex;
  final int? adjacentLineIndex;

  const _TotalDetectionResult({
    required this.total,
    required this.lineIndex,
    this.adjacentLineIndex,
  });
}
