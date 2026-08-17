/// Unit test `ItemBillSplitter` — alokasi pengeluaran berbasis item/struk.
///
/// Kasus yang dicakup:
/// * satu item → satu orang / beberapa orang / sisa pembulatan;
/// * bill multi-item + `quantity` (contoh rumah makan dari requirement);
/// * properti **konservasi uang**: `sum(allocate) == totalOf` (termasuk brute
///   enumerate kombinasi kecil);
/// * **deterministik**: urutan claimant tidak mengubah hasil;
/// * validasi input korup (claimant kosong/duplikat, quantity 0, harga negatif).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:debt_splitter/core/money/item_bill_splitter.dart';

/// Helper: membangun [ItemBillLine] ringkas.
ItemBillLine _line({
  required String id,
  required int unitPrice,
  int quantity = 1,
  required List<String> claimants,
}) =>
    ItemBillLine(
      id: id,
      unitPrice: unitPrice,
      quantity: quantity,
      claimantIds: claimants,
    );

int _sumShares(Map<String, int> shares) =>
    shares.values.fold<int>(0, (acc, value) => acc + value);

void main() {
  group('ItemBillSplitter.allocate — satu item', () {
    test('1 item, 1 orang -> seluruh nominal masuk ke orang itu', () {
      final shares = ItemBillSplitter.allocate([
        _line(id: 'ng', unitPrice: 25_000, claimants: ['A']),
      ]);
      expect(shares, {'A': 25_000});
    });

    test('1 item dibagi rata 2 orang (habis tanpa sisa)', () {
      final shares = ItemBillSplitter.allocate([
        _line(id: 'sa', unitPrice: 30_000, claimants: ['A', 'B']),
      ]);
      expect(shares, {'A': 15_000, 'B': 15_000});
    });

    test('1 item dibagi 3 orang dengan sisa -> konservasi terjaga', () {
      // 100.003 / 3 -> base 33.334, sisa 1 -> satu claimant dapat +1.
      final bill = _line(
        id: 'i1',
        unitPrice: 100_003,
        claimants: ['A', 'B', 'C'],
      );
      final shares = ItemBillSplitter.allocate([bill]);

      expect(_sumShares(shares), ItemBillSplitter.totalOf([bill]));
      expect(shares, hasLength(3));
      final minS = shares.values.reduce((a, b) => a < b ? a : b);
      final maxS = shares.values.reduce((a, b) => a > b ? a : b);
      expect(maxS - minS, lessThanOrEqualTo(1));
    });
  });

  group('ItemBillSplitter.allocate — beberapa item (bill)', () {
    test('contoh bill rumah makan: 3 orang beda pesanan', () {
      final shares = ItemBillSplitter.allocate([
        _line(id: 'ng', unitPrice: 25_000, claimants: ['A']),
        _line(id: 'sa', unitPrice: 30_000, claimants: ['A', 'B']),
        _line(id: 'et1', unitPrice: 8_000, claimants: ['A']),
        _line(id: 'et2', unitPrice: 8_000, claimants: ['C']),
        _line(id: 'ag', unitPrice: 28_000, claimants: ['B']),
        _line(id: 'mi', unitPrice: 25_000, claimants: ['C']),
        _line(id: 'np', unitPrice: 10_000, claimants: ['B', 'C']),
        _line(id: 'ej', unitPrice: 20_000, claimants: ['C']),
      ]);

      // A: 25 + 15 + 8         = 48.000
      // B: 15 + 28 + 5         = 48.000
      // C: 8 + 25 + 5 + 20     = 58.000
      expect(shares, {'A': 48_000, 'B': 48_000, 'C': 58_000});
      expect(_sumShares(shares), 154_000);
    });

    test('quantity > 1: nominal baris = unitPrice * quantity, dibagi rata', () {
      // 2 Es Teh @ 8.000 = 16.000 untuk A & C -> masing 8.000.
      final shares = ItemBillSplitter.allocate([
        _line(
          id: 'et',
          unitPrice: 8_000,
          quantity: 2,
          claimants: ['A', 'C'],
        ),
      ]);
      expect(shares, {'A': 8_000, 'C': 8_000});
    });

    test('quantity > 1 dengan sisa pembulatan: konservasi terjaga', () {
      // 3 @ 10.001 = 30.003 untuk 4 orang -> base 7.500, sisa 3.
      final bill = _line(
        id: 'x',
        unitPrice: 10_001,
        quantity: 3,
        claimants: ['A', 'B', 'C', 'D'],
      );
      final shares = ItemBillSplitter.allocate([bill]);

      expect(_sumShares(shares), ItemBillSplitter.totalOf([bill]));
      expect(shares, hasLength(4));
      final minS = shares.values.reduce((a, b) => a < b ? a : b);
      final maxS = shares.values.reduce((a, b) => a > b ? a : b);
      expect(maxS - minS, lessThanOrEqualTo(1));
    });
  });

  group('ItemBillSplitter — properti konservasi & determinisme', () {
    test('sum(allocate) == totalOf untuk kombinasi kecil (brute force)', () {
      for (var unitPrice = 0; unitPrice <= 200; unitPrice++) {
        for (var quantity = 1; quantity <= 4; quantity++) {
          for (var n = 1; n <= 5; n++) {
            final lines = [
              _line(
                id: 'l',
                unitPrice: unitPrice,
                quantity: quantity,
                claimants: [for (var i = 0; i < n; i++) 'u$i'],
              ),
            ];
            final shares = ItemBillSplitter.allocate(lines);
            expect(
              _sumShares(shares),
              ItemBillSplitter.totalOf(lines),
              reason: 'unitPrice=$unitPrice quantity=$quantity n=$n',
            );
          }
        }
      }
    });

    test('urutan claimant tidak mengubah hasil (deterministik)', () {
      final a = ItemBillSplitter.allocate([
        _line(id: 'i', unitPrice: 100_003, claimants: ['B', 'A', 'C']),
      ]);
      final b = ItemBillSplitter.allocate([
        _line(id: 'i', unitPrice: 100_003, claimants: ['A', 'C', 'B']),
      ]);
      expect(a, b);
    });

    test('user yang tidak ikut baris mana pun tidak muncul di hasil', () {
      final shares = ItemBillSplitter.allocate([
        _line(id: 'i', unitPrice: 10_000, claimants: ['A']),
      ]);
      expect(shares.containsKey('B'), isFalse);
      expect(shares, {'A': 10_000});
    });

    test('akumulasi multi-baris pada user yang sama', () {
      final shares = ItemBillSplitter.allocate([
        _line(id: 'i1', unitPrice: 5_000, claimants: ['A']),
        _line(id: 'i2', unitPrice: 7_000, claimants: ['A', 'B']),
      ]);
      // A: 5.000 + 3.500 = 8.500; B: 3.500.
      expect(shares, {'A': 8_500, 'B': 3_500});
    });
  });

  group('ItemBillSplitter — input tidak valid', () {
    test('claimant kosong -> ArgumentError', () {
      expect(
        () => ItemBillSplitter.allocate(
          [_line(id: 'i', unitPrice: 1_000, claimants: [])],
        ),
        throwsArgumentError,
      );
    });

    test('quantity 0 -> ArgumentError', () {
      expect(
        () => ItemBillSplitter.allocate(
          [_line(id: 'i', unitPrice: 1_000, quantity: 0, claimants: ['A'])],
        ),
        throwsArgumentError,
      );
    });

    test('harga negatif -> ArgumentError', () {
      expect(
        () => ItemBillSplitter.allocate(
          [_line(id: 'i', unitPrice: -5, claimants: ['A'])],
        ),
        throwsArgumentError,
      );
    });

    test('claimant duplikat -> ArgumentError', () {
      expect(
        () => ItemBillSplitter.allocate(
          [_line(id: 'i', unitPrice: 1_000, claimants: ['A', 'A'])],
        ),
        throwsArgumentError,
      );
    });

    test('totalOf daftar kosong -> 0', () {
      expect(ItemBillSplitter.totalOf(const []), 0);
    });

    test('baris korup ditolak di totalOf juga', () {
      expect(
        () => ItemBillSplitter.totalOf(
          [_line(id: 'i', unitPrice: 10, quantity: 0, claimants: ['A'])],
        ),
        throwsArgumentError,
      );
    });
  });
}