import 'package:flutter/material.dart';

enum GoalStatus { inProgress, completed }

/// เอนทิตี้ Goal_Saving ตามพจนานุกรมข้อมูลในเอกสารบทที่ 3
class GoalModel {
  final String? currency;
  final String id; // goal_id
  final String name; // goal_name
  final double targetAmount; // target_amount
  double savedAmount; // saved_amount
  final DateTime startDate; // start_date
  final DateTime targetDate; // target_date
  GoalStatus status; // status
  final IconData icon;
  final String? note; // หมายเหตุ (optional)

  GoalModel({
    required this.id,
    this.currency,
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    required this.startDate,
    required this.targetDate,
    required this.icon,
    this.status = GoalStatus.inProgress,
    this.note,
  });

  double get progress =>
      targetAmount <= 0 ? 0 : (savedAmount / targetAmount).clamp(0, 1);

  /// ตามข้อ 1.3.2.2 แจ้งเตือนเมื่อใกล้ถึงเป้าหมาย (>= 90%)
  bool get isNearTarget => progress >= 0.9 && progress < 1.0;

  GoalModel copyWith({
    String? name,
    double? targetAmount,
    double? savedAmount,
    DateTime? startDate,
    DateTime? targetDate,
    GoalStatus? status,
    IconData? icon,
    String? note,
  }) {
    return GoalModel(
      id: id,
      currency: currency,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      startDate: startDate ?? this.startDate,
      targetDate: targetDate ?? this.targetDate,
      status: status ?? this.status,
      icon: icon ?? this.icon,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap(String userId) {
    return {
      'id': id,
      'currency': currency,
      'user_id': userId,
      'name': name,
      'target_amount': targetAmount,
      'saved_amount': savedAmount,
      'start_date': startDate.toIso8601String(),
      'target_date': targetDate.toIso8601String(),
      'status': status == GoalStatus.completed ? 'completed' : 'inProgress',
      'icon_code': icon.codePoint,
      'note': note,
    };
  }

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    return GoalModel(
      id: map['id'] as String,
      currency: map['currency'] as String?,
      name: map['name'] as String,
      targetAmount: (map['target_amount'] as num).toDouble(),
      savedAmount: (map['saved_amount'] as num).toDouble(),
      startDate: DateTime.parse(map['start_date'] as String),
      targetDate: DateTime.parse(map['target_date'] as String),
      status: map['status'] == 'completed' ? GoalStatus.completed : GoalStatus.inProgress,
      icon: IconData(map['icon_code'] as int, fontFamily: 'MaterialIcons'),
      note: map['note'] as String?,
    );
  }
}