import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../model/Expense.dart';
import '../../../services/FirestoreService.dart';
import '../../../utlity/AppColors.dart';
import '../../../widgets/ExportOptionsSheet.dart';
import 'AddExpenseScreen.dart';

class ExpenseListScreen extends StatefulWidget {
  final bool isEmbedded;
  const ExpenseListScreen({super.key, this.isEmbedded = false});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  /// null = "All" months selected
  DateTime? _selectedMonth;

  void _exportExpenses() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => const ExportOptionsSheet(
        exportType: ExportType.expenses,
        title: "Export Expense Report",
      ),
    );
  }

  /// Extract unique year-month keys from the expense list, newest first.
  List<DateTime> _extractMonths(List<Expense> expenses) {
    final Set<String> seen = {};
    final List<DateTime> months = [];
    for (var e in expenses) {
      final key = "${e.date.year}-${e.date.month.toString().padLeft(2, '0')}";
      if (seen.add(key)) {
        months.add(DateTime(e.date.year, e.date.month));
      }
    }
    months.sort((a, b) => b.compareTo(a)); // newest first
    return months;
  }

  @override
  Widget build(BuildContext context) {
    final content = StreamBuilder<List<Expense>>(
      stream: _firestoreService.getExpensesStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }

        final allExpenses = snapshot.data ?? [];
        if (allExpenses.isEmpty) return _buildEmptyState();

        // Months available from data
        final months = _extractMonths(allExpenses);

        // Filter by selected month (if any)
        final expenses = _selectedMonth == null
            ? allExpenses
            : allExpenses.where((e) =>
        e.date.year == _selectedMonth!.year &&
            e.date.month == _selectedMonth!.month).toList();

        // Today's total
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        double todayTotal = 0;
        double currentMonthTotal = 0;
        
        for (var e in allExpenses) {
          final eDate = DateTime(e.date.year, e.date.month, e.date.day);
          // Today
          if (eDate.isAtSameMomentAs(today)) {
            todayTotal += e.amount;
          }
          // Current Month
          if (e.date.year == now.year && e.date.month == now.month) {
            currentMonthTotal += e.amount;
          }
        }

        // Filtered total (for the summary bar right side)
        double filteredTotal = 0;
        for (var e in expenses) {
          filteredTotal += e.amount;
        }

        // Group by date
        final Map<String, List<Expense>> groupedExpenses = {};
        for (var expense in expenses) {
          final dateKey = DateFormat('yyyy-MM-dd').format(expense.date);
          groupedExpenses.putIfAbsent(dateKey, () => []).add(expense);
        }

        final sortedDates = groupedExpenses.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return Column(
          children: [
            _buildMonthChips(months),
            _buildSummaryBar(
              todayTotal: todayTotal,
              monthTotal: filteredTotal,
              currentMonthTotal: currentMonthTotal,
            ),
            Expanded(
              child: expenses.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                padding: const EdgeInsets.only(
                    top: 8, left: 16, right: 16, bottom: 80),
                itemCount: sortedDates.length,
                itemBuilder: (context, index) {
                  final dateKey = sortedDates[index];
                  final dateItems = groupedExpenses[dateKey]!;
                  return _buildDateGroup(dateKey, dateItems);
                },
              ),
            ),
          ],
        );
      },
    );

    if (widget.isEmbedded) {
      return Scaffold(
        body: content,
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AddExpenseScreen()));
          },
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Expenses",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download, color: Colors.white),
            onPressed: _exportExpenses,
            tooltip: "Export Expenses",
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddExpenseScreen()));
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: content,
    );
  }
  // ----------------------------------------------------------------
  // Month chips (derived from data)
  // ----------------------------------------------------------------
  Widget _buildMonthChips(List<DateTime> months) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _monthChip(label: "All", value: null),
          const SizedBox(width: 8),
          ...months.map((m) {
            final label = DateFormat('MMM yyyy').format(m);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _monthChip(label: label, value: m),
            );
          }),
        ],
      ),
    );
  }

  Widget _monthChip({required String label, required DateTime? value}) {
    final isSelected = (_selectedMonth == null && value == null) ||
        (_selectedMonth != null &&
            value != null &&
            _selectedMonth!.year == value.year &&
            _selectedMonth!.month == value.month);

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : AppColors.textColor,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.grey.shade200,
      showCheckmark: false,
      onSelected: (_) {
        setState(() => _selectedMonth = value);
        // Tap a month → open detail dialog
        if (value != null) _showMonthlySummary(value);
      },
    );
  }
  // ----------------------------------------------------------------
  // Summary bar (Today + Selected month)
  // ----------------------------------------------------------------
  Widget _buildSummaryBar({
    required double todayTotal,
    required double monthTotal,
    required double currentMonthTotal,
  }) {
    final monthLabel = _selectedMonth == null
        ? "All-time Total"
        : "${DateFormat('MMM yyyy').format(_selectedMonth!)} Total";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: AppColors.primary.withValues(alpha: 0.05),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Today's Total",
                        style:
                            TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text("₹${todayTotal.toStringAsFixed(0)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.error)),
                  ],
                ),
              ),
              Container(width: 1, height: 32, color: Colors.grey.shade300),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Current Month",
                        style:
                            TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text("₹${currentMonthTotal.toStringAsFixed(0)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
          if (_selectedMonth != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(monthLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                Text("₹${monthTotal.toStringAsFixed(0)}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.error)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // Monthly summary dialog
  // ----------------------------------------------------------------
  void _showMonthlySummary(DateTime month) {
    showDialog(
      context: context,
      builder: (ctx) => StreamBuilder<List<Expense>>(
        stream: _firestoreService.getExpensesStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data ?? [];
          final monthExpenses = all
              .where((e) =>
          e.date.year == month.year && e.date.month == month.month)
              .toList();

          double total = 0, cash = 0, online = 0;
          for (var e in monthExpenses) {
            total += e.amount;
            if (e.paymentType.toLowerCase() == 'cash') {
              cash += e.amount;
            } else {
              online += e.amount;
            }
          }

          // Daily breakdown
          final Map<int, double> dailyTotals = {};
          for (var e in monthExpenses) {
            dailyTotals[e.date.day] =
                (dailyTotals[e.date.day] ?? 0) + e.amount;
          }
          final sortedDays = dailyTotals.keys.toList()..sort();

          return Dialog(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: AppColors.cardColor,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 560, maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('MMMM yyyy').format(month),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(),

                    if (monthExpenses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text("No expenses for this month.",
                              style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    else ...[
                      // Total
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Total Spent",
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text("₹${total.toStringAsFixed(0)}",
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.error)),
                            const SizedBox(height: 4),
                            Text("${monthExpenses.length} transactions",
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Split badges
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryTile(
                                "Cash", "₹${cash.toStringAsFixed(0)}",
                                Colors.green),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildSummaryTile(
                                "Online", "₹${online.toStringAsFixed(0)}",
                                Colors.blue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Daily breakdown
                      const Text("Daily Breakdown",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textColor)),
                      const SizedBox(height: 8),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: sortedDays.length,
                          itemBuilder: (context, i) {
                            final day = sortedDays[i];
                            return Padding(
                              padding:
                              const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('dd MMM').format(DateTime(
                                        month.year, month.month, day)),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  Text(
                                    "₹${dailyTotals[day]!.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ============================================================
  // OPTIONS BOTTOM SHEET
  // ============================================================

  void _showExpenseOptions(Expense expense) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            Text(
              expense.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            _buildOptionTile(
              icon: Icons.edit_outlined,
              title: "Edit Expense",
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddExpenseScreen(expense: expense))
                );
              },
            ),
            _buildOptionTile(
              icon: Icons.delete_outline,
              title: "Delete Expense",
              color: AppColors.error,
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(expense);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textColor),
      ),
      onTap: onTap,
    );
  }

  // ----------------------------------------------------------------
  // Existing helpers
  // ----------------------------------------------------------------
  Widget _buildDateGroup(String dateKey, List<Expense> items) {
    DateTime date = DateTime.parse(dateKey);
    String formattedDate = DateFormat('dd MMM, yyyy').format(date);

    final now = DateTime.now();
    if (dateKey == DateFormat('yyyy-MM-dd').format(now)) {
      formattedDate = "Today, $formattedDate";
    }

    double cashTotal = 0;
    double onlineTotal = 0;
    for (var item in items) {
      if (item.paymentType.toLowerCase() == 'cash') {
        cashTotal += item.amount;
      } else {
        onlineTotal += item.amount;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(formattedDate,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                        fontSize: 12)),
              ),
              const SizedBox(width: 4),
              if (cashTotal > 0)
                _buildSmallTotalBadge(
                    "Cash: ₹${cashTotal.toStringAsFixed(0)}", Colors.green),
              const SizedBox(width: 4),
              if (onlineTotal > 0)
                _buildSmallTotalBadge(
                    "Online: ₹${onlineTotal.toStringAsFixed(0)}", Colors.blue),
            ],
          ),
        ),
        ...items.map((e) => _buildExpenseCard(e)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSmallTotalBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    final createdAt = expense.createdAt ?? DateTime.now();
    final time = DateFormat('hh:mm a').format(createdAt);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Text(expense.title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
            "To: ${expense.paidBy}\nBy ${expense.staffMember}\nat $time",
            style: TextStyle(fontSize: 12, color: AppColors.textColor)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("₹${expense.amount.toStringAsFixed(0)}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                        fontSize: 15)),
                Text(expense.paymentType,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textColor)),
              ],
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.more_vert, color: AppColors.textColor.withOpacity(0.6), size: 22),
              onPressed: () => _showExpenseOptions(expense),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Expense expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: AppColors.cardColor,
        title: const Text(
          "Delete Expense",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textColor,
          ),
        ),
        content: Text(
          "Are you sure you want to delete '${expense.title}'?",
          style:
          TextStyle(color: AppColors.textColor.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              "Cancel",
              style: TextStyle(color: AppColors.error),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestoreService.deleteExpense(
          expense.id!, expense.amount, expense.date);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text("No expenses recorded yet.",
              style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }
}
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import '../../../model/Expense.dart';
// import '../../../services/FirestoreService.dart';
// import '../../../utlity/AppColors.dart';
// import '../../../widgets/ExportOptionsSheet.dart';
// import 'AddExpenseScreen.dart';
//
// class ExpenseListScreen extends StatefulWidget {
//   final bool isEmbedded;
//   const ExpenseListScreen({super.key, this.isEmbedded = false});
//
//   @override
//   State<ExpenseListScreen> createState() => _ExpenseListScreenState();
// }
//
// class _ExpenseListScreenState extends State<ExpenseListScreen> {
//   final FirestoreService _firestoreService = FirestoreService();
//
//   void _exportExpenses() {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
//       builder: (ctx) => const ExportOptionsSheet(
//         exportType: ExportType.expenses,
//         title: "Export Expense Report",
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final content = StreamBuilder<List<Expense>>(
//         stream: _firestoreService.getExpensesStream(),
//         builder: (context, snapshot) {
//           if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
//           if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
//
//           final expenses = snapshot.data ?? [];
//           if (expenses.isEmpty) return _buildEmptyState();
//
//           // Calculate Today's Total
//           final now = DateTime.now();
//           final today = DateTime(now.year, now.month, now.day);
//           double todayTotal = 0;
//           for (var e in expenses) {
//             final eDate = DateTime(e.date.year, e.date.month, e.date.day);
//             if (eDate.isAtSameMomentAs(today)) {
//               todayTotal += e.amount;
//             }
//           }
//
//           // Group expenses by date
//           final Map<String, List<Expense>> groupedExpenses = {};
//           for (var expense in expenses) {
//             final dateKey = DateFormat('yyyy-MM-dd').format(expense.date);
//             if (!groupedExpenses.containsKey(dateKey)) {
//               groupedExpenses[dateKey] = [];
//             }
//             groupedExpenses[dateKey]!.add(expense);
//           }
//
//           final sortedDates = groupedExpenses.keys.toList()..sort((a, b) => b.compareTo(a));
//
//           return Column(
//             children: [
//               _buildTodaySummary(todayTotal),
//               Expanded(
//                 child: ListView.builder(
//                   padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80),
//                   itemCount: sortedDates.length,
//                   itemBuilder: (context, index) {
//                     final dateKey = sortedDates[index];
//                     final dateItems = groupedExpenses[dateKey]!;
//                     return _buildDateGroup(dateKey, dateItems);
//                   },
//                 ),
//               ),
//             ],
//           );
//         },
//       );
//
//     if (widget.isEmbedded) {
//       return Scaffold(
//         body: content,
//         floatingActionButton: FloatingActionButton(
//           onPressed: () {
//             Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpenseScreen()));
//           },
//           backgroundColor: AppColors.primary,
//           child: const Icon(Icons.add, color: Colors.white),
//         ),
//       );
//     }
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Expenses", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
//         backgroundColor: AppColors.primary,
//         iconTheme: const IconThemeData(color: Colors.white),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.file_download, color: Colors.white),
//             onPressed: _exportExpenses,
//             tooltip: "Export Expenses",
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {
//           Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpenseScreen()));
//         },
//         backgroundColor: AppColors.primary,
//         child: const Icon(Icons.add, color: Colors.white),
//       ),
//       body: content,
//     );
//   }
//
//   Widget _buildTodaySummary(double total) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(16),
//       color: AppColors.primary.withValues(alpha: 0.05),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           const Text("Today's Total Expense", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
//           Text("₹${total.toStringAsFixed(0)}",
//             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.error)),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDateGroup(String dateKey, List<Expense> items) {
//     DateTime date = DateTime.parse(dateKey);
//     String formattedDate = DateFormat('dd MMM, yyyy').format(date);
//
//     // Check if it's today
//     final now = DateTime.now();
//     if (dateKey == DateFormat('yyyy-MM-dd').format(now)) {
//       formattedDate = "Today, $formattedDate";
//     }
//
//     double cashTotal = 0;
//     double onlineTotal = 0;
//     for (var item in items) {
//       if (item.paymentType.toLowerCase() == 'cash') {
//         cashTotal += item.amount;
//       } else {
//         onlineTotal += item.amount;
//       }
//     }
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
//           child: Row(
//             children: [
//               Expanded(
//                 child: Text(formattedDate,
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         color: Colors.grey.shade700,
//                         fontSize: 12)),
//               ),
//               const SizedBox(width: 4),
//               if (cashTotal > 0)
//                 _buildSmallTotalBadge("Cash: ₹${cashTotal.toStringAsFixed(0)}", Colors.green),
//               const SizedBox(width: 4),
//               if (onlineTotal > 0)
//                 _buildSmallTotalBadge("Online: ₹${onlineTotal.toStringAsFixed(0)}", Colors.blue),
//             ],
//           ),
//         ),
//         ...items.map((e) => _buildExpenseCard(e)),
//         const SizedBox(height: 12),
//       ],
//     );
//   }
//
//   Widget _buildSmallTotalBadge(String text, Color color) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         color: color.withValues(alpha: 0.1),
//         borderRadius: BorderRadius.circular(6),
//         border: Border.all(color: color.withValues(alpha: 0.3)),
//       ),
//       child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
//     );
//   }
//
//   Widget _buildExpenseCard(Expense expense) {
//
//     final createdAt = expense.createdAt ?? DateTime.now();
//     final time = DateFormat('hh:mm a').format(createdAt);
//     return Card(
//       margin: const EdgeInsets.only(bottom: 8),
//       elevation: 0,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//         side: BorderSide(color: Colors.grey.shade200),
//       ),
//       child: ListTile(
//         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//         title: Text(expense.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
//         subtitle: Text("To: ${expense.paidBy}\nBy ${expense.staffMember}\nat $time",
//           style: TextStyle(fontSize: 12, color: AppColors.textColor)),
//         trailing: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               crossAxisAlignment: CrossAxisAlignment.end,
//               children: [
//                 Text("₹${expense.amount.toStringAsFixed(0)}",
//                   style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 15)),
//                 Text(expense.paymentType, style: TextStyle(fontSize: 11, color: AppColors.textColor)),
//               ],
//             ),
//             const SizedBox(width: 8),
//             Row(
//               children: [
//                 IconButton(
//                   icon: const Icon(Icons.edit, color: AppColors.primary, size: 20),
//                   onPressed: () {
//                     Navigator.push(
//                         context,
//                         MaterialPageRoute(builder: (_) => AddExpenseScreen(expense: expense))
//                     );
//                   },
//                   constraints: const BoxConstraints(),
//                   padding: EdgeInsets.zero,
//                 ),
//                 IconButton(
//                   icon: const Icon(Icons.delete_outline, color: AppColors.primary, size: 20),
//                   onPressed: () => _confirmDelete(expense),
//                   constraints: const BoxConstraints(),
//                   padding: EdgeInsets.zero,
//                 ),
//               ],
//             )
//
//           ],
//         ),
//       ),
//     );
//   }
//   Future<void> _confirmDelete(Expense expense) async {
//     final confirm = await showDialog<bool>(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(16),
//         ),
//         backgroundColor: AppColors.cardColor,
//         title: const Text(
//           "Delete Expense",
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//             color: AppColors.textColor,
//           ),
//         ),
//         content: Text(
//           "Are you sure you want to delete '${expense.title}'?",
//           style: TextStyle(color: AppColors.textColor.withValues(alpha: 0.7)),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx, false),
//             child: const Text(
//               "Cancel",
//               style: TextStyle(color: AppColors.error),
//             ),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.pop(ctx, true),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: AppColors.error,
//               foregroundColor: Colors.white,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(10),
//               ),
//             ),
//             child: const Text("Delete"),
//           ),
//         ],
//       ),
//     );
//
//     if (confirm == true) {
//       await _firestoreService.deleteExpense(expense.id!, expense.amount, expense.date);
//     }
//   }
//
//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
//           const SizedBox(height: 16),
//           const Text("No expenses recorded yet.", style: TextStyle(fontSize: 18, color: Colors.grey)),
//         ],
//       ),
//     );
//   }
// }
