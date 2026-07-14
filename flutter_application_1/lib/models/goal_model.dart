import 'package:flutter/material.dart';

enum GoalStatus { inProgress, completed }

/// เอนทิตี้ Goal_Saving ตามพจนานุกรมข้อมูลในเอกสารบทที่ 3
class GoalModel {
  final String id; // goal_id
  final String name; // goal_name
  final double targetAmount; // target_amount
  double savedAmount; // saved_amount
  final DateTime startDate; // start_date
  final DateTime targetDate; // target_date
  GoalStatus status; // status
  final IconData icon;

  GoalModel({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    required this.startDate,
    required this.targetDate,
    required this.icon,
    this.status = GoalStatus.inProgress,
  });

  double get progress =>
      targetAmount <= 0 ? 0 : (savedAmount / targetAmount).clamp(0, 1);

  /// ตามข้อ 1.3.2.2 แจ้งเตือนเมื่อใกล้ถึงเป้าหมาย (>= 90%)
  bool get isNearTarget => progress >= 0.9 && progress < 1.0;
}
