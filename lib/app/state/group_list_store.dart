/// State layar Dashboard (daftar grup) — Minggu 3.
///
/// [ChangeNotifier] sederhana yang membungkus [DebtSplitterService] dan
/// menyediakan data + status loading/error ke widget via `provider`.
/// Dipakai bersama `ChangeNotifierProvider<GroupListStore>` di `app.dart`.
library;

import 'package:flutter/foundation.dart';

import 'package:debt_splitter/app/services/debt_splitter_service.dart';
import 'package:debt_splitter/core/models/group.dart';

class GroupListStore extends ChangeNotifier {
  GroupListStore(this._service);

  final DebtSplitterService _service;

  List<GroupDashboardEntry> _entries = const [];
  bool _loading = false;
  String? _error;

  List<GroupDashboardEntry> get entries => _entries;
  bool get isLoading => _loading;
  String? get error => _error;

  /// Memuat ulang seluruh ringkasan grup dari DB lokal.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _entries = await _service.getAllDashboardEntries();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Group> createGroupWithMembers({
    required String name,
    required List<String> memberNames,
  }) async {
    final group = await _service.createGroupWithMembers(
      name: name,
      memberNames: memberNames,
    );
    await load();
    return group;
  }

  Future<void> deleteGroup(String id) async {
    await _service.deleteGroup(id);
    await load();
  }
}
