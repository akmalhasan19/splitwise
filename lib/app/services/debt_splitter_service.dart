/// Service facade yang menyatukan akses ke semua repository (Minggu 3).
///
/// UI hanya berbicara ke [DebtSplitterService] — bukan ke tiap repository
/// langsung — sesuai `docs/architecture.md` §6 (data flow:
/// `UI -> Service/UseCase -> Repository -> AppDatabase`). Service menyuntikkan
/// UUID/timestamp & merangkai operasi multi-repo (mis. membuat grup + anggota +
/// user baru dalam satu pemanggilan), sekaligus menjadi sumber data untuk
/// widget ChangeNotifier.
///
/// Tetap 100% lokal & offline: tidak ada I/O jaringan; seluruh akses via
/// [AppDatabase] / repository yang sudah ada.
library;

import 'package:debt_splitter/core/db/app_database.dart';
import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:debt_splitter/core/models/expense.dart';
import 'package:debt_splitter/core/models/expense_share.dart';
import 'package:debt_splitter/core/models/expense_with_shares.dart';
import 'package:debt_splitter/core/models/group.dart';
import 'package:debt_splitter/core/models/user.dart';
import 'package:debt_splitter/core/money/money_amount.dart';
import 'package:debt_splitter/features/expenses/data/expense_repository.dart';
import 'package:debt_splitter/features/groups/data/group_repository.dart';
import 'package:debt_splitter/features/settle_up/debt_simplifier_engine.dart';
import 'package:debt_splitter/features/settle_up/net_balance_calculator.dart';
import 'package:debt_splitter/features/share/whatsapp_summary_generator.dart';
import 'package:debt_splitter/features/users/data/user_repository.dart';

/// Ringkasan grup untuk Dashboard (Daftar Grup & total saldo per grup).
class GroupDashboardEntry {
  const GroupDashboardEntry({
    required this.group,
    required this.memberCount,
    required this.totalExpenseAmount,
    required this.netBalances,
  });

  final Group group;
  final int memberCount;

  /// Total nominal seluruh expense dalam grup.
  final MoneyAmount totalExpenseAmount;

  /// `userId -> net balance` di grup (untuk ringkasan saldo dashboard).
  final Map<String, MoneyAmount> netBalances;
}

class DebtSplitterService {
  DebtSplitterService(AppDatabase db)
    : _groupRepo = GroupRepository(db),
      _userRepo = UserRepository(db),
      _expenseRepo = ExpenseRepository(db);

  final GroupRepository _groupRepo;
  final UserRepository _userRepo;
  final ExpenseRepository _expenseRepo;

  // ----------- Groups -----------

  Future<List<Group>> getAllGroups() => _groupRepo.getAllGroups();

  Future<Group?> getGroupById(String id) => _groupRepo.getGroupById(id);

  /// Membuat grup baru berikut daftar nama anggota (akan dibuatkan sebagai
  /// `User` baru otomatis bila belum ada — untuk UX "instant start" tanpa
  /// perlu membuat user terpisah). Setiap nama unik dalam satu pemanggilan.
  Future<Group> createGroupWithMembers({
    required String name,
    required List<String> memberNames,
  }) async {
    if (memberNames.isEmpty) {
      throw ArgumentError('Grup harus memiliki minimal satu anggota.');
    }
    // Buat/buat ulang user per nama, lalu hubungkan ke grup baru.
    final userIds = <String>[];
    final seenNames = <String>{};
    for (final rawName in memberNames) {
      final clean = rawName.trim();
      if (clean.isEmpty) {
        throw ArgumentError('Nama anggota tidak boleh kosong.');
      }
      if (!seenNames.add(clean.toLowerCase())) {
        throw ArgumentError('Anggota duplikat: "$clean".');
      }
      final user = await _userRepo.createUser(name: clean);
      userIds.add(user.id);
    }
    return _groupRepo.createGroup(name: name, memberUserIds: userIds);
  }

  Future<List<User>> getGroupMembers(String groupId) =>
      _groupRepo.getGroupMembers(groupId);

  Future<void> deleteGroup(String id) => _groupRepo.deleteGroup(id);

  /// Memuat satu ringkasan-dashboard untuk satu grup (total expense + saldo).
  Future<GroupDashboardEntry> getGroupDashboardEntry(String groupId) async {
    final group = await _groupRepo.getGroupById(groupId);
    if (group == null) {
      throw StateError('Grup "$groupId" tidak ditemukan.');
    }
    final members = await _groupRepo.getGroupMembers(groupId);
    final expenses = await _expenseRepo.getExpenseWithSharesByGroup(groupId);
    final balances = NetBalanceCalculator.calculateBalances(expenses);
    var total = 0;
    for (final item in expenses) {
      total += item.expense.amount;
    }
    return GroupDashboardEntry(
      group: group,
      memberCount: members.length,
      totalExpenseAmount: total,
      netBalances: balances,
    );
  }

  /// Ringkasan seluruh grup untuk layar Dashboard (urut nama grup).
  Future<List<GroupDashboardEntry>> getAllDashboardEntries() async {
    final groups = await _groupRepo.getAllGroups();
    final entries = <GroupDashboardEntry>[];
    for (final group in groups) {
      entries.add(await getGroupDashboardEntry(group.id));
    }
    entries.sort(
      (a, b) =>
          a.group.name.toLowerCase().compareTo(b.group.name.toLowerCase()),
    );
    return entries;
  }

  // ----------- Members / Users -----------

  Future<List<User>> getAllUsers() => _userRepo.getAllUsers();

  /// Menambahkan anggota baru ke grup yang sudah ada (buat user bila perlu).
  Future<User> addMemberByName(String groupId, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) {
      throw ArgumentError('Nama anggota tidak boleh kosong.');
    }
    final user = await _userRepo.createUser(name: clean);
    await _groupRepo.addMember(groupId, user.id);
    return user;
  }

  // ----------- Expenses -----------

  Future<List<ExpenseWithShares>> getExpensesByGroup(String groupId) =>
      _expenseRepo.getExpenseWithSharesByGroup(groupId);

  /// Membuat expense dengan equal-split ke seluruh anggota grup. Kembali ke
  /// `ExpenseRepository.createEqualSplitExpense` (sisa 1 Rupiah didistribusi).
  Future<Expense> addEqualSplitExpense({
    required String groupId,
    required String paidBy,
    required MoneyAmount amount,
    String? note,
    int? date,
  }) {
    return _expenseRepo.createEqualSplitExpense(
      groupId: groupId,
      paidBy: paidBy,
      amount: amount,
      date: date ?? _nowSeconds(),
      note: note,
    );
  }

  /// Membuat expense dengan pembagian custom (EXACT). [sharesById] =
  /// `userId -> shareAmount`; konservasi `sum == amount` divalidasi repo.
  Future<Expense> addExactSplitExpense({
    required String groupId,
    required String paidBy,
    required MoneyAmount amount,
    required Map<String, MoneyAmount> sharesById,
    String? note,
    int? date,
  }) async {
    final shares = <ExpenseShare>[
      for (final entry in sharesById.entries)
        ExpenseShare(
          id: '', // id diisi oleh repository (UUID v4) lewat _ownShares.
          userId: entry.key,
          shareAmount: entry.value,
        ),
    ];
    return _expenseRepo.createExpense(
      groupId: groupId,
      paidBy: paidBy,
      amount: amount,
      splitType: ExpenseSplitType.exact,
      date: date ?? _nowSeconds(),
      note: note,
      shares: shares,
    );
  }

  Future<void> deleteExpense(String id) => _expenseRepo.deleteExpense(id);

  // ----------- Settle Up & Share -----------

  /// Menghitung rekomendasi pelunasan (output greedy engine) untuk satu grup.
  Future<List<SettlementPayment>> getSettlements(String groupId) async {
    final expenses = await _expenseRepo.getExpenseWithSharesByGroup(groupId);
    final balances = NetBalanceCalculator.calculateBalances(expenses);
    return DebtSimplifierEngine.settle(balances);
  }

  /// Memuat snapshot lengkap (grup+anggota+saldo+settlements+total) untuk
  /// generator ringkasan WhatsApp.
  Future<GroupSummarySnapshot> getSummarySnapshot(String groupId) async {
    final group = await _groupRepo.getGroupById(groupId);
    if (group == null) {
      throw StateError('Grup "$groupId" tidak ditemukan.');
    }
    final members = await _groupRepo.getGroupMembers(groupId);
    final expenses = await _expenseRepo.getExpenseWithSharesByGroup(groupId);
    final balances = NetBalanceCalculator.calculateBalances(expenses);
    var total = 0;
    for (final item in expenses) {
      total += item.expense.amount;
    }
    return GroupSummarySnapshot(
      group: group,
      members: members,
      netBalances: balances,
      settlements: DebtSimplifierEngine.settle(balances),
      totalExpenseAmount: total,
    );
  }

  static int _nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
