import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';

Future<void> runDataAction(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

Future<void> refreshAppData(BuildContext context) =>
    runDataAction(context, context.read<DataService>().refreshData);
