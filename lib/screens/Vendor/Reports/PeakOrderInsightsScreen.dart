import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/FirestoreService.dart';
import '../../../utlity/AppColors.dart';
import '../../../model/Order.dart';

class PeakOrderInsightsScreen extends StatefulWidget {
  const PeakOrderInsightsScreen({super.key});

  @override
  State<PeakOrderInsightsScreen> createState() => _PeakOrderInsightsScreenState();
}
class _PeakOrderInsightsScreenState extends State<PeakOrderInsightsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;

  // Analysis Data
  Map<int, int> _dayWiseOrders = {}; // 1 (Mon) to 7 (Sun)
  Map<int, double> _dayWiseRevenue = {};
  Map<int, int> _hourWiseOrders = {}; // 0 to 23
  Map<int, double> _hourWiseRevenue = {};
  int _uniqueBusinessDays = 1;

  @override
  void initState() {
    super.initState();
    _performAnalysis();
  }

  Future<void> _performAnalysis() async {
    setState(() => _isLoading = true);

    try {
      final String vendorId = _firestoreService.vendorId ?? '';
      final ordersSnapshot = await _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('orders')
          .get();

      final List<OrderModel> orders = ordersSnapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .toList();

      Map<int, int> dayCounts = {};
      Map<int, double> dayRevenue = {};
      Map<int, int> hourCounts = {};
      Map<int, double> hourRevenue = {};
      Set<String> businessDays = {};

      for (var order in orders) {
        final DateTime? date = order.createdAt;
        if (date == null) continue;

        // Day wise (1=Mon, 7=Sun)
        dayCounts[date.weekday] = (dayCounts[date.weekday] ?? 0) + 1;
        dayRevenue[date.weekday] = (dayRevenue[date.weekday] ?? 0) + order.totalAmount;

        // Hour wise
        hourCounts[date.hour] = (hourCounts[date.hour] ?? 0) + 1;
        hourRevenue[date.hour] = (hourRevenue[date.hour] ?? 0) + order.totalAmount;

        if (order.businessDate != null) {
          businessDays.add(order.businessDate!);
        }
      }

      _uniqueBusinessDays = businessDays.length > 0 ? businessDays.length : 1;

      if (mounted) {
        setState(() {
          _dayWiseOrders = dayCounts;
          _dayWiseRevenue = dayRevenue;
          _hourWiseOrders = hourCounts;
          _hourWiseRevenue = hourRevenue;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Analysis Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Peak Order Insights",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _performAnalysis,
              color: AppColors.primary,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle("Daily Average Performance"),
                    const SizedBox(height: 6),
                    _buildDayWiseChart(),
                    const SizedBox(height: 12),
                    _buildSectionTitle("Hourly Performance (Peak Slots)"),
                    const SizedBox(height: 6),
                    _buildHourlySlotsList(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textColor),
    );
  }

  Widget _buildDayWiseChart() {
    final days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    int maxOrders = 1;
    for (var val in _dayWiseOrders.values) {
      if (val > maxOrders) maxOrders = val;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          const Text("Average orders & revenue per day of week",
              style: TextStyle(color: AppColors.textColor, fontSize: 12)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (index) {
              final dayNum = index + 1;
              final orders = _dayWiseOrders[dayNum] ?? 0;
              final revenue = _dayWiseRevenue[dayNum] ?? 0.0;
              final barHeight = (orders / maxOrders) * 150;
              
              // Correct average based on occurrences of that weekday would be better,
              // but using total business days / 7 is a good approximation for history.
              final divisor = (_uniqueBusinessDays / 7).clamp(1, 1000).toDouble();
              final avgOrders = orders / divisor;
              final avgRevenue = revenue / divisor;

              return Column(
                children: [
                  Text("₹${avgRevenue.toStringAsFixed(0)}",
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700)),
                  Text(avgOrders.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    width: 28,
                    height: barHeight.clamp(5, 150),
                    decoration: BoxDecoration(
                      color: AppColors.primary
                          .withOpacity(index >= 4 ? 1.0 : 0.6), // Highlight weekends
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(days[index], style: const TextStyle(fontSize: 11)),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlySlotsList() {
    // Define slots: 6 PM (18) to 4 AM (4)
    final slots = [
      {"label": "06 - 07 PM", "hour": 18},
      {"label": "07 - 08 PM", "hour": 19},
      {"label": "08 - 09 PM", "hour": 20},
      {"label": "09 - 10 PM", "hour": 21},
      {"label": "10 - 11 PM", "hour": 22},
      {"label": "11 - 12 AM", "hour": 23},
      {"label": "12 - 01 AM", "hour": 0},
      {"label": "01 - 02 AM", "hour": 1},
      {"label": "02 - 03 AM", "hour": 2},
      {"label": "03 - 04 AM", "hour": 3},
    ];

    int maxInSlot = 1;
    for (var slot in slots) {
      int count = _hourWiseOrders[slot['hour']] ?? 0;
      if (count > maxInSlot) maxInSlot = count;
    }

    return Column(
      children: slots.map((slot) {
        final count = _hourWiseOrders[slot['hour']] ?? 0;
        final revenue = _hourWiseRevenue[slot['hour']] ?? 0.0;
        final percentage = count / maxInSlot;
        
        final avgOrders = count / _uniqueBusinessDays;
        final avgRevenue = revenue / _uniqueBusinessDays;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              SizedBox(
                  width: 80,
                  child: Text(slot['label'] as String,
                      style:
                          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Container(
                          height: 12,
                          decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        FractionallySizedBox(
                          widthFactor: percentage.clamp(0.05, 1.0),
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                AppColors.primary.withOpacity(0.7),
                                AppColors.primary
                              ]),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Avg Revenue: ₹${avgRevenue.toStringAsFixed(0)}",
                      style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 50,
                child: Text(
                  "${avgOrders.toStringAsFixed(1)} avg",
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
