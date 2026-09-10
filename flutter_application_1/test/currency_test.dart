import 'package:budgetmate/models/category_model.dart';
import 'package:budgetmate/models/user_model.dart';
import 'package:budgetmate/services/data_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'data_service_test.dart' show MemoryDB;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('new entries retain selected currency; old amounts never convert', () async {
    final db = MemoryDB();
    final service = DataService(database:db)..currentUser=UserModel(id:'u',name:'Test',email:'u@example.com',createdAt:DateTime(2026));
    await db.insert('users',service.currentUser!.toMap());
    final category=defaultCategories.firstWhere((c)=>c.type==CategoryType.income);
    await service.addTransaction(type:CategoryType.income,amount:100,category:category,date:DateTime(2026));
    await service.setCurrency('USD');
    expect(service.balance,0);
    await service.addTransaction(type:CategoryType.income,amount:5,category:category,date:DateTime(2026));
    expect(service.balance,5);
    expect(db.tables['transactions']!.values.last['currency'],'USD');
    expect(db.tables['transactions']!.values.first['amount'],100);
    await service.setCurrency('THB');
    expect(service.balance,100);
    await service.refreshData();
    expect(service.balance,100);
    expect(service.transactions.single.currency,'THB');
    service.dispose();
  });
}
