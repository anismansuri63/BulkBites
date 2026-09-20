import 'package:cloud_firestore/cloud_firestore.dart';
import '../utlity/DateUtils.dart';

class Expense {
  final String? id;
  final String title;
  final double amount;
  final String staffMember;
  final String paymentType; // Cash / UPI
  final String paidBy; // Organization / Individual
  final DateTime date;
  final String? category;
  final DateTime? createdAt;

  Expense({
    this.id,
    required this.title,
    required this.amount,
    required this.staffMember,
    required this.paymentType,
    required this.paidBy,
    required this.date,
    this.category,
    this.createdAt,
  });

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Expense(
      id: doc.id,
      title: data['title'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      staffMember: data['staffMember'] ?? '',
      paymentType: data['paymentType'] ?? 'Cash',
      paidBy: data['paidBy'] ?? 'Organization',
      date: BBDateUtils.parseDateTime(data['date']) ?? DateTime.now(),
      category: data['category'],
      createdAt: BBDateUtils.parseDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'staffMember': staffMember,
      'paymentType': paymentType,
      'paidBy': paidBy,
      'date': Timestamp.fromDate(date),
      'category': category,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
