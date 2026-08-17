/// Importer sinkronisasi offline — Phase 2, Minggu 4, Task 1 & 2.
///
/// Meng-*merge* [GroupSyncPayload] / [FullBackupPayload] ke database lokal
/// dengan strategi **dilindungi UUID** (idempoten & non-destruktif):
///
/// * `User`   — id sama: perbarui `name`/`avatarColor`; id baru: insert.
/// * `Group`  — id sama: perbarui metadata; id baru: insert.
/// * anggota  — id yang belum menjadi anggota ditambahkan (tidak pernah
///   menghapus keanggotaan yang sudah ada).
/// * `Expense`— id sama: perbarui baris & *ganti* share-nya agar konsisten
///   dengan payload; id baru: insert expense + share.
///
/// Tidak ada data yang dihapus selama import — aman untuk sinkronisasi
/// dua arah antarperangkat. Seluruh proses berjalan dalam satu transaksi
/// (atomik): gagal di tengah => tidak ada perubahan parsial.
library;

import 'package:debt_splitter/core/db/app_database.dart';
import 'package:debt_splitter/core/models/expense.dart';
import 'package:debt_splitter/core/models/expense_share.dart';
import 'package:debt_splitter/core/sync/full_backup_payload.dart';
import 'package:debt_splitter/core/sync/group_sync_payload.dart';
import 'package:debt_splitter/features/expenses/data/expense_dao.dart';
import 'package:debt_splitter/features/expenses/data/expense_share_dao.dart';
import 'package:debt_splitter/features/groups/data/group_dao.dart';
import 'package:debt_splitter/features/groups/data/group_member_dao.dart';
import 'package:debt_splitter/features/users/data/user_dao.dart';
import 'package:sqflite/sqflite.dart';

/// Ringkasan hasil import (jumlah perubahan per kategori).
class SyncImportResult {
  const SyncImportResult({
    this.usersAdded = 0,
    this.usersUpdated = 0,
    this.groupsAdded = 0,
    this.groupsUpdated = 0,
    this.membersAdded = 0,
    this.expensesAdded = 0,
    this.expensesUpdated = 0,
    this.sharesInserted = 0,
  });

  final int usersAdded;
  final int usersUpdated;
  final int groupsAdded;
  final int groupsUpdated;
  final int membersAdded;
  final int expensesAdded;
  final int expensesUpdated;
  final int sharesInserted;

  /// Jumlah total perubahan yang benar-benar ditulis ke DB (0 = tidak ada).
  int get totalChanges =>
      usersAdded +
      usersUpdated +
      groupsAdded +
      groupsUpdated +
      membersAdded +
      expensesAdded +
      expensesUpdated +
      sharesInserted;

  SyncImportResult operator +(SyncImportResult other) => SyncImportResult(
    usersAdded: usersAdded + other.usersAdded,
    usersUpdated: usersUpdated + other.usersUpdated,
    groupsAdded: groupsAdded + other.groupsAdded,
    groupsUpdated: groupsUpdated + other.groupsUpdated,
    membersAdded: membersAdded + other.membersAdded,
    expensesAdded: expensesAdded + other.expensesAdded,
    expensesUpdated: expensesUpdated + other.expensesUpdated,
    sharesInserted: sharesInserted + other.sharesInserted,
  );
}

class SyncImporter {
  SyncImporter(this._appDatabase);

  final AppDatabase _appDatabase;

  static const UserDao _userDao = UserDao();
  static const GroupDao _groupDao = GroupDao();
  static const GroupMemberDao _memberDao = GroupMemberDao();
  static const ExpenseDao _expenseDao = ExpenseDao();
  static const ExpenseShareDao _shareDao = ExpenseShareDao();

  /// Meng-merge satu [GroupSyncPayload] ke database lokal (satu transaksi).
  Future<SyncImportResult> importGroupPayload(
    GroupSyncPayload payload,
  ) async {
    _validatePayload(payload);
    return _appDatabase.db.transaction((txn) async {
      return _importGroup(txn, payload);
    });
  }

  /// Meng-merge seluruh grup pada [FullBackupPayload] (satu transaksi).
  Future<SyncImportResult> importFullBackup(
    FullBackupPayload backup,
  ) async {
    return _appDatabase.db.transaction((txn) async {
      var result = const SyncImportResult();
      for (final payload in backup.groups) {
        _validatePayload(payload);
        result = result + await _importGroup(txn, payload);
      }
      return result;
    });
  }

  Future<SyncImportResult> _importGroup(
    Transaction txn,
    GroupSyncPayload payload,
  ) async {
    // 1. User (upsert: insert bila baru, update bila berubah).
    var usersAdded = 0;
    var usersUpdated = 0;
    for (final user in payload.members) {
      final existing = await _userDao.getById(txn, user.id);
      if (existing == null) {
        await _userDao.insert(txn, user);
        usersAdded++;
      } else if (existing.name != user.name ||
          existing.avatarColor != user.avatarColor) {
        await _userDao.update(txn, user);
        usersUpdated++;
      }
    }

    // 2. Group (upsert metadata).
    var groupsAdded = 0;
    var groupsUpdated = 0;
    final existingGroup = await _groupDao.getById(txn, payload.group.id);
    if (existingGroup == null) {
      await _groupDao.insert(txn, payload.group);
      groupsAdded++;
    } else if (existingGroup.name != payload.group.name ||
        existingGroup.defaultCurrency != payload.group.defaultCurrency) {
      await _groupDao.update(
        txn,
        payload.group.copyWith(
          name: payload.group.name,
          defaultCurrency: payload.group.defaultCurrency,
        ),
      );
      groupsUpdated++;
    }

    // 3. Keanggotaan: tambahkan anggota yang belum terdaftar.
    var membersAdded = 0;
    final existingMemberIds = (await _memberDao.getMemberUserIds(
      txn,
      payload.group.id,
    )).toSet();
    for (final user in payload.members) {
      if (!existingMemberIds.contains(user.id)) {
        await _memberDao.addMember(
          txn,
          groupId: payload.group.id,
          userId: user.id,
        );
        membersAdded++;
      }
    }

    // 4. Expense + share: insert bila baru; update + ganti share bila data
    //    berbeda. Data identik dilewati (idempoten — tidak menulis ulang).
    var expensesAdded = 0;
    var expensesUpdated = 0;
    var sharesInserted = 0;
    for (final item in payload.expenses) {
      final expense = item.expense;
      final existing = await _expenseDao.getById(txn, expense.id);
      if (existing == null) {
        await _expenseDao.insert(txn, expense);
        for (final share in item.shares) {
          await _shareDao.insert(txn, share.withExpenseId(expense.id));
        }
        expensesAdded++;
        sharesInserted += item.shares.length;
      } else if (!_sameExpense(existing, expense) ||
          !await _sameShares(txn, expense.id, item.shares)) {
        await _expenseDao.update(txn, expense);
        await _shareDao.deleteByExpense(txn, expense.id);
        for (final share in item.shares) {
          await _shareDao.insert(txn, share.withExpenseId(expense.id));
        }
        expensesUpdated++;
        sharesInserted += item.shares.length;
      }
    }

    return SyncImportResult(
      usersAdded: usersAdded,
      usersUpdated: usersUpdated,
      groupsAdded: groupsAdded,
      groupsUpdated: groupsUpdated,
      membersAdded: membersAdded,
      expensesAdded: expensesAdded,
      expensesUpdated: expensesUpdated,
      sharesInserted: sharesInserted,
    );
  }

  /// `true` bila [a] dan [b] memuat data expense yang identik (kecuali id).
  static bool _sameExpense(Expense a, Expense b) =>
      a.paidBy == b.paidBy &&
      a.amount == b.amount &&
      a.splitType == b.splitType &&
      a.date == b.date &&
      a.note == b.note;

  /// `true` bila share di DB untuk [expenseId] identik (userId + nominal)
  /// dengan [shares] payload — id share tidak dibandingkan (boleh berbeda
  /// antar perangkat), urutan tidak penting.
  static Future<bool> _sameShares(
    DatabaseExecutor db,
    String expenseId,
    List<ExpenseShare> shares,
  ) async {
    final existing = await _shareDao.getByExpense(db, expenseId);
    if (existing.length != shares.length) {
      return false;
    }
    final existingKeys = existing
        .map((s) => '${s.userId}:${s.shareAmount}')
        .toList()
      ..sort();
    final payloadKeys = shares
        .map((s) => '${s.userId}:${s.shareAmount}')
        .toList()
      ..sort();
    for (var i = 0; i < existingKeys.length; i++) {
      if (existingKeys[i] != payloadKeys[i]) {
        return false;
      }
    }
    return true;
  }

  /// Validasi cepat payload yang dibentuk secara programatik (bukan dari
  /// `fromJson`): pembayar & penerima share harus anggota, konservasi uang.
  static void _validatePayload(GroupSyncPayload payload) {
    final memberIds = payload.members.map((u) => u.id).toSet();
    for (final item in payload.expenses) {
      final expense = item.expense;
      if (expense.groupId != payload.group.id) {
        throw ArgumentError(
          'Expense "${expense.id}" milik grup berbeda dari payload.',
        );
      }
      if (!memberIds.contains(expense.paidBy)) {
        throw ArgumentError(
          'Pembayar "${expense.paidBy}" bukan anggota grup payload.',
        );
      }
      var sum = 0;
      for (final share in item.shares) {
        if (!memberIds.contains(share.userId)) {
          throw ArgumentError(
            'Penerima share "${share.userId}" bukan anggota grup payload.',
          );
        }
        sum += share.shareAmount;
      }
      if (sum != expense.amount) {
        throw ArgumentError(
          'Konservasi uang gagal di expense "${expense.id}": '
          'total share ($sum) != amount (${expense.amount}).',
        );
      }
    }
  }
}
