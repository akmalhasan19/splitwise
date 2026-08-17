/// Dialog pembuatan grup baru — "instant start" tanpa login (Minggu 3).
///
/// Meminta nama grup + daftar nama anggota. Tiap nama unik menjadi `User`
/// baru (dibuatkan otomatis oleh service). Setelah berhasil, mengembalikan
/// objek [Group] ke pemanggil via `Navigator.pop`.
library;

import 'package:flutter/material.dart';

import 'package:debt_splitter/app/state/group_list_store.dart';
import 'package:debt_splitter/core/models/group.dart';

class CreateGroupDialog extends StatefulWidget {
  const CreateGroupDialog({required this.store, super.key});

  /// Store yang dipakai untuk membuat grup & memicu muat-ulang dashboard.
  /// Disuntikkan eksplisit (bukan via `context.read`) karena overlay route
  /// dialog tidak mewarisi `MultiProvider` di subtree `home`.
  final GroupListStore store;

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _membersCtrl = TextEditingController();

  bool _saving = false;
  String? _formError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _membersCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Grup Baru'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama grup',
                  hintText: 'mis. Trip Bromo',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama grup wajib diisi'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _membersCtrl,
                decoration: const InputDecoration(
                  labelText: 'Anggota',
                  hintText: 'Pisahkan nama dengan koma atau baris baru',
                  helperText: 'mis. Budi, Andi, Citra',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                textCapitalization: TextCapitalization.words,
                validator: _validateMembers,
              ),
              if (_formError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _formError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Buat'),
        ),
      ],
    );
  }

  String? _validateMembers(String? v) {
    final names = _parseNames(v ?? '');
    if (names.isEmpty) return 'Minimal satu anggota';
    if (names.length != names.map((n) => n.toLowerCase()).toSet().length) {
      return 'Ada nama anggota yang duplikat';
    }
    return null;
  }

  List<String> _parseNames(String raw) {
    return raw
        .split(RegExp(r'[\n,]+'))
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      final group = await widget.store.createGroupWithMembers(
        name: _nameCtrl.text,
        memberNames: _parseNames(_membersCtrl.text),
      );
      if (mounted) Navigator.pop(context, group);
    } catch (e) {
      setState(() {
        _saving = false;
        _formError = e.toString();
      });
    }
  }
}
