import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../controllers/budget_controller.dart';
import '../services/receipt_ocr_service.dart';
import '../ui/views/receipt_viewer_dialog.dart';

/// Modal bottom sheet for scanning, reviewing, editing, and saving OCR receipts.
class ReceiptReviewSheet extends StatefulWidget {
  final BudgetController budget;
  final ParsedReceipt parsedReceipt;

  const ReceiptReviewSheet({
    super.key,
    required this.budget,
    required this.parsedReceipt,
  });

  /// Entry point to trigger the full camera/gallery capture + OCR scan flow.
  static Future<void> showCaptureFlow(
    BuildContext context,
    BudgetController budget,
  ) async {
    HapticFeedback.lightImpact();

    // 1. Show source selection sheet (Camera vs Gallery vs PC Sample)
    final dynamic result = await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _ReceiptSourcePickerModal(),
    );

    if (result == null || !context.mounted) return;

    if (result == 'sample_mg') {
      final parsed = ReceiptOcrService.instance.getSampleMgReceipt();
      await show(context, budget, parsedReceipt: parsed);
      return;
    }

    final ImageSource source = result as ImageSource;

    // 2. Pick the image
    XFile? pickedFile;
    try {
      final picker = ImagePicker();
      pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 90, // Crisp thermal receipt text
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not access image: $e'),
          backgroundColor: AppColors.expenseRed,
        ),
      );
      return;
    }

    if (pickedFile == null || !context.mounted) return;

    // 3. Show sleek "Scanning receipt..." loading indicator
    BuildContext? dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return const _OcrScanningDialog();
      },
    );

    ParsedReceipt parsed;
    try {
      parsed = await ReceiptOcrService.instance.scanReceipt(pickedFile);
    } catch (e) {
      // Fallback: graceful degraded receipt with attached image
      parsed = ParsedReceipt(
        merchant: 'Receipt Expense',
        items: [],
        total: 0.0,
        imagePath: pickedFile.path,
      );
    } finally {
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      } else if (context.mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    }

    if (!context.mounted) return;

    // 4. Open the editable confirmation sheet
    await show(context, budget, parsedReceipt: parsed);
  }

  /// Displays the review bottom sheet modal with the given [ParsedReceipt].
  static Future<void> show(
    BuildContext context,
    BudgetController budget, {
    required ParsedReceipt parsedReceipt,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReceiptReviewSheet(
        budget: budget,
        parsedReceipt: parsedReceipt,
      ),
    );
  }

  @override
  State<ReceiptReviewSheet> createState() => _ReceiptReviewSheetState();
}

class _ReceiptReviewSheetState extends State<ReceiptReviewSheet> {
  late final TextEditingController _merchantController;
  late final TextEditingController _totalController;
  late final FocusNode _totalFocusNode;
  final List<_ItemControllers> _itemControllers = [];
  bool _isUpdatingProgrammatically = false;

  static const List<String> _categories = [
    'Food & Groceries',
    'Resto / Café',
    'Transport',
    'Supplies',
    'Housing & Utilities',
    'Other',
  ];

  late String _selectedCategory;
  late DateTime _selectedDate;
  bool _isManualTotalOverride = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _totalFocusNode = FocusNode();
    _merchantController = TextEditingController(text: widget.parsedReceipt.merchant);
    _selectedDate = widget.parsedReceipt.date ?? DateTime.now();

    // Select category matching merchant
    _selectedCategory = _resolveInitialCategory(widget.parsedReceipt.merchant);

    // Initialize item controllers
    for (final item in widget.parsedReceipt.items) {
      _addItemToState(item.name, item.price);
    }

    final initialTotal = widget.parsedReceipt.total > 0
        ? widget.parsedReceipt.total
        : _calculateItemsSum();

    _totalController = TextEditingController(
      text: initialTotal > 0 ? initialTotal.toStringAsFixed(3) : '',
    );

    _totalController.addListener(_onTotalUserEdited);
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _totalController.dispose();
    _totalFocusNode.dispose();
    for (final c in _itemControllers) {
      c.dispose();
    }
    super.dispose();
  }

  String _resolveInitialCategory(String merchant) {
    final lower = merchant.toLowerCase();
    if (lower.contains('carrefour') ||
        lower.contains('monoprix') ||
        lower.contains('aziza') ||
        lower.contains('mg') ||
        lower.contains('superette') ||
        lower.contains('boulangerie') ||
        lower.contains('epicerie')) {
      return 'Food & Groceries';
    }
    if (lower.contains('café') ||
        lower.contains('resto') ||
        lower.contains('restaurant') ||
        lower.contains('pizza') ||
        lower.contains('fast food')) {
      return 'Resto / Café';
    }
    if (lower.contains('fnac') ||
        lower.contains('librairie') ||
        lower.contains('papeterie')) {
      return 'Supplies';
    }
    return _categories[0];
  }

  void _onTotalUserEdited() {
    if (!_isUpdatingProgrammatically && _totalFocusNode.hasFocus) {
      _isManualTotalOverride = true;
    }
  }

  void _addItemToState(String name, double price) {
    final nameCtrl = TextEditingController(text: name);
    final priceCtrl = TextEditingController(
      text: price > 0 ? price.toStringAsFixed(3) : '',
    );

    final itemCtrl = _ItemControllers(nameCtrl: nameCtrl, priceCtrl: priceCtrl);

    priceCtrl.addListener(() {
      _recalculateTotalIfAutomatic();
    });

    _itemControllers.add(itemCtrl);
  }

  void _removeItemAt(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      final removed = _itemControllers.removeAt(index);
      removed.dispose();
      _recalculateTotalIfAutomatic();
    });
  }

  void _addNewBlankItem() {
    HapticFeedback.lightImpact();
    setState(() {
      _addItemToState('', 0.0);
    });
  }

  double _calculateItemsSum() {
    double sum = 0.0;
    for (final c in _itemControllers) {
      final raw = c.priceCtrl.text.replaceAll(',', '.').trim();
      final p = double.tryParse(raw);
      if (p != null && p > 0.0) {
        sum += p;
      }
    }
    return sum;
  }

  void _recalculateTotalIfAutomatic() {
    if (!_isManualTotalOverride) {
      final sum = _calculateItemsSum();
      _isUpdatingProgrammatically = true;
      _totalController.text = sum > 0.0 ? sum.toStringAsFixed(3) : '0.000';
      _isUpdatingProgrammatically = false;
    }
  }

  void _onSave() {
    HapticFeedback.mediumImpact();
    final merchant = _merchantController.text.trim();
    final rawTotal = _totalController.text.trim().replaceAll(',', '.');
    final total = double.tryParse(rawTotal) ?? _calculateItemsSum();

    if (merchant.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a merchant or expense title';
      });
      return;
    }

    if (total <= 0.0) {
      setState(() {
        _errorMessage = 'Please enter a valid expense total amount in DT';
      });
      return;
    }

    // Build itemized breakdown summary
    final itemDescriptions = <String>[];
    for (final c in _itemControllers) {
      final n = c.nameCtrl.text.trim();
      final rawP = c.priceCtrl.text.replaceAll(',', '.').trim();
      final p = double.tryParse(rawP);
      if (n.isNotEmpty) {
        itemDescriptions.add(p != null && p > 0 ? '$n (${p.toStringAsFixed(3)} DT)' : n);
      }
    }

    // Map UI category to BudgetController internal categories
    String mappedCategory = _selectedCategory;
    if (_selectedCategory == 'Food & Groceries' || _selectedCategory == 'Resto / Café') {
      mappedCategory = 'Campus Dining & Groceries';
    } else if (_selectedCategory == 'Transport') {
      mappedCategory = 'Social & Commute';
    } else if (_selectedCategory == 'Supplies') {
      mappedCategory = 'Books & Tools';
    } else if (_selectedCategory == 'Housing & Utilities') {
      mappedCategory = 'Housing & Utilities';
    }

    // Add expense to controller
    widget.budget.addExpense(
      title: merchant,
      amount: total,
      category: mappedCategory,
      date: _selectedDate,
      imagePath: widget.parsedReceipt.imagePath,
    );

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added ${total.toStringAsFixed(3)} DT expense at $merchant',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.deepPine,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final hasImage = widget.parsedReceipt.imagePath != null &&
        widget.parsedReceipt.imagePath!.isNotEmpty;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Forest Green Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 16),
            decoration: const BoxDecoration(
              color: AppColors.darkForest,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.softSage.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.deepPine,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.document_scanner_rounded,
                        color: AppColors.vibrantGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Receipt Review',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Verified on-device with ML Kit OCR',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.softSage,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasImage)
                      GestureDetector(
                        onTap: () {
                          ReceiptViewerDialog.show(
                            context,
                            ExpenseItem(
                              id: 'preview',
                              title: _merchantController.text.trim().isEmpty
                                  ? 'Receipt'
                                  : _merchantController.text.trim(),
                              amount: double.tryParse(_totalController.text) ?? 0.0,
                              category: _selectedCategory,
                              date: _selectedDate,
                              imagePath: widget.parsedReceipt.imagePath,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.deepPine,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.midMoss.withOpacity(0.6),
                                width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.image_outlined,
                                  color: AppColors.vibrantGreen, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'View Photo',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.softSage, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Scrollable Form Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.expenseRed.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.expenseRed.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.expenseRed, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.expenseRed,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Merchant Field
                  Text(
                    'MERCHANT / STORE',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.softSage,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.sandCream),
                    ),
                    child: TextField(
                      key: const ValueKey('receipt_merchant_field'),
                      controller: _merchantController,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.darkForest,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Carrefour, Monoprix, Café...',
                        prefixIcon: Icon(Icons.storefront_outlined,
                            color: AppColors.deepPine, size: 20),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Grand Total Field Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.midMoss.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'GRAND TOTAL',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppColors.deepPine,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (!_isManualTotalOverride &&
                                      _itemControllers.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.vibrantGreen
                                            .withOpacity(0.15),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Auto-Sum',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: AppColors.deepPine,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                key: const ValueKey('receipt_total_field'),
                                controller: _totalController,
                                focusNode: _totalFocusNode,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.darkForest,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '0.000',
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'DT',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.deepPine,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Extracted Items Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'DETECTED ITEMS (${_itemControllers.length})',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.softSage,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      TextButton.icon(
                        key: const ValueKey('receipt_add_item_btn'),
                        onPressed: _addNewBlankItem,
                        icon: const Icon(Icons.add_circle_outline_rounded,
                            size: 16, color: AppColors.deepPine),
                        label: Text(
                          'Add Item',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.deepPine,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_itemControllers.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.sandCream),
                      ),
                      child: Text(
                        'No individual line items parsed. You can tap "+ Add Item" or save using the Grand Total above.',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.softSage,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    ..._itemControllers.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final c = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            // Item Name
                            Expanded(
                              flex: 6,
                              child: Container(
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: AppColors.sandCream),
                                ),
                                child: TextField(
                                  key: ValueKey('item_name_$idx'),
                                  controller: c.nameCtrl,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.darkForest,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Item description',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Item Price
                            Expanded(
                              flex: 3,
                              child: Container(
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: AppColors.sandCream),
                                ),
                                child: TextField(
                                  key: ValueKey('item_price_$idx'),
                                  controller: c.priceCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.darkForest,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: '0.000',
                                    suffixText: 'DT',
                                    suffixStyle: TextStyle(
                                      color: AppColors.softSage,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 10),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Delete Item
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: AppColors.expenseRed, size: 18),
                              onPressed: () => _removeItemAt(idx),
                              tooltip: 'Delete item',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 18),

                  // Category Selector Chips
                  Text(
                    'CATEGORY',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.softSage,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      final isSelected = cat == _selectedCategory;
                      return ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedCategory = cat;
                            });
                          }
                        },
                        selectedColor: AppColors.deepPine,
                        backgroundColor: Colors.white,
                        labelStyle: GoogleFonts.plusJakartaSans(
                          color: isSelected ? Colors.white : AppColors.darkOlive,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                        side: BorderSide(
                          color: isSelected ? AppColors.deepPine : AppColors.sandCream,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Save Expense Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      key: const ValueKey('receipt_save_btn'),
                      onPressed: _onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepPine,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Save Expense',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemControllers {
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;

  _ItemControllers({required this.nameCtrl, required this.priceCtrl});

  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
  }
}

/// Source selection modal for Camera vs Gallery
class _ReceiptSourcePickerModal extends StatelessWidget {
  const _ReceiptSourcePickerModal();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.sandCream,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.deepPine.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.deepPine,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scan Receipt',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.darkForest,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Choose capture method for on-device OCR',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.softSage,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SourceOptionCard(
            icon: Icons.photo_camera_rounded,
            title: 'Take Photo (Camera)',
            subtitle: 'Optimized for thermal receipts (90% quality)',
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          const SizedBox(height: 12),
          _SourceOptionCard(
            icon: Icons.photo_library_rounded,
            title: 'Choose from Gallery / PC Files',
            subtitle: 'Select receipt photo or screenshot',
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          if (kIsWeb || (!kIsWeb && !Platform.isAndroid && !Platform.isIOS)) ...[
            const SizedBox(height: 12),
            _SourceOptionCard(
              icon: Icons.receipt_long_rounded,
              title: 'Test Real MG Proxi Receipt (PC Mode)',
              subtitle: 'Instantly test real MG Kelibia receipt data',
              onTap: () => Navigator.of(context).pop('sample_mg'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.sandCream.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.deepPine,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.vibrantGreen, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.darkForest,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.softSage,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: AppColors.softSage, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sleek dialog shown while ML Kit is parsing receipt
class _OcrScanningDialog extends StatelessWidget {
  const _OcrScanningDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.darkForest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.vibrantGreen),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Scanning receipt...',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Extracting items & total with on-device OCR',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.softSage,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
