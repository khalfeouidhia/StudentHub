import 'package:flutter/material.dart';

/// Models for Home Dashboard
class RoommateBalance {
  final String name;
  final double amount; // positive if they owe you, negative if you owe them
  final String currency;

  const RoommateBalance({
    required this.name,
    required this.amount,
    this.currency = 'DT',
  });

  bool get isPositive => amount >= 0;
  String get formattedAmount =>
      '${amount >= 0 ? '+' : ''}${amount.toStringAsFixed(3)} $currency';
}

class FocusTask {
  final String title;
  final String dueInfo;
  final bool isCompleted;

  const FocusTask({
    required this.title,
    required this.dueInfo,
    this.isCompleted = false,
  });

  FocusTask copyWith({bool? isCompleted}) {
    return FocusTask(
      title: title,
      dueInfo: dueInfo,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class HomeDashboardData {
  final String userName;
  final String flatName;
  final String rentDueText;
  final List<String> roommates;
  final String pinnedMessage;
  final List<String> pinnedActions;
  final double spentSoFar;
  final double totalCap;
  final double safeBuffer;
  final String currency;
  final List<RoommateBalance> balances;
  final List<FocusTask> focusTasks;

  const HomeDashboardData({
    required this.userName,
    required this.flatName,
    required this.rentDueText,
    required this.roommates,
    required this.pinnedMessage,
    required this.pinnedActions,
    required this.spentSoFar,
    required this.totalCap,
    required this.safeBuffer,
    this.currency = 'DT',
    required this.balances,
    required this.focusTasks,
  });

  double get spentPercentage => (spentSoFar / totalCap).clamp(0.0, 1.0);
}

/// Home state controller
class HomeController extends ChangeNotifier {
  late HomeDashboardData _data;

  HomeController({HomeDashboardData? initialData}) {
    _data = initialData ??
        HomeDashboardData(
          userName: 'Alex',
          flatName: 'Shared Flat',
          rentDueText: 'Rent due in 4 days',
          roommates: const ['Alex', 'Sarah', 'Yassine'],
          pinnedMessage:
              'Wifi bill is paid for this month. Please log grocery receipts before Sunday!',
          pinnedActions: const ['Details', 'Acknowledge'],
          spentSoFar: 380.000,
          totalCap: 650.000,
          safeBuffer: 270.000,
          currency: 'DT',
          balances: const [
            RoommateBalance(name: 'Yassine', amount: 35.500),
            RoommateBalance(name: 'Sarah', amount: -12.000),
          ],
          focusTasks: const [
            FocusTask(title: 'CS301 Project Submission', dueInfo: 'Due in 6h'),
          ],
        );
  }

  HomeDashboardData get data => _data;

  void toggleTask(int index) {
    if (index >= 0 && index < _data.focusTasks.length) {
      final updatedList = List<FocusTask>.from(_data.focusTasks);
      final current = updatedList[index];
      updatedList[index] = current.copyWith(isCompleted: !current.isCompleted);
      _data = HomeDashboardData(
        userName: _data.userName,
        flatName: _data.flatName,
        rentDueText: _data.rentDueText,
        roommates: _data.roommates,
        pinnedMessage: _data.pinnedMessage,
        pinnedActions: _data.pinnedActions,
        spentSoFar: _data.spentSoFar,
        totalCap: _data.totalCap,
        safeBuffer: _data.safeBuffer,
        currency: _data.currency,
        balances: _data.balances,
        focusTasks: updatedList,
      );
      notifyListeners();
    }
  }

  void nudgeRoommate(String name) {
    // Logic for sending nudge notification
    notifyListeners();
  }

  void settleBalance(String name) {
    // Logic for settling balance
    notifyListeners();
  }
}

/// Responsive Home View implementation meeting design specifications
class ResponsiveHomeView extends StatelessWidget {
  final HomeDashboardData data;
  final ValueChanged<int>? onToggleFocusTask;
  final ValueChanged<String>? onNudge;
  final ValueChanged<String>? onSettle;
  final VoidCallback? onExpensesTap;
  final VoidCallback? onSplitBillTap;
  final VoidCallback? onWifiKitTap;
  final VoidCallback? onLogChoreTap;

  const ResponsiveHomeView({
    super.key,
    required this.data,
    this.onToggleFocusTask,
    this.onNudge,
    this.onSettle,
    this.onExpensesTap,
    this.onSplitBillTap,
    this.onWifiKitTap,
    this.onLogChoreTap,
  });

  static const Color darkBg = Color(0xFF10131A);
  static const Color cardBg = Color(0xFF1A1F2B);
  static const Color accentLime = Color(0xFFD4F34A);
  static const Color alertRed = Color(0xFFD32F2F);
  static const Color textMuted = Color(0xFF9E9E88);
  static const Color textLight = Color(0xFFE0E2EC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildHouseBoard(),
              const SizedBox(height: 16),
              _buildMonthlyLivingPoolCard(),
              const SizedBox(height: 16),
              _buildQuickActionsRow(),
              const SizedBox(height: 16),
              _buildRoommateBalancesCard(),
              const SizedBox(height: 16),
              _buildTodaysFocusCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good evening, ${data.userName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.flatName,
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: alertRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: alertRed.withValues(alpha: 0.6)),
              ),
              child: Text(
                data.rentDueText,
                style: const TextStyle(
                  color: Color(0xFFFF5252),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Roommate Presence Row
        Row(
          children: [
            const Text(
              'Roommate Presence: ',
              style: TextStyle(
                color: textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: data.roommates.map((name) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        avatar: CircleAvatar(
                          backgroundColor: accentLime,
                          radius: 10,
                          child: Text(
                            name.isNotEmpty ? name[0] : '?',
                            style: const TextStyle(
                              color: Color(0xFF10131A),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        label: Text(
                          name,
                          style: const TextStyle(
                            color: textLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: const Color(0xFF161A22),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHouseBoard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.push_pin, color: accentLime, size: 16),
              SizedBox(width: 8),
              Text(
                'House Board',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.pinnedMessage,
            style: const TextStyle(
              color: textLight,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: data.pinnedActions.map((action) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF252A36),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  action,
                  style: const TextStyle(
                    color: accentLime,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyLivingPoolCard() {
    final percentage = (data.spentPercentage * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Text(
            'Monthly Living Pool',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          // Circular Progress Ring
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: CircularProgressIndicator(
                  value: data.spentPercentage,
                  strokeWidth: 12,
                  backgroundColor: const Color(0xFF282E3D),
                  valueColor: const AlwaysStoppedAnimation<Color>(accentLime),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'SPENT SO FAR',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${data.spentSoFar.toStringAsFixed(3)} ${data.currency}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$percentage%',
                    style: const TextStyle(
                      color: accentLime,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Bottom Summary Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF131720),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Cap',
                        style: TextStyle(color: textMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${data.totalCap.toStringAsFixed(3)} ${data.currency}',
                        style: const TextStyle(
                          color: textLight,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.white12,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Safe Buffer',
                        style: TextStyle(color: textMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${data.safeBuffer.toStringAsFixed(3)} ${data.currency}',
                        style: const TextStyle(
                          color: accentLime,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow() {
    return Row(
      children: [
        _buildActionPill(
          icon: Icons.receipt_long,
          label: 'Expenses',
          onTap: onExpensesTap,
        ),
        const SizedBox(width: 8),
        _buildActionPill(
          icon: Icons.call_split,
          label: 'Split Bill',
          onTap: onSplitBillTap,
        ),
        const SizedBox(width: 8),
        _buildActionPill(
          icon: Icons.wifi,
          label: 'Wi-Fi Kit',
          onTap: onWifiKitTap,
        ),
        const SizedBox(width: 8),
        _buildActionPill(
          icon: Icons.cleaning_services,
          label: 'Log Chore',
          onTap: onLogChoreTap,
        ),
      ],
    );
  }

  Widget _buildActionPill({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accentLime, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: textLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoommateBalancesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Roommate Balances',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.balances.length,
            separatorBuilder: (_, __) =>
                const Divider(color: Colors.white10, height: 16),
            itemBuilder: (context, index) {
              final item = data.balances[index];
              return Row(
                children: [
                  CircleAvatar(
                    backgroundColor: item.isPositive
                        ? accentLime
                        : alertRed.withValues(alpha: 0.8),
                    radius: 16,
                    child: Text(
                      item.name.isNotEmpty ? item.name[0] : '?',
                      style: TextStyle(
                        color: item.isPositive
                            ? const Color(0xFF10131A)
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.isPositive
                              ? '${item.name} owes you'
                              : 'You owe ${item.name}',
                          style:
                              const TextStyle(color: textLight, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.formattedAmount,
                          style: TextStyle(
                            color: item.isPositive
                                ? accentLime
                                : const Color(0xFFFF5252),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item.isPositive)
                    OutlinedButton(
                      onPressed: () => onNudge?.call(item.name),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: accentLime),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text(
                        'Nudge',
                        style: TextStyle(
                            color: accentLime,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => onSettle?.call(item.name),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentLime,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text(
                        'Quick Settle',
                        style: TextStyle(
                            color: Color(0xFF10131A),
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysFocusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Focus",
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.focusTasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final task = data.focusTasks[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141720),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: task.isCompleted,
                      activeColor: accentLime,
                      checkColor: const Color(0xFF10131A),
                      onChanged: (_) => onToggleFocusTask?.call(index),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              color: task.isCompleted ? textMuted : textLight,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            task.dueInfo,
                            style: const TextStyle(
                              color: textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: alertRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Due soon',
                        style: TextStyle(
                          color: Color(0xFFFF5252),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
