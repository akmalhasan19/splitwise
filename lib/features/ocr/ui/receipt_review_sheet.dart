/// Layar review/edit hasil scan struk — Phase 5, Fitur A, Task A4.
///
/// Menampilkan daftar item hasil OCR dengan kemampuan:
/// - Edit nama, harga, qty per item
/// - Hapus item salah
/// - Warning bila total item tidak cocok dengan total struk
/// - Tombol "Pakai hasil ini" → merge ke editor Struk (draft)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:debt_splitter/core/money/money_amount.dart';
import 'package:debt_splitter/core/utils/money_formatter.dart';
import 'package:debt_splitter/features/ocr/receipt_candidate_item.dart';
import 'package:debt_splitter/features/ocr/receipt_parse_result.dart';

class ReceiptReviewSheet extends StatefulWidget {
  const ReceiptReviewSheet({required this.result, super.key});

  final ReceiptParseResult result;

  @override
  State<ReceiptReviewSheet> createState() => _ReceiptReviewSheetState();
}

class _ReceiptReviewSheetState extends State<ReceiptReviewSheet> {
  late List<_EditableItem> _items;
  MoneyAmount? _totalFromReceipt;

  @override
  void initState() {
    super.initState();
    _items = widget.result.items
        .map((item) => _EditableItem(
              name: item.name,
              price: item.unitPrice > 0 ? '${item.unitPrice}' : '',
              qty: '${item.quantity}',
              priceGuessed: item.priceGuessed,
            ))
        .toList();
    _totalFromReceipt = widget.result.totalFromReceipt;
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.nameCtrl.dispose();
      item.priceCtrl.dispose();
      item.qtyCtrl.dispose();
    }
    super.dispose();
  }

  MoneyAmount get _itemsTotal {
    var total = 0;
    for (final item in _items) {
      total += item.lineTotal;
    }
    return total;
  }

  bool get _hasTotalMismatch =>
      _totalFromReceipt != null &&
      _totalFromReceipt! > 0 &&
      _itemsTotal != _totalFromReceipt;

  List<ReceiptCandidateItem> get _resultItems => [
        for (final item in _items)
          ReceiptCandidateItem(
            name: item.nameCtrl.text.trim(),
            unitPrice: tryParseRupiahField(item.priceCtrl.text) ?? 0,
            quantity: int.tryParse(item.qtyCtrl.text) ?? 1,
            priceGuessed: item.priceGuessed,
          ),
      ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Text(
                'Hasil Scan Struk',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Periksa dan edit item yang diperlukan.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              // Warning total
              if (_hasTotalMismatch)
                _TotalWarning(
                  itemsTotal: _itemsTotal,
                  receiptTotal: _totalFromReceipt!,
                ),
              // Info item yang perlu diedit
              if (_items.any((i) => i.priceGuessed))
                const _GuessedItemBanner(),
              const SizedBox(height: 8),
              // Daftar item
              Expanded(
                child: _items.isEmpty
                    ? const Center(
                        child: Text('Tidak ada item terdeteksi dari struk.'),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return _EditableItemCard(
                            index: index,
                            item: _items[index],
                            onChanged: () => setState(() {}),
                            onRemove: () {
                              setState(() => _items.removeAt(index));
                            },
                          );
                        },
                      ),
              ),
              // Total
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total item: ${formatRupiah(_itemsTotal)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (_totalFromReceipt != null)
                      Text(
                        'Total struk: ${formatRupiah(_totalFromReceipt!)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _hasTotalMismatch
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                  ],
                ),
              ),
              // Tombol aksi
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close),
                        label: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _items.isEmpty
                            ? null
                            : () => Navigator.pop(context, _resultItems),
                        icon: const Icon(Icons.check),
                        label: Text(
                          'Pakai hasil ini (${_items.length} item)',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Data editable untuk satu item.
class _EditableItem {
  _EditableItem({
    required String name,
    required String price,
    required String qty,
    this.priceGuessed = false,
  })  : nameCtrl = TextEditingController(text: name),
        priceCtrl = TextEditingController(text: price),
        qtyCtrl = TextEditingController(text: qty);

  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController qtyCtrl;
  final bool priceGuessed;

  int get lineTotal =>
      (tryParseRupiahField(priceCtrl.text) ?? 0) *
      (int.tryParse(qtyCtrl.text) ?? 1);

  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    qtyCtrl.dispose();
  }
}

/// Kartu satu baris item editable.
class _EditableItemCard extends StatelessWidget {
  const _EditableItemCard({
    required this.index,
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _EditableItem item;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Badge urut
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: item.priceGuessed
                        ? Colors.orange.shade100
                        : Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: item.priceGuessed
                            ? Colors.orange.shade800
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Nama item
                Expanded(
                  child: TextFormField(
                    controller: item.nameCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Nama item',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => onChanged(),
                  ),
                ),
                IconButton(
                  tooltip: 'Hapus item',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Harga
                Expanded(
                  child: TextFormField(
                    controller: item.priceCtrl,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Harga (Rp)',
                      prefixText: 'Rp ',
                      border: const OutlineInputBorder(),
                      suffixIcon: item.priceGuessed
                          ? const Icon(
                              Icons.warning_amber,
                              size: 16,
                              color: Colors.orange,
                            )
                          : null,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 8),
                // Qty
                SizedBox(
                  width: 64,
                  child: TextFormField(
                    controller: item.qtyCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Qty',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ],
            ),
            // Subtotal
            if (item.lineTotal > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Subtotal: ${formatRupiah(item.lineTotal)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Warning bila total item tidak cocok dengan total struk.
class _TotalWarning extends StatelessWidget {
  const _TotalWarning({
    required this.itemsTotal,
    required this.receiptTotal,
  });

  final MoneyAmount itemsTotal;
  final MoneyAmount receiptTotal;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Total item (${formatRupiah(itemsTotal)}) tidak cocok dengan '
              'TOTAL struk (${formatRupiah(receiptTotal)}). '
              'Periksa kembali item yang salah atau belum terdeteksi.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner info item yang perlu diedit manual.
class _GuessedItemBanner extends StatelessWidget {
  const _GuessedItemBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 6),
          Text(
            'Item bertanda  perlu diedit — harga/qty belum terdeteksi.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.blue.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
