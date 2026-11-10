import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/utilities_controller.dart';

/// Screen 5: Student Utilities View
class UtilitiesView extends StatelessWidget {
  const UtilitiesView({super.key});

  @override
  Widget build(BuildContext context) {
    return const StudentUtilities();
  }
}

class StudentUtilities extends StatefulWidget {
  const StudentUtilities({super.key});

  @override
  State<StudentUtilities> createState() => _StudentUtilitiesState();
}

class _StudentUtilitiesState extends State<StudentUtilities> {
  final _newSupplyController = TextEditingController();

  void _showAddSupplyDialog(
      BuildContext context, UtilitiesController controller) {
    _newSupplyController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Shared Flat Supply',
            style: TextStyle(
                color: Color(0xFFE0E2EC), fontWeight: FontWeight.w800)),
        content: TextField(
          controller: _newSupplyController,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFE0E2EC), fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Item Name (e.g. Olive Oil, Salt)',
            hintStyle: const TextStyle(color: Color(0xFF888B98)),
            filled: true,
            fillColor: const Color(0xFF161A22),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF888B98))),
          ),
          ElevatedButton(
            onPressed: () {
              if (_newSupplyController.text.trim().isNotEmpty) {
                controller.addSupply(_newSupplyController.text.trim());
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE2F952),
              foregroundColor: const Color(0xFF10131A),
            ),
            child: const Text('Add to List',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showAddBillModal(BuildContext context, UtilitiesController controller) {
    final titleCtrl = TextEditingController();
    final providerCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final dueCtrl = TextEditingController(text: 'Due in 7 days');
    bool autoSplitChecked = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1F2B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx2).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add Shared Bill / Auto Split',
                style: TextStyle(
                  color: Color(0xFFE0E2EC),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: Color(0xFFE0E2EC), fontSize: 14),
                decoration: _modalInputDecoration(
                    'Bill Title (e.g. Wi-Fi Plan, Heating Gas)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: providerCtrl,
                style: const TextStyle(color: Color(0xFFE0E2EC), fontSize: 14),
                decoration: _modalInputDecoration(
                    'Utility Provider (e.g. STEG, SONEDE, Topnet)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Color(0xFFE0E2EC), fontSize: 14),
                decoration: _modalInputDecoration('Total Amount (DT)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dueCtrl,
                style: const TextStyle(color: Color(0xFFE0E2EC), fontSize: 14),
                decoration:
                    _modalInputDecoration('Due Date (e.g. Due next Friday)'),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: const Color(0xFFE2F952),
                checkColor: const Color(0xFF10131A),
                title: const Text(
                  'Auto-split evenly across 3 flatmates',
                  style: TextStyle(
                      color: Color(0xFFE0E2EC),
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Calculates 1/3 share per resident automatically',
                  style: TextStyle(color: Color(0xFF888B98), fontSize: 11),
                ),
                value: autoSplitChecked,
                onChanged: (v) =>
                    setModalState(() => autoSplitChecked = v ?? true),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                    if (titleCtrl.text.trim().isNotEmpty && amt > 0) {
                      controller.addInvoice(
                        title: titleCtrl.text.trim(),
                        provider: providerCtrl.text.trim().isEmpty
                            ? 'Shared'
                            : providerCtrl.text.trim(),
                        amount: amt,
                        dueDate: dueCtrl.text.trim(),
                      );
                      Navigator.pop(ctx2);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(autoSplitChecked
                              ? '⚡ Added & auto-split: ${(amt / 3).toStringAsFixed(3)} DT per flatmate'
                              : '⚡ Added utility bill!'),
                          backgroundColor: const Color(0xFFE2F952),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE2F952),
                    foregroundColor: const Color(0xFF10131A),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save & Post Bill',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _modalInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF888B98), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF161A22),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    );
  }

  void _showSplitSummary(BuildContext context, UtilitiesController controller) {
    final splitAmt = controller.autoSplit(roommateCount: 3);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F2B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Utilities Split (3 Flatmates)',
              style: TextStyle(
                  color: Color(0xFFE0E2EC),
                  fontSize: 18,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              'Each roommate owes: ${splitAmt.toStringAsFixed(3)} DT',
              style: const TextStyle(
                  color: Color(0xFFE2F952),
                  fontSize: 20,
                  fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '📲 Notification broadcast to Sarah & Yassine (${splitAmt.toStringAsFixed(3)} DT each)!'),
                    backgroundColor: const Color(0xFFE2F952),
                  ),
                );
              },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Broadcast Ping to Flatmates',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE2F952),
                foregroundColor: const Color(0xFF10131A),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _newSupplyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    UtilitiesController? controller;
    try {
      controller = context.watch<UtilitiesController>();
    } catch (_) {}

    final activeCycleTotal = controller?.activeCycleTotal ?? 0.000;
    final invoices = controller?.invoices ?? [];
    final supplies = controller?.supplies ?? [];
    final isEmpty = invoices.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF10131A),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Header ────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Student Utilities',
                          style: TextStyle(
                            color: Color(0xFFE0E2EC),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Invoices, Bills & Shared Stock',
                          style:
                              TextStyle(color: Color(0xFF888B98), fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      if (controller != null)
                        _showSplitSummary(context, controller);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0x1FE2F952),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.call_split,
                              color: Color(0xFFE2F952), size: 15),
                          SizedBox(width: 4),
                          Text('Auto Split',
                              style: TextStyle(
                                  color: Color(0xFFE2F952),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Active Cycle Total Card ────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F2B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF232A3B)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ACTIVE UTILITY CYCLE',
                      style: TextStyle(
                        color: Color(0xFF888B98),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${activeCycleTotal.toStringAsFixed(3)} DT',
                      style: const TextStyle(
                        color: Color(0xFFE0E2EC),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Total monthly bills to be split evenly across flatmates',
                      style: TextStyle(color: Color(0xFF888B98), fontSize: 12),
                    ),
                    const SizedBox(height: 16),

                    // Badges wrapped in Wrap to eliminate overflow
                    Builder(builder: (_) {
                      final powerAmt = invoices
                          .where((i) =>
                              i.title.toLowerCase().contains('electr') ||
                              i.provider.toLowerCase().contains('steg'))
                          .fold(0.0, (sum, i) => sum + i.amount);
                      final fibreAmt = invoices
                          .where((i) =>
                              i.title.toLowerCase().contains('fibre') ||
                              i.provider.toLowerCase().contains('topnet') ||
                              i.title.toLowerCase().contains('wifi'))
                          .fold(0.0, (sum, i) => sum + i.amount);
                      final waterAmt = invoices
                          .where((i) =>
                              i.title.toLowerCase().contains('water') ||
                              i.provider.toLowerCase().contains('sonede'))
                          .fold(0.0, (sum, i) => sum + i.amount);
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _breakdownPill(
                              'Power',
                              '${powerAmt.toStringAsFixed(3)} DT',
                              powerAmt > 0
                                  ? const Color(0xFFE2F952)
                                  : const Color(0xFF888B98)),
                          _breakdownPill(
                              'Fibre',
                              '${fibreAmt.toStringAsFixed(3)} DT',
                              fibreAmt > 0
                                  ? const Color(0xFF7EB4FF)
                                  : const Color(0xFF888B98)),
                          _breakdownPill(
                              'Water',
                              '${waterAmt.toStringAsFixed(3)} DT',
                              waterAmt > 0
                                  ? const Color(0xFFFF8C42)
                                  : const Color(0xFF888B98)),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Invoices Section ──────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'MONTHLY INVOICES',
                    style: TextStyle(
                      color: Color(0xFF888B98),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (controller != null)
                        _showAddBillModal(context, controller);
                    },
                    child: const Text(
                      '+ Add Bill',
                      style: TextStyle(
                          color: Color(0xFFE2F952),
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Empty state handling for invoices
              if (isEmpty)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F2B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF232A3B)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0x1FE2F952),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_outline,
                            color: Color(0xFFE2F952), size: 24),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'All utilities settled! No pending invoices.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFE0E2EC),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap "+ Add Bill" to record a new utility invoice for the flat.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Color(0xFF888B98), fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          if (controller != null)
                            _showAddBillModal(context, controller);
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('+ Add Bill / Auto Split',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE2F952),
                          foregroundColor: const Color(0xFF10131A),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...invoices.map((inv) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F2B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: inv.isPaid
                            ? const Color(0xFF232A3B)
                            : const Color(0x33E2F952),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Leading icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF161A22),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(inv.icon,
                              color: const Color(0xFFE2F952), size: 20),
                        ),
                        const SizedBox(width: 12),
                        // Flexible/Expanded title section to prevent overflow
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${inv.title} (${inv.provider})',
                                style: const TextStyle(
                                  color: Color(0xFFE0E2EC),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                inv.dueDate,
                                style: const TextStyle(
                                    color: Color(0xFF888B98), fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Trailing amount & action
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${inv.amount.toStringAsFixed(3)} DT',
                              style: const TextStyle(
                                color: Color(0xFFE0E2EC),
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            inv.isPaid
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0x284CAF50),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('Paid',
                                        style: TextStyle(
                                            color: Color(0xFF4CAF50),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700)),
                                  )
                                : GestureDetector(
                                    onTap: () => controller?.payBill(inv.id),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE2F952),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Pay Now',
                                        style: TextStyle(
                                          color: Color(0xFF10131A),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 20),

              // ── Supply & Grocery Checklist ────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SHARED SUPPLIES & GROCERY LIST',
                    style: TextStyle(
                      color: Color(0xFF888B98),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (controller != null)
                        _showAddSupplyDialog(context, controller);
                    },
                    child: const Text(
                      '+ Add Item',
                      style: TextStyle(
                          color: Color(0xFFE2F952),
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F2B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF232A3B)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: supplies.isEmpty
                        ? [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Column(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: const BoxDecoration(
                                        color: Color(0x1FE2F952),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                          Icons.shopping_basket_outlined,
                                          color: Color(0xFFE2F952),
                                          size: 18),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'No shared supplies logged yet.',
                                      style: TextStyle(
                                          color: Color(0xFFE0E2EC),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Tap "+ Add Item" above to add items to the flat grocery list.',
                                      style: TextStyle(
                                          color: Color(0xFF888B98),
                                          fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ]
                        : supplies.map((s) {
                            return CheckboxListTile(
                              dense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              activeColor: const Color(0xFFE2F952),
                              checkColor: const Color(0xFF10131A),
                              title: Text(
                                s.name,
                                style: TextStyle(
                                  color: s.isChecked
                                      ? const Color(0xFF888B98)
                                      : const Color(0xFFE0E2EC),
                                  fontSize: 13,
                                  decoration: s.isChecked
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              value: s.isChecked,
                              onChanged: (_) => controller?.toggleSupply(s.id),
                            );
                          }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _breakdownPill(String label, String amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            '$label: $amount',
            style: const TextStyle(
                color: Color(0xFFE0E2EC),
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
