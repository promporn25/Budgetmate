import 'package:budgetmate/models/category_model.dart';
import 'package:budgetmate/models/goal_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default categories retain their icons when loaded from storage', () {
    for (final category in defaultCategories) {
      expect(CategoryModel.fromMap(category.toMap()).icon, category.icon);
    }
  });

  test('saved goals retain their selected icon', () {
    const goalIcons = [
      Icons.restaurant,
      Icons.local_cafe,
      Icons.home,
      Icons.directions_car,
      Icons.receipt_long,
      Icons.shopping_bag,
      Icons.card_giftcard,
      Icons.flight,
      Icons.spa,
      Icons.music_note,
      Icons.sports_soccer,
      Icons.pets,
      Icons.school,
      Icons.savings,
    ];
    for (final icon in goalIcons) {
      final goal = GoalModel(
        id: 'goal',
        name: 'Trip',
        targetAmount: 100,
        savedAmount: 10,
        startDate: DateTime(2026, 1, 1),
        targetDate: DateTime(2026, 12, 1),
        icon: icon,
      );
      expect(GoalModel.fromMap(goal.toMap('user')).icon, icon);
    }
  });

  test('unrecognized stored icon uses a visible fallback', () {
    final map = defaultCategories.first.toMap()..['icon_code'] = -1;
    expect(CategoryModel.fromMap(map).icon, Icons.category_outlined);
  });
}
