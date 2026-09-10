import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


const _dbTimeout = Duration(seconds: 10);

class DBHelper {
  DBHelper._internal();
  static final DBHelper instance = DBHelper._internal();

  // The existing database is named 'default', without parentheses.
  final FirebaseFirestore _fs = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'default',
  );

  CollectionReference<Map<String, dynamic>> _col(String table) {
    if (table == 'categories') {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('กรุณาเข้าสู่ระบบก่อน');
      return _fs.collection('users').doc(uid).collection('categories');
    }
    return _fs.collection(table);
  }

  /// Commit both records together and re-read the goal on concurrent updates.
  Future<Map<String, dynamic>> transferToGoal(
    String goalId, double amount, Map<String, dynamic> entry,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || entry['user_id'] != uid || !amount.isFinite || amount <= 0) {
      throw StateError('ข้อมูลการโอนไม่ถูกต้อง');
    }
    final goalRef = _col('goals').doc(goalId);
    return _fs.runTransaction((transaction) async {
      final snapshot = await transaction.get(goalRef);
      final data = snapshot.data();
      if (data == null || data['user_id'] != uid) {
        throw StateError('ไม่พบเป้าหมาย');
      }
      final saved = (data['saved_amount'] as num).toDouble() + amount;
      final target = (data['target_amount'] as num).toDouble();
      if (saved > target) throw StateError('จำนวนเงินเกินเป้าหมาย');
      final updated = {...data, 'saved_amount': saved,
        'status': saved >= target ? 'completed' : 'inProgress'};
      transaction.update(goalRef, updated);
      transaction.set(_col('transactions').doc(entry['id'] as String), entry);
      return updated;
    });
  }

 
  Never _handleError(Object e, StackTrace st, String fallbackMessage) {
  
    debugPrint('[DBHelper] RAW ERROR TYPE=${e.runtimeType} VALUE=$e');
    if (e is TimeoutException) {
      debugPrint('[DBHelper] TIMEOUT after ${_dbTimeout.inSeconds}s: $fallbackMessage');
      throw Exception('$fallbackMessage (หมดเวลา) - เช็คอินเทอร์เน็ต');
    }
    if (e is FirebaseException) {
      debugPrint('[DBHelper] FirebaseException code=${e.code} message=${e.message}');
      switch (e.code) {
        case 'permission-denied':
          throw Exception('$fallbackMessage (ไม่มีสิทธิ์เข้าถึงข้อมูล - ตรวจสอบ Firestore Security Rules)');
        case 'unavailable':
          throw Exception('$fallbackMessage (เชื่อมต่อ Firestore ไม่ได้ - เช็คอินเทอร์เน็ต/สถานะ Firebase)');
        case 'failed-precondition':
          // เกิดเมื่อ query ใช้ where + orderBy คนละ field กัน (เช่น where('user_id')
          // ร่วมกับ orderBy('date')) ซึ่ง Firestore บังคับให้ต้องสร้าง Composite Index
          // ก่อนใช้งานจริง ข้อความ e.message ของ Firebase จะมีลิงก์สำหรับกดสร้าง index
          // อัตโนมัติแนบมาด้วย ให้เปิดลิงก์นั้นในเบราว์เซอร์แล้วกด "Create Index" ได้เลย
          throw Exception(
              '$fallbackMessage (ต้องสร้าง Firestore Index ก่อนใช้งาน query นี้ - '
              'เปิดลิงก์ในข้อความต่อไปนี้เพื่อสร้าง index อัตโนมัติ: ${e.message})');
        default:
          throw Exception('$fallbackMessage (${e.code}: ${e.message})');
      }
    }
    debugPrint('[DBHelper] Unexpected error: $e\n$st');
    throw Exception('$fallbackMessage ($e)');
  }

  // ---------------- Generic CRUD helpers ----------------
  // ใช้ data['id'] เป็น document id เสมอ (โค้ดเดิมสร้าง id ด้วย uuid อยู่แล้ว)
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final id = data['id'] as String;
    try {
      await _col(table).doc(id).set(data);
      return 1;
    } catch (e, st) {
      _handleError(e, st, 'บันทึกไม่สำเร็จ');
    }
  }

  // เพิ่มหลายรายการในครั้งเดียวด้วย WriteBatch (1 round-trip แทนที่จะยิงทีละรายการ)
  // Firestore batch รองรับสูงสุด 500 operations ต่อ batch จึงแบ่งเป็นชุดๆ ถ้าเผื่อไว้
  Future<void> insertBatch(String table, List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    const chunkSize = 450;
    for (int i = 0; i < items.length; i += chunkSize) {
      final chunk = items.sublist(i, i + chunkSize > items.length ? items.length : i + chunkSize);
      final batch = _fs.batch();
      for (final data in chunk) {
        final id = data['id'] as String;
        batch.set(_col(table).doc(id), data);
      }
      try {
        await batch.commit();
      } catch (e, st) {
        _handleError(e, st, 'บันทึกไม่สำเร็จ');
      }
    }
  }

  // รองรับเฉพาะ where แบบ 'field = ?' กับ whereArgs 1 ค่า (ตรงกับที่ใช้ทั้งโปรเจกต์)
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  }) async {
    if (where?.trim() == 'id = ?' && whereArgs?.length == 1) {
      try {
        final snapshot = await _col(table).doc(whereArgs!.first.toString())
            .get().timeout(_dbTimeout);
        final data = snapshot.data();
        return data == null ? [] : [data];
      } catch (e, st) {
        _handleError(e, st, 'โหลดข้อมูลไม่สำเร็จ');
      }
    }
    Query<Map<String, dynamic>> q = _col(table);

    if (where != null && whereArgs != null && whereArgs.isNotEmpty) {
      final field = where.split('=').first.trim();
      q = q.where(field, isEqualTo: whereArgs.first);
    }

    if (orderBy != null && orderBy.trim().isNotEmpty) {
      final parts = orderBy.trim().split(RegExp(r'\s+'));
      final field = parts[0];
      final desc = parts.length > 1 && parts[1].toUpperCase() == 'DESC';
      q = q.orderBy(field, descending: desc);
    }

    try {
      final snap = await q.get().timeout(_dbTimeout);
      return snap.docs.map((d) => d.data()).toList();
    } catch (e, st) {
      _handleError(e, st, 'โหลดข้อมูลไม่สำเร็จ');
    }
  }

  // รองรับเฉพาะ where = 'id = ?' (ตรงกับที่ใช้ทั้งโปรเจกต์)
  Future<int> update(
    String table,
    Map<String, dynamic> data,
    String where,
    List<Object?> whereArgs,
  ) async {
    final id = whereArgs.first.toString();
    try {
      await _col(table).doc(id).update(data);
      return 1;
    } catch (e, st) {
      _handleError(e, st, 'บันทึกไม่สำเร็จ');
    }
  }

  Future<int> delete(String table, String where, List<Object?> whereArgs) async {
    final id = whereArgs.first.toString();
    try {
      await _col(table).doc(id).delete();
      return 1;
    } catch (e, st) {
      _handleError(e, st, 'ลบไม่สำเร็จ');
    }
  }

  Future<int> count(String table) async {
    try {
      final agg = await _col(table).count().get().timeout(_dbTimeout);
      return agg.count ?? 0;
    } catch (e, st) {
      _handleError(e, st, 'นับจำนวนรายการไม่สำเร็จ');
    }
  }
}