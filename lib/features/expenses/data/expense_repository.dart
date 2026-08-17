/// Repository operasi CRUD transaksi `Expense` + `ExpenseShare`.
///
/// Kontrak domain yang dijaga di sini (di luar constraint SQL):
/// * konservasi uang: `sum(share_amount) == amount` persis (penentang
///   [ArgumentError] di level business, bukan error DB);
/// * `amount` harus > 0;
/// * pembayar (`paid_by`) dan seluruh penerima share wajib anggota grup;
/// * pembuatan/update expense berjalan atomik (expense + shares dalam satu
///   transaction), tidak parsial.
library;

import 'package:debt_splitter/core/db/app_database.dart';
import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:debt_splitter/core/models/expense.dart';
import 'package:debt_splitter/core/models/expense_share.dart';
import 'package:debt_splitter/core/models/expense_with_shares.dart';
import 'package:debt_splitter/core/money/money_amount.dart';
import 'package:debt_splitter/core/money/split_calculator.dart';
import 'package:debt_splitter/features/groups/data/group_member_dao.dart';
import 'package:uuid/uuid.dart';

import 'expense_dao.dart';
import 'expense_share_dao.dart';

class ExpenseRepository {
  ExpenseRepository(this._appDatabase, {Uuid? uuid}) : _uuid = uuid ?? Uuid();

  final AppDatabase _appDatabase;
  final Uuid _uuid;

  static const ExpenseDao _expenseDao = ExpenseDao();
  static const ExpenseShareDao _shareDao = ExpenseShareDao();
  static const GroupMemberDao _memberDao = GroupMemberDao();

  /// Membuat expense baru beserta seluruh [shares] dalam satu transaksi.
  ///
  /// `shares` boleh belum diisi `expenseId` — repository mengisinya dengan
  /// id expense yang sebenarnya; `id` share yang dipakai harus unik.
  Future<Expense> createExpense({
    required String groupId,
    required String paidBy,
    required MoneyAmount amount,
    required ExpenseSplitType splitType,
    required int date,
    required List<ExpenseShare> shares,
    String? note,
    String? id,
  }) async {
    await _validateInputs(
      groupId: groupId,
      paidBy: paidBy,
      amount: amount,
      shares: shares,
    );

    final expense = Expense(
      id: id ?? _uuid.v4(),
      groupId: groupId,
      paidBy: paidBy,
      amount: amount,
      splitType: splitType,
      date: date,
      note: note,
    );
    final ownedShares = _ownShares(expense.id, shares);

    await _appDatabase.db.transaction((txn) async {
      await _expenseDao.insert(txn, expense);
      await _shareDao.insertAll(txn, ownedShares);
    });
    return expense;
  }

  /// Membuat expense secara transaksional dan langsung menghitung pembagian
  /// **equal split** ke seluruh anggota grup lewat
  /// [SplitCalculator.equalSplit] (sisa 1 Rupiah didistribusikan ke
  /// `remainder` anggota pertama).
  Future<Expense> createEqualSplitExpense({
    required String groupId,
    required String paidBy,
    required MoneyAmount amount,
    required int date,
    String? note,
  }) async {
    final memberIds = await _memberDao.getMemberUserIds(
      _appDatabase.db,
      groupId,
    );
    if (memberIds.isEmpty) {
      throw StateError('Grup "$groupId" tidak memiliki anggota.');
    }

    final amounts = SplitCalculator.equalSplit(amount, memberIds.length);
    final shares = <ExpenseShare>[
      for (var i = 0; i < memberIds.length; i++)
        ExpenseShare(
          id: _uuid.v4(),
          userId: memberIds[i],
          shareAmount: amounts[i],
        ),
    ];

    return createExpense(
      groupId: groupId,
      paidBy: paidBy,
      amount: amount,
      splitType: ExpenseSplitType.equal,
      date: date,
      note: note,
      shares: shares,
    );
  }

  /// Meng-update data expense beserta shares-nya secara atomik:
  /// update baris expense -> hapus shares lama -> insert shares baru.
  Future<Expense> updateExpenseWithShares(
    Expense expense,
    List<ExpenseShare> shares,
  ) async {
    if (await _expenseDao.getById(_appDatabase.db, expense.id) == null) {
      throw StateError('Expense "${expense.id}" tidak ditemukan.');
    }
    await _validateInputs(
      groupId: expense.groupId,
      paidBy: expense.paidBy,
      amount: expense.amount,
      shares: shares,
    );

    final ownedShares = _ownShares(expense.id, shares);
    await _appDatabase.db.transaction((txn) async {
      await _expenseDao.update(txn, expense);
      await _shareDao.deleteByExpense(txn, expense.id);
      await _shareDao.insertAll(txn, ownedShares);
    });
    return expense;
  }

  /// Menghapus expense; baris `expense_shares` ikut terhapus (ON DELETE
  /// CASCADE dari tabel `expenses`).
  Future<void> deleteExpense(String id) async {
    await _expenseDao.delete(_appDatabase.db, id);
  }

  Future<Expense?> getExpenseById(String id) =>
      _expenseDao.getById(_appDatabase.db, id);

  Future<List<Expense>> getExpensesByGroup(String groupId) =>
      _expenseDao.getByGroup(_appDatabase.db, groupId);

  Future<List<ExpenseShare>> getSharesByExpense(String expenseId) =>
      _shareDao.getByExpense(_appDatabase.db, expenseId);

  Future<List<ExpenseShare>> getSharesByGroup(String groupId) =>
      _shareDao.getByGroup(_appDatabase.db, groupId);

  Future<int> countExpenses({String? groupId}) =>
      _expenseDao.count(_appDatabase.db, groupId: groupId);

  /// Mengambil satu expense + seluruh share-nya; melempar [StateError] bila
  /// expense tidak ada.
  Future<ExpenseWithShares> getExpenseWithShares(String expenseId) async {
    final expense = await _expenseDao.getById(_appDatabase.db, expenseId);
    if (expense == null) {
      throw StateError('Expense "$expenseId" tidak ditemukan.');
    }
    final shares = await _shareDao.getByExpense(_appDatabase.db, expenseId);
    return ExpenseWithShares(expense: expense, shares: shares);
  }

  /// Seluruh expense milik grup berikut share-nya (urut tanggal, terbaru
  /// dahulu). Sumber data utama untuk kalkulasi net-balance (Minggu 2).
  Future<List<ExpenseWithShares>> getExpenseWithSharesByGroup(
    String groupId,
  ) async {
    final expenses = await _expenseDao.getByGroup(_appDatabase.db, groupId);
    final result = <ExpenseWithShares>[];
    for (final expense in expenses) {
      final shares = await _shareDao.getByExpense(_appDatabase.db, expense.id);
      result.add(ExpenseWithShares(expense: expense, shares: shares));
    }
    return result;
  }

  /// Validasi business layer sebelum menulis ke DB.
  Future<void> _validateInputs({
    required String groupId,
    required String paidBy,
    required MoneyAmount amount,
    required List<ExpenseShare> shares,
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Nominal expense harus > 0.');
    }
    if (shares.isEmpty) {
      throw ArgumentError.value(
        shares,
        'shares',
        'Expense harus memiliki minimal satu share.',
      );
    }

    final sumShares = SplitCalculator.sum(
      shares.map((share) => share.shareAmount),
    );
    if (sumShares != amount) {
      throw ArgumentError.value(
        sumShares,
        'shares',
        'Konservasi uang gagal: total share ($sumShares) != amount ($amount).',
      );
    }

    final memberIds = (await _memberDao.getMemberUserIds(
      _appDatabase.db,
      groupId,
    )).toSet();
    if (!memberIds.contains(paidBy)) {
      throw ArgumentError.value(
        paidBy,
        'paidBy',
        'Pembayar harus anggota grup.',
      );
    }
    for (final share in shares) {
      if (!memberIds.contains(share.userId)) {
        throw ArgumentError.value(
          share.userId,
          'shares',
          'Seluruh penerima share harus anggota grup.',
        );
      }
    }
  }

  /// Mengisi `expenseId` pada setiap share menjadi milik expense tsb, dan
  /// memastikan setiap share memiliki UUID v4 unik sebagai Primary Key.
  ///
  /// Share yang dipanggil dengan `id` kosong (mis. path EXACT dari UI) akan
  /// diberi UUID baru — menjamin `expense_shares.id` selalu UUID (kontrak
  /// skema & aman untuk serialisasi payload sync).
  List<ExpenseShare> _ownShares(String expenseId, List<ExpenseShare> shares) =>
      shares.map((share) {
        final owned = share.id.isEmpty ? _uuid.v4() : share.id;
        return ExpenseShare(
          id: owned,
          expenseId: expenseId,
          userId: share.userId,
          shareAmount: share.shareAmount,
        );
      }).toList();
}
