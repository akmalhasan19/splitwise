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
import 'package:provider/provider.dart';

import 'package:debt_splitter/app/state/group_detail_store.dart';
import 'package:debt_splitter/core/money/money_amount.dart';
import 'package:debt_splitter/core/utils/money_formatter.dart';

enum _SplitMode { equal, exact }

class QuickEntrySheet extends StatefulWidget {
  const QuickEntrySheet({super.key});

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
    final store = context.watch<GroupDetailStore>();
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
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
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
    final store = context.read<GroupDetailStore>();
    if (store.members.isEmpty) {
      setState(() => _error = 'Grup belum memiliki anggota.');
      return;
    }
    if (_paidById == null) {
      setState(() => _error = 'Pilih pembayar.');
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
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
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
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
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

/// Wrapper publik agar [TextInputFormatter] bisa diuji dari luar.
TextInputFormatter thousandsInputFormatter() => _ThousandsFormatter();
