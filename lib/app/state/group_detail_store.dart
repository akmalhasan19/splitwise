/// State layar Detail Grup + Settle Up — Minggu 3.
///
/// Menyatukan snapshot sebuah grup: metadata, anggota, riwayat expense, saldo
/// per anggota, dan rekomendasi pelunasan. Satu store per `groupId`, disuntik
/// via `ChangeNotifierProvider<GroupDetailStore>` saat masuk layar detail.
library;

import 'package:flutter/foundation.dart';

import 'package:debt_splitter/app/services/debt_splitter_service.dart';
import 'package:debt_splitter/core/models/expense.dart';
import 'package:debt_splitter/core/models/expense_with_shares.dart';
import 'package:debt_splitter/core/models/group.dart';
import 'package:debt_splitter/core/models/user.dart';
import 'package:debt_splitter/core/money/money_amount.dart';
import 'package:debt_splitter/features/settle_up/debt_simplifier_engine.dart';

/// Satu baris riwayat expense yang sudah diperkaya nama pembayar.
class ExpenseHistoryItem {
  const ExpenseHistoryItem({
    required this.expense,
    required this.paidByName,
    required this.shareCount,
  });

  final Expense expense;
  final String paidByName;
  final int shareCount;
}

class GroupDetailStore extends ChangeNotifier {
  GroupDetailStore(this._service, this.groupId);

  final DebtSplitterService _service;
  final String groupId;

  Group? _group;
  List<User> _members = const [];
  List<ExpenseHistoryItem> _history = const [];
  Map<String, MoneyAmount> _netBalances = const {};
  List<SettlementPayment> _settlements = const [];
  bool _loading = false;
  String? _error;

  Group? get group => _group;
  List<User> get members => _members;
  List<ExpenseHistoryItem> get history => _history;
  Map<String, MoneyAmount> get netBalances => _netBalances;
  List<SettlementPayment> get settlements => _settlements;
  bool get isLoading => _loading;
  String? get error => _error;

  /// Peta id -> nama anggota (resolusi cepat untuk UI).
  Map<String, String> get memberNameById => {
    for (final m in _members) m.id: m.name,
  };

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final snapshot = await _service.getSummarySnapshot(groupId);
      final expenses = await _service.getExpensesByGroup(groupId);
      _group = snapshot.group;
      _members = snapshot.members;
      _netBalances = snapshot.netBalances;
      _settlements = snapshot.settlements;
      _history = _buildHistory(expenses, snapshot.members);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  List<ExpenseHistoryItem> _buildHistory(
    List<ExpenseWithShares> expenses,
    List<User> members,
  ) {
    final nameById = {for (final m in members) m.id: m.name};
    final sorted = [...expenses]
      ..sort((a, b) {
        // Tanggal terbaru dahulu; tie-break id stabil.
        final byDate = b.expense.date.compareTo(a.expense.date);
        if (byDate != 0) return byDate;
        return a.expense.id.compareTo(b.expense.id);
      });
    return [
      for (final e in sorted)
        ExpenseHistoryItem(
          expense: e.expense,
          paidByName: nameById[e.expense.paidBy] ?? '—',
          shareCount: e.shares.length,
        ),
    ];
  }

  Future<void> addEqualSplitExpense({
    required String paidBy,
    required MoneyAmount amount,
    String? note,
  }) async {
    await _service.addEqualSplitExpense(
      groupId: groupId,
      paidBy: paidBy,
      amount: amount,
      note: note,
    );
    await load();
  }

  Future<void> addExactSplitExpense({
    required String paidBy,
    required MoneyAmount amount,
    required Map<String, MoneyAmount> sharesById,
    String? note,
  }) async {
    await _service.addExactSplitExpense(
      groupId: groupId,
      paidBy: paidBy,
      amount: amount,
      sharesById: sharesById,
      note: note,
    );
    await load();
  }

  Future<void> deleteExpense(String id) async {
    await _service.deleteExpense(id);
    await load();
  }

  Future<void> addMember(String name) async {
    await _service.addMemberByName(groupId, name);
    await load();
  }
}
