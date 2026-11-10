import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UtilityInvoice {
  final String id;
  final String title;
  final String provider;
  final double amount;
  final String dueDate;
  bool isPaid;

  UtilityInvoice({
    required this.id,
    required this.title,
    required this.provider,
    required this.amount,
    required this.dueDate,
    this.isPaid = false,
  });

  IconData get icon {
    final p = provider.toLowerCase();
    if (p.contains('sonede') || title.toLowerCase().contains('water')) {
      return Icons.water_drop_outlined;
    }
    if (p.contains('topnet') ||
        p.contains('fibre') ||
        title.toLowerCase().contains('wifi')) {
      return Icons.wifi;
    }
    if (p.contains('steg') || title.toLowerCase().contains('electr')) {
      return Icons.bolt;
    }
    return Icons.receipt_long_outlined;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'provider': provider,
        'amount': amount,
        'dueDate': dueDate,
        'isPaid': isPaid,
      };

  factory UtilityInvoice.fromJson(Map<String, dynamic> json) => UtilityInvoice(
        id: json['id'] as String,
        title: json['title'] as String,
        provider: json['provider'] as String,
        amount: (json['amount'] as num).toDouble(),
        dueDate: json['dueDate'] as String,
        isPaid: json['isPaid'] as bool,
      );
}

class SupplyItem {
  final String id;
  final String name;
  bool isChecked;
  final String category;

  SupplyItem({
    required this.id,
    required this.name,
    this.isChecked = false,
    this.category = 'General',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isChecked': isChecked,
        'category': category,
      };

  factory SupplyItem.fromJson(Map<String, dynamic> json) => SupplyItem(
        id: json['id'] as String,
        name: json['name'] as String,
        isChecked: json['isChecked'] as bool? ?? false,
        category: json['category'] as String? ?? 'General',
      );
}

/// Manages flat utilities, invoices, auto-splits, and communal supplies checklist with persistence.
class UtilitiesController extends ChangeNotifier {
  static const _invoicesKey = 'utilities_invoices_v1';
  static const _suppliesKey = 'utilities_supplies_v1';

  final List<UtilityInvoice> _invoices = [];
  final List<SupplyItem> _supplies = [];
  bool _isLoaded = false;

  UtilitiesController() {
    _initFromStorage();
  }

  bool get isLoaded => _isLoaded;
  bool get isEmpty => _invoices.isEmpty;

  List<UtilityInvoice> get invoices => List.unmodifiable(_invoices);
  List<SupplyItem> get supplies => List.unmodifiable(_supplies);

  /// Active cycle total amount. If empty, safely returns 0.000.
  double get activeCycleTotal =>
      _invoices.fold(0.0, (sum, inv) => sum + inv.amount);

  /// Total unpaid invoices.
  double get unpaidTotal => _invoices
      .where((inv) => !inv.isPaid)
      .fold(0.0, (sum, inv) => sum + inv.amount);

  Future<void> _initFromStorage() async {
    final prefs = await SharedPreferences.getInstance();

    final rawInvoices = prefs.getStringList(_invoicesKey);
    if (rawInvoices != null) {
      _invoices.clear();
      for (final item in rawInvoices) {
        try {
          _invoices.add(UtilityInvoice.fromJson(
              jsonDecode(item) as Map<String, dynamic>));
        } catch (_) {}
      }
    }

    final rawSupplies = prefs.getStringList(_suppliesKey);
    if (rawSupplies != null) {
      _supplies.clear();
      for (final item in rawSupplies) {
        try {
          _supplies.add(
              SupplyItem.fromJson(jsonDecode(item) as Map<String, dynamic>));
        } catch (_) {}
      }
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _saveInvoicesToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _invoices.map((inv) => jsonEncode(inv.toJson())).toList();
    await prefs.setStringList(_invoicesKey, encoded);
  }

  Future<void> _saveSuppliesToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _supplies.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_suppliesKey, encoded);
  }

  /// Marks a specific utility bill as paid.
  void payBill(String id) {
    final index = _invoices.indexWhere((inv) => inv.id == id);
    if (index != -1) {
      _invoices[index].isPaid = true;
      notifyListeners();
      _saveInvoicesToStorage();
    }
  }

  /// Adds a new utility bill and updates active cycle.
  void addInvoice({
    required String title,
    required String provider,
    required double amount,
    required String dueDate,
  }) {
    _invoices.insert(
      0,
      UtilityInvoice(
        id: 'inv-${DateTime.now().millisecondsSinceEpoch}',
        title: title.trim(),
        provider: provider.trim(),
        amount: amount,
        dueDate: dueDate.trim().isEmpty ? 'Due soon' : dueDate.trim(),
      ),
    );
    notifyListeners();
    _saveInvoicesToStorage();
  }

  /// Calculates per-roommate share (e.g. split across 3 flatmates).
  double autoSplit({int roommateCount = 3}) {
    if (roommateCount <= 0 || _invoices.isEmpty) return 0.0;
    return activeCycleTotal / roommateCount;
  }

  /// Toggles shared supply item checkbox.
  void toggleSupply(String id) {
    final index = _supplies.indexWhere((s) => s.id == id);
    if (index != -1) {
      _supplies[index].isChecked = !_supplies[index].isChecked;
      notifyListeners();
      _saveSuppliesToStorage();
    }
  }

  /// Adds a new item to the supplies checklist.
  void addSupply(String name) {
    if (name.trim().isNotEmpty) {
      _supplies.add(
        SupplyItem(
          id: 'sup-${DateTime.now().millisecondsSinceEpoch}',
          name: name.trim(),
          isChecked: false,
        ),
      );
      notifyListeners();
      _saveSuppliesToStorage();
    }
  }

  /// Clears invoices for clean zero-base testing.
  void clearAllInvoices() {
    _invoices.clear();
    notifyListeners();
    _saveInvoicesToStorage();
  }
}
