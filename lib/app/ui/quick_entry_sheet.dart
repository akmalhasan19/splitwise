/// Quick-Entry Sheet — form cepat input pengeluaran (Minggu 3, Task 2).
///
/// Memiliki:
/// * auto-formatting currency pada input nominal (pemisah ribuan titik
///   realtime saat user mengetik);
/// * selector Pembayar (Paid By) — dropdown anggota grup;
/// * selector opsi split: EQUAL (sama rata) atau EXACT (custom nominal).
///
/// Memakai [GroupDetailStore]yang sudah disuntikkan oleh layar detail grup.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:debt_splitter/app/state/group_detail_store.dart';
import 'package:debt_splitter/core/models/expense_item.dart';
import 'package:debt_splitter/core/models/expense_with_items.dart';
import 'package:debt_splitter/core/models/user.dart';
import 'package:debt_splitter/core/money/money_amount.dart';
import 'package:debt_splitter/core/utils/money_formatter.dart';

enum _SplitMode { equal, exact, item }

class QuickEntrySheet extends StatefulWidget {
  const QuickEntrySheet({required this.store, super.key});

  /// Store detail grup yang dipakai untuk membaca daftar anggota & menyimpan
  /// pengeluaran baru. Disuntikkan eksplisit karena sheet di-push sebagai
  /// route overlay via `showModalBottomSheet` — route sibling yang **tidak
  /// mewarisi** `ChangeNotifierProvider<GroupDetailStore>` dari route detail
  /// grup. Tanpa injeksi ini, `context.watch<GroupDetailStore>()` di dalam
  /// overlay melempar `ProviderNotFoundException` dan sheet tampak kosong.
  /// Pola yang sama dipakai `CreateGroupDialog` (lihat catatannya).
  final GroupDetailStore store;

  @override
  State<QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends State<QuickEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _exactCtrl = <String, TextEditingController>{};

  _SplitMode _mode = _SplitMode.equal;
  String? _paidById;
  bool _saving = false;
  String? _error;

  /// Draft item mode "Struk" — diisi editor item via callback.
  List<ExpenseItemWithClaims> _itemDraft = const [];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    for (final c in _exactCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final members = store.members;
    _paidById ??= members.isNotEmpty ? members.first.id : null;

    // Pastikan controller per anggota ada untuk mode EXACT.
    for (final m in members) {
      _exactCtrl.putIfAbsent(m.id, TextEditingController.new);
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DragHandle(),
                const SizedBox(height: 8),
                Text(
                  'Catat Pengeluaran',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 12),
                SegmentedButton<_SplitMode>(
                  segments: const [
                    ButtonSegment(
                      value: _SplitMode.equal,
                      label: Text('Sama rata'),
                    ),
                    ButtonSegment(
                      value: _SplitMode.exact,
                      label: Text('Custom'),
                    ),
                    ButtonSegment(
                      value: _SplitMode.item,
                      label: Text('Struk'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() {
                    _mode = s.first;
                    _error = null;
                  }),
                ),
                if (_mode != _SplitMode.item) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nominal (Rp)',
                      hintText: '0',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _ThousandsFormatter(),
                    ],
                    validator: _validateAmount,
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _paidById,
                  decoration: const InputDecoration(
                    labelText: 'Dibayar oleh',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final m in members)
                      DropdownMenuItem(value: m.id, child: Text(m.name)),
                  ],
                  onChanged: members.isEmpty
                      ? null
                      : (v) => setState(() => _paidById = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (opsional)',
                    hintText: 'mis. Makan malam',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                if (_mode == _SplitMode.exact) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Bagian tanggungan custom',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  ExactSplitHint(
                    amount: _parseAmount(),
                    membersLength: members.length,
                  ),
                  const SizedBox(height: 4),
                  for (final m in members) ...[
                    ExactSplitRow(name: m.name, controller: _exactCtrl[m.id]!),
                    const SizedBox(height: 4),
                  ],
                  ExactSplitTotalRow(
                    amount: _parseAmount(),
                    exactValues: {
                      for (final id in [for (final m in members) m.id])
                        id:
                            tryParseRupiahField(_exactCtrl[id]?.text ?? '') ??
                            0,
                    },
                  ),
                ],
                if (_mode == _SplitMode.item) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Daftar item struk',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Catat menu dari struk, lalu centang siapa yang '
                    'memakannya. Bagian tiap orang dihitung otomatis.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  _ItemBillEditor(
                    members: members,
                    key: const ValueKey('item-bill-editor'),
                    onChanged: (items) => setState(() => _itemDraft = items),
                  ),
                ],
                const SizedBox(height: 12),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Simpan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  MoneyAmount? _parseAmount() => tryParseRupiahField(_amountCtrl.text);

  String? _validateAmount(String? v) {
    final parsed = tryParseRupiahField(v ?? '');
    if (parsed == null || parsed <= 0) return 'Nominal harus > 0';
    return null;
  }

  Future<void> _submit() async {
    final store = widget.store;
    if (store.members.isEmpty) {
      setState(() => _error = 'Grup belum memiliki anggota.');
      return;
    }
    if (_paidById == null) {
      setState(() => _error = 'Pilih pembayar.');
      return;
    }
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();

    // Mode "Struk": nominal & bagian dihitung otomatis dari item.
    if (_mode == _SplitMode.item) {
      final items = _itemDraft;
      if (items.isEmpty) {
        setState(() => _error = 'Tambahkan minimal satu item dari struk.');
        return;
      }
      for (var i = 0; i < items.length; i++) {
        final entry = items[i];
        final itemName = entry.item.name.trim();
        if (itemName.isEmpty) {
          setState(() => _error = 'Nama item ke-${i + 1} tidak boleh kosong.');
          return;
        }
        if (entry.item.unitPrice <= 0) {
          setState(() => _error = 'Harga item "$itemName" harus lebih dari 0.');
          return;
        }
        if (entry.item.quantity < 1) {
          setState(() => _error = 'Jumlah unit item "$itemName" minimal 1.');
          return;
        }
        if (entry.claimantIds.isEmpty) {
          setState(() {
            _error = 'Item "$itemName" belum ada yang memakannya. '
                'Centang minimal satu anggota.';
          });
          return;
        }
      }
      setState(() => _saving = true);
      try {
        await store.addItemSplitExpense(paidBy: _paidById!, items: items, note: note);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = _parseAmount()!;
    if (_mode == _SplitMode.equal) {
      setState(() => _saving = true);
    } else {
      // Validasi konservasi untuk custom.
      final sharesById = <String, MoneyAmount>{};
      var sum = 0;
      for (final entry in _exactCtrl.entries) {
        final v = tryParseRupiahField(entry.value.text) ?? 0;
        sharesById[entry.key] = v;
        sum += v;
      }
      if (sum != amount) {
        setState(() {
          _saving = false;
          _error = 'Total bagian ($sum) harus sama dengan nominal ($amount).';
        });
        return;
      }
      setState(() => _saving = true);
    }

    try {
      if (_mode == _SplitMode.equal) {
        await store.addEqualSplitExpense(
          paidBy: _paidById!,
          amount: amount,
          note: note,
        );
      } else {
        final sharesById = <String, MoneyAmount>{};
        for (final entry in _exactCtrl.entries) {
          sharesById[entry.key] = tryParseRupiahField(entry.value.text) ?? 0;
        }
        await store.addExactSplitExpense(
          paidBy: _paidById!,
          amount: amount,
          sharesById: sharesById,
          note: note,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade400,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Formatter yang menambahkan pemisah ribuan titik secara realtime
/// (auto-formatting currency) pada input nominal. Hanya memproses digit;
/// filtering dilakukan oleh [FilteringTextInputFormatter.digitsOnly].
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final grouped = _group(digits);
    return TextEditingValue(
      text: grouped,
      selection: TextSelection.collapsed(offset: grouped.length),
    );
  }

  String _group(String digits) {
    final buffer = StringBuffer();
    var count = 0;
    for (var i = digits.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join();
  }
}

class ExactSplitHint extends StatelessWidget {
  const ExactSplitHint({
    required this.amount,
    required this.membersLength,
    super.key,
  });

  final MoneyAmount? amount;
  final int membersLength;

  @override
  Widget build(BuildContext context) {
    if (amount == null || membersLength == 0) {
      return const SizedBox.shrink();
    }
    final base = amount! ~/ membersLength;
    final remainder = amount! % membersLength;
    final hint = remainder == 0
        ? 'Saran sama rata: ${formatRupiah(base)} / orang (habis)'
        : 'Saran sama rata: ${formatRupiah(base + 1)} (untuk $remainder orang) '
              '/ ${formatRupiah(base)} (sisanya)';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(hint, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class ExactSplitRow extends StatelessWidget {
  const ExactSplitRow({
    required this.name,
    required this.controller,
    super.key,
  });

  final String name;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(name)),
        SizedBox(
          width: 140,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              isDense: true,
              prefixText: 'Rp ',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
      ],
    );
  }
}

class ExactSplitTotalRow extends StatelessWidget {
  const ExactSplitTotalRow({
    required this.amount,
    required this.exactValues,
    super.key,
  });

  /// Nominal expense target; `null` bila input belum diisi.
  final MoneyAmount? amount;
  final Map<String, MoneyAmount> exactValues;

  @override
  Widget build(BuildContext context) {
    var sum = 0;
    for (final v in exactValues.values) {
      sum += v;
    }
    final target = amount ?? 0;
    final matches = target > 0 && sum == target;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        'Total bagian: ${formatRupiah(sum)} / ${formatRupiah(target)} '
        '${matches ? "✓" : "✗"}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: matches ? Colors.green.shade700 : Colors.red.shade700,
        ),
      ),
    );
  }
}

/// Draft satu baris item pada mode "Struk" (menyimpan controller teks).
class _DraftLine {
  _DraftLine() {
    qtyCtrl.text = '1';
  }

  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController();
  final Set<String> claimants = <String>{};

  int get lineTotal =>
      (tryParseRupiahField(priceCtrl.text) ?? 0) *
      (int.tryParse(qtyCtrl.text) ?? 1);

  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    qtyCtrl.dispose();
  }
}

/// Editor daftar item bilah "Struk".
///
/// Memancarkan [ExpenseItemWithClaims] (id item masih kosong — repository
/// mengisi UUID saat simpan) lewat [onChanged] setiap kali data berubah.
class _ItemBillEditor extends StatefulWidget {
  const _ItemBillEditor({required this.members, required this.onChanged, super.key});

  final List<User> members;
  final ValueChanged<List<ExpenseItemWithClaims>> onChanged;

  @override
  State<_ItemBillEditor> createState() => _ItemBillEditorState();
}

class _ItemBillEditorState extends State<_ItemBillEditor> {
  final List<_DraftLine> _lines = <_DraftLine>[];

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onChanged([
      for (var i = 0; i < _lines.length; i++)
        ExpenseItemWithClaims(
          item: ExpenseItem(
            id: '',
            name: _lines[i].nameCtrl.text.trim(),
            unitPrice: tryParseRupiahField(_lines[i].priceCtrl.text) ?? 0,
            quantity: int.tryParse(_lines[i].qtyCtrl.text) ?? 1,
            ordering: i,
          ),
          claimantIds: _lines[i].claimants.toList(),
        ),
    ]);
  }

  void _addLine() {
    setState(() => _lines.add(_DraftLine()));
    _emit();
  }

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index).dispose();
    });
    _emit();
  }

  void _onFieldChanged(int index) {
    setState(() {});
    _emit();
  }

  void _toggleClaimant(int index, String userId) {
    setState(() {
      final claimants = _lines[index].claimants;
      if (!claimants.remove(userId)) {
        claimants.add(userId);
      }
    });
    _emit();
  }

  void _toggleAllClaimants(int index) {
    setState(() {
      final claimants = _lines[index].claimants;
      if (claimants.length == widget.members.length) {
        claimants.clear();
      } else {
        claimants
          ..clear()
          ..addAll(widget.members.map((m) => m.id));
      }
    });
    _emit();
  }

  int _total() {
    var total = 0;
    for (final line in _lines) {
      total += line.lineTotal;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (_lines.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Belum ada item. Tambahkan menu dari struk.'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addLine,
            icon: const Icon(Icons.add),
            label: const Text('Tambah item'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _addLine,
            icon: const Icon(Icons.add),
            label: const Text('Tambah item'),
          ),
        ),
        for (var i = 0; i < _lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _DraftItemCard(
            index: i,
            line: _lines[i],
            members: widget.members,
            onFieldChanged: _onFieldChanged,
            onToggleClaimant: _toggleClaimant,
            onToggleAllClaimants: _toggleAllClaimants,
            onRemove: _removeLine,
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Total bilah: ${formatRupiah(_total())}',
          textAlign: TextAlign.end,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _total() > 0 ? null : Theme.of(context).colorScheme.error,
          ),
        ),
      ],
    );
  }
}

/// Kartu satu baris item: nama, harga/unit, qty, dan pemilih "dimakan oleh".
class _DraftItemCard extends StatelessWidget {
  const _DraftItemCard({
    required this.index,
    required this.line,
    required this.members,
    required this.onFieldChanged,
    required this.onToggleClaimant,
    required this.onToggleAllClaimants,
    required this.onRemove,
  });

  final int index;
  final _DraftLine line;
  final List<User> members;
  final ValueChanged<int> onFieldChanged;
  final void Function(int index, String userId) onToggleClaimant;
  final ValueChanged<int> onToggleAllClaimants;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final memberIds = line.claimants;
    final lineTotal = line.lineTotal;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: line.nameCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Nama item',
                      hintText: 'mis. Nasi Goreng',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => onFieldChanged(index),
                  ),
                ),
                IconButton(
                  tooltip: 'Hapus item',
                  onPressed: () => onRemove(index),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: line.priceCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Harga/unit (Rp)',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _ThousandsFormatter(),
                    ],
                    onChanged: (_) => onFieldChanged(index),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: TextFormField(
                    controller: line.qtyCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Qty',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (_) => onFieldChanged(index),
                  ),
                ),
              ],
            ),
            if (lineTotal > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Subtotal: ${formatRupiah(lineTotal)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dimakan oleh',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (members.length > 1)
                  InkWell(
                    onTap: () => onToggleAllClaimants(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        memberIds.length == members.length
                            ? 'Batal semua'
                            : 'Pilih semua',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (members.isEmpty)
              const Text('Grup belum memiliki anggota.')
            else
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final m in members)
                    FilterChip(
                      label: Text(m.name),
                      selected: memberIds.contains(m.id),
                      onSelected: (_) => onToggleClaimant(index, m.id),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Wrapper publik agar [TextInputFormatter] bisa diuji dari luar.
TextInputFormatter thousandsInputFormatter() => _ThousandsFormatter();

