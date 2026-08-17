/// Serialisasi data grup & transaksi ke format JSON ringkas — Phase 2, Minggu 4,
/// Task 1 (QR Code Offline Peer-to-Peer Sync).
///
/// Satu [GroupSyncPayload] memuat SATU grup lengkap: metadata grup, daftar
/// anggota, dan seluruh expense beserta share-nya. Payload ini di-encode ke
/// QR oleh [PayloadCodec] (`lib/core/sync/payload_codec.dart`).
///
/// **Format ringkas**: agar muat dalam kapasitas QR (~3KB), seluruh key JSON
/// memakai nama pendek (dokumentasi pemetaan di bawah). Selain itu payload
/// dikompresi `gzip` sebelum di-encode Base64 — lihat [PayloadCodec].
///
/// Pemetaan key (ringkas):
/// ```text
/// t  = type marker ("DS1")          x  = exportedAt (epoch detik)
/// v  = schemaVersion                g  = objek Group
/// m  = daftar User (anggota)        e  = daftar ExpenseWithShares
/// ```
/// Objek Group:  `id` | `n` (name) | `c` (defaultCurrency) | `ca` (createdAt)
/// Objek User:   `id` | `n` (name) | `a` (avatarColor) | `ca` (createdAt)
/// Objek Expense: `id` | `g` (groupId) | `p` (paidBy) | `am` (amount)
///                | `st` (splitType db value) | `d` (date) | `n` (note, opsional)
///                | `sh` (daftar ExpenseShare)
/// Objek Share:  `id` | `u` (userId) | `sa` (shareAmount)
///
/// Semua nominal uang bertipe `int` ([MoneyAmount]) — tanpa `double`/`float`.
library;

import 'package:debt_splitter/core/db/local_schema.dart';
import 'package:debt_splitter/core/models/expense.dart';
import 'package:debt_splitter/core/models/expense_item.dart';
import 'package:debt_splitter/core/models/expense_share.dart';
import 'package:debt_splitter/core/models/expense_with_items.dart';
import 'package:debt_splitter/core/models/expense_with_shares.dart';
import 'package:debt_splitter/core/models/group.dart';
import 'package:debt_splitter/core/models/user.dart';
import 'package:debt_splitter/core/money/money_amount.dart';

/// Payload sinkronisasi satu grup (export & import offline via QR/JSON).
class GroupSyncPayload {
  const GroupSyncPayload({
    required this.schemaVersion,
    required this.exportedAt,
    required this.group,
    required this.members,
    required this.expenses,
  });

  /// Marker tipe payload — membedakan dari payload lain di QR/JSON.
  static const String typeMarker = 'DS1';

  /// Versi format serialisasi saat ini. Penerima menolak payload dengan
  /// `schemaVersion` lebih baru dari versi ini (agar tidak salah tafsir).
  static const int currentSchemaVersion = 2;

  /// Versi format payload (untuk kompatibilitas ke depan).
  final int schemaVersion;

  /// Waktu payload dibuat (Unix epoch detik) — info saja, bukan idempotensi.
  final int exportedAt;

  /// Metadata grup yang disinkronkan.
  final Group group;

  /// Seluruh anggota grup (urutan apapun; dipakai resolusi id -> nama).
  final List<User> members;

  /// Seluruh transaksi grup berikut share-nya.
  final List<ExpenseWithShares> expenses;

  /// Menyusun payload menjadi [Map] JSON ringkas (siap `jsonEncode`).
  Map<String, Object?> toJson() => <String, Object?>{
    't': typeMarker,
    'v': schemaVersion,
    'x': exportedAt,
    'g': _groupToJson(group),
    'm': <Object?>[for (final member in members) _userToJson(member)],
    'e': <Object?>[for (final item in expenses) _expenseToJson(item)],
  };

  /// Membaca [GroupSyncPayload] dari [Map] JSON hasil decode.
  ///
  /// Melakukan validasi ketat (FormatException pada data korup):
  /// * marker `t` & `schemaVersion` harus didukung;
  /// * `groupId` & `paidBy` & penerima share harus anggota grup;
  /// * konservasi uang: `sum(shareAmount) == amount` per expense;
  /// * id unik (tidak ada duplikat user/expense/share).
  static GroupSyncPayload fromJson(Map<String, Object?> json) {
    _expectType(json);
    final schemaVersion = _readInt(json, 'v', min: 1);
    if (schemaVersion > currentSchemaVersion) {
      throw FormatException(
        'Payload versi $schemaVersion lebih baru dari yang didukung '
        '($currentSchemaVersion). Perbarui aplikasi Debt-Splitter.',
      );
    }

    final group = _groupFromJson(_readMap(json, 'g'));
    final members = <User>[];
    for (final raw in _readList(json, 'm')) {
      final user = _userFromJson(_asMap(raw, 'm'));
      if (members.any((u) => u.id == user.id)) {
        throw FormatException('Anggota duplikat di payload: "${user.id}".');
      }
      members.add(user);
    }
    if (members.isEmpty) {
      throw const FormatException('Payload tidak memiliki anggota grup.');
    }
    final memberIds = members.map((u) => u.id).toSet();

    final expenses = <ExpenseWithShares>[];
    for (final raw in _readList(json, 'e')) {
      expenses.add(_expenseFromJson(_asMap(raw, 'e'), group.id, memberIds));
    }

    return GroupSyncPayload(
      schemaVersion: schemaVersion,
      exportedAt: _readInt(json, 'x', min: 0),
      group: group,
      members: members,
      expenses: expenses,
    );
  }

  // ---------- Group ----------

  static Map<String, Object?> _groupToJson(Group group) => <String, Object?>{
    'id': group.id,
    'n': group.name,
    'c': group.defaultCurrency,
    'ca': group.createdAt,
  };

  static Group _groupFromJson(Map<String, Object?> map) => Group(
    id: _readString(map, 'id'),
    name: _readString(map, 'n'),
    defaultCurrency: _readString(map, 'c'),
    createdAt: _readInt(map, 'ca', min: 0),
  );

  // ---------- User ----------

  static Map<String, Object?> _userToJson(User user) => <String, Object?>{
    'id': user.id,
    'n': user.name,
    'a': user.avatarColor,
    'ca': user.createdAt,
  };

  static User _userFromJson(Map<String, Object?> map) => User(
    id: _readString(map, 'id'),
    name: _readString(map, 'n'),
    avatarColor: _readString(map, 'a'),
    createdAt: _readInt(map, 'ca', min: 0),
  );

  // ---------- Expense + Share ----------

  static Map<String, Object?> _expenseToJson(ExpenseWithShares item) {
    final expense = item.expense;
    final map = <String, Object?>{
      'id': expense.id,
      'g': expense.groupId,
      'p': expense.paidBy,
      'am': expense.amount,
      'st': expense.splitType.dbValue,
      'd': expense.date,
      'sh': <Object?>[
        for (final share in item.shares) _shareToJson(share),
      ],
    };
    if (expense.note != null && expense.note!.isNotEmpty) {
      map['n'] = expense.note;
    }
    if (item.items.isNotEmpty) {
      map['i'] = <Object?>[for (final entry in item.items) _itemToJson(entry)];
    }
    return map;
  }

  static Map<String, Object?> _itemToJson(ExpenseItemWithClaims entry) =>
      <String, Object?>{
        'id': entry.item.id,
        'n': entry.item.name,
        'p': entry.item.unitPrice,
        'q': entry.item.quantity,
        'o': entry.item.ordering,
        'c': <Object?>[for (final id in entry.claimantIds) id],
      };

  static Map<String, Object?> _shareToJson(ExpenseShare share) =>
      <String, Object?>{
        'id': share.id,
        'u': share.userId,
        'sa': share.shareAmount,
      };

  static ExpenseWithShares _expenseFromJson(
    Map<String, Object?> map,
    String groupId,
    Set<String> memberIds,
  ) {
    final id = _readString(map, 'id');
    if (map['g'] != groupId) {
      throw FormatException(
        'Expense "$id" milik grup berbeda dari payload '
        '(${map['g']} != $groupId).',
      );
    }
    final paidBy = _readString(map, 'p');
    if (!memberIds.contains(paidBy)) {
      throw FormatException(
        'Pembayar expense "$id" ($paidBy) bukan anggota grup.',
      );
    }
    final amount = _readInt(map, 'am', min: 1);
    final splitType = ExpenseSplitType.fromDbValue(_readString(map, 'st'));

    final shares = <ExpenseShare>[];
    for (final raw in _readList(map, 'sh')) {
      final share = _shareFromJson(_asMap(raw, 'sh'));
      if (shares.any((s) => s.id == share.id)) {
        throw FormatException('Share duplikat di expense "$id".');
      }
      if (!memberIds.contains(share.userId)) {
        throw FormatException(
          'Penerima share ${share.userId} di expense "$id" bukan anggota.',
        );
      }
      shares.add(share);
    }
    if (shares.isEmpty) {
      throw FormatException('Expense "$id" tidak memiliki share.');
    }
    var sum = 0;
    for (final share in shares) {
      sum += share.shareAmount;
    }
    if (sum != amount) {
      throw FormatException(
        'Konservasi uang gagal di expense "$id": total share ($sum) '
        '!= amount ($amount).',
      );
    }

    final note = map['n'];
    if (note != null && note is! String) {
      throw const FormatException('Field note harus bertipe string.');
    }

    // Skema V2: detail item/claim (opsional — payload versi lama tanpa item).
    final items = <ExpenseItemWithClaims>[];
    final rawItems = map['i'];
    if (rawItems != null) {
      if (rawItems is! List) {
        throw FormatException('Field "i" expense "$id" harus berupa daftar.');
      }
      final seenItemIds = <String>{};
      for (final raw in rawItems) {
        final entry = _itemFromJson(_asMap(raw, 'i'), memberIds);
        if (!seenItemIds.add(entry.item.id)) {
          throw FormatException('Item duplikat di expense "$id".');
        }
        items.add(entry);
      }
    }

    return ExpenseWithShares(
      expense: Expense(
        id: id,
        groupId: groupId,
        paidBy: paidBy,
        amount: amount,
        splitType: splitType,
        date: _readInt(map, 'd', min: 0),
        note: note as String?,
      ),
      shares: shares,
      items: items,
    );
  }

  static ExpenseItemWithClaims _itemFromJson(
    Map<String, Object?> map,
    Set<String> memberIds,
  ) {
    final id = _readString(map, 'id');
    final claimantIds = <String>[];
    for (final raw in _readList(map, 'c')) {
      if (raw is! String || raw.isEmpty) {
        throw FormatException('Claimant item "$id" harus string id user.');
      }
      if (!memberIds.contains(raw)) {
        throw FormatException(
          'Claimant "$raw" item "$id" bukan anggota grup.',
        );
      }
      claimantIds.add(raw);
    }
    if (claimantIds.isEmpty) {
      throw FormatException('Item "$id" tidak memiliki pengeklaim.');
    }
    return ExpenseItemWithClaims(
      item: ExpenseItem(
        id: id,
        name: _readString(map, 'n'),
        unitPrice: _readInt(map, 'p', min: 0),
        quantity: _readInt(map, 'q', min: 1),
        ordering: _readInt(map, 'o', min: 0),
        expenseId: '',
      ),
      claimantIds: claimantIds,
    );
  }

  static ExpenseShare _shareFromJson(Map<String, Object?> map) => ExpenseShare(
    id: _readString(map, 'id'),
    expenseId: '', // diisi konteks oleh pemanggil (_expenseFromJson)
    userId: _readString(map, 'u'),
    shareAmount: _readInt(map, 'sa', min: 0),
  );

  // ---------- Helper baca (validasi ketat) ----------

  static void _expectType(Map<String, Object?> json) {
    if (json['t'] != typeMarker) {
      throw const FormatException(
        'Bukan payload Debt-Splitter (marker "DS1" tidak ditemukan).',
      );
    }
  }

  static Map<String, Object?> _readMap(
    Map<String, Object?> json,
    String key,
  ) =>
      _asMap(json[key], key);

  static Map<String, Object?> _asMap(Object? raw, String key) {
    if (raw is Map) {
      return Map<String, Object?>.from(raw);
    }
    throw FormatException('Field "$key" harus berupa objek JSON.');
  }

  static List<Object?> _readList(Map<String, Object?> json, String key) {
    final raw = json[key];
    if (raw is List) {
      return raw;
    }
    throw FormatException('Field "$key" harus berupa daftar JSON.');
  }

  static String _readString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw FormatException('Field "$key" harus berupa string tidak kosong.');
  }

  static int _readInt(
    Map<String, Object?> json,
    String key, {
    int? min,
  }) {
    final value = json[key];
    if (value is int) {
      if (min != null && value < min) {
        throw FormatException('Field "$key" minimal $min (ditemukan $value).');
      }
      return value;
    }
    throw FormatException('Field "$key" harus berupa bilangan bulat.');
  }
}
