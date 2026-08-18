/// Widget test Quick-Entry Sheet — mereproduksi bug modal-overlay Provider.
///
/// Membuktikan bahwa sheet "Tambah pengeluaran" yang di-push via
/// `showModalBottomSheet` dari `GroupDetailScreen` benar-benar menampilkan
/// form (nominal, pembayar, split) — bukan layar blank putih akibat
/// `ProviderNotFoundException` karena modal overlay tidak mewarisi
/// `ChangeNotifierProvider<GroupDetailStore>` di route detail grup.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:debt_splitter/app/services/debt_splitter_service.dart';
import 'package:debt_splitter/app/services/share_service.dart';
import 'package:debt_splitter/app/state/group_list_store.dart';
import 'package:debt_splitter/app/ui/dashboard_screen.dart';
import 'package:debt_splitter/core/db/app_database.dart';

import '../helpers/test_db.dart';

void main() {
  setUpAll(initSqfliteFfi);

  late AppDatabase db;
  late DebtSplitterService service;
  late GroupListStore store;

  setUp(() async {
    db = await openTestDatabase();
    service = DebtSplitterService(db);
    store = GroupListStore(service);
  });

  tearDown(() async => db.close());

  Widget buildApp() {
    return MultiProvider(
      providers: [
        Provider<DebtSplitterService>.value(value: service),
        Provider<ShareService>.value(value: const ShareService()),
        ChangeNotifierProvider<GroupListStore>.value(value: store),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const DashboardScreen(),
      ),
    );
  }

  testWidgets(
    'FAB + pada detail grup membuka form quick-entry (bukan blank)',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Buat grup baru dari dashboard.
      await tester.tap(find.text('Grup Baru'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Trip Bromo');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Budi, Andi, Citra',
      );
      await tester.tap(find.text('Buat'));
      await tester.pumpAndSettle();

      // Sudah masuk layar detail grup.
      expect(find.text('Trip Bromo'), findsOneWidget);

      // Tekan FAB '+' untuk membuka quick-entry sheet.
      await tester.tap(find.byTooltip('Tambah pengeluaran'));
      await tester.pumpAndSettle();

      // Form harus terlihat — bukan sheet kosong.
      expect(find.text('Catat Pengeluaran'), findsOneWidget);
      expect(find.text('Nominal (Rp)'), findsOneWidget);
      expect(find.text('Dibayar oleh'), findsOneWidget);
      expect(find.text('Sama rata'), findsOneWidget);
      expect(find.text('Simpan'), findsOneWidget);
    },
  );

  testWidgets(
    'mode Struk: segmen membuka editor item (bukan blank)',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Grup Baru'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Trip Bromo');
      await tester.enterText(find.byType(TextFormField).at(1), 'Budi, Andi');
      await tester.tap(find.text('Buat'));
      await tester.pumpAndSettle();

      // Buka quick-entry lalu pilih segmen "Struk".
      await tester.tap(find.byTooltip('Tambah pengeluaran'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Struk'));
      await tester.pumpAndSettle();

      expect(find.text('Daftar item struk'), findsOneWidget);
      expect(find.text('Tambah item'), findsWidgets);
      expect(
        find.text('Belum ada item. Tambahkan menu dari struk.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Fitur B: item baru pre-checked saat toggle ON, uncheck saat toggle OFF, dan aksi massal',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Grup Baru'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Trip Bali');
      await tester.enterText(find.byType(TextFormField).at(1), 'Budi, Andi');
      await tester.tap(find.text('Buat'));
      await tester.pumpAndSettle();

      // Buka quick-entry lalu pilih segmen "Struk".
      await tester.tap(find.byTooltip('Tambah pengeluaran'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Struk'));
      await tester.pumpAndSettle();

      // 1. Toggle "Item baru otomatis dibagi semua anggota" harus ada dan aktif (ON by default)
      final toggleFinder = find.widgetWithText(
        SwitchListTile,
        'Item baru otomatis dibagi semua anggota',
      );
      expect(toggleFinder, findsOneWidget);
      final switchWidget = tester.widget<SwitchListTile>(toggleFinder);
      expect(switchWidget.value, isTrue);

      // Tambah item 1 saat toggle ON
      await tester.tap(find.widgetWithText(OutlinedButton, 'Tambah item').first);
      await tester.pumpAndSettle();

      // Item 1 harus memiliki FilterChip untuk Budi dan Andi yang tercentang (selected == true)
      final chipsItem1 = tester.widgetList<FilterChip>(find.byType(FilterChip)).toList();
      expect(chipsItem1.length, 2);
      expect(chipsItem1[0].selected, isTrue);
      expect(chipsItem1[1].selected, isTrue);

      // 2. Matikan toggle global OFF
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Tambah item 2 saat toggle OFF
      await tester.tap(find.widgetWithText(OutlinedButton, 'Tambah item').first);
      await tester.pumpAndSettle();

      // Sekarang total ada 4 chip (2 untuk item 1, 2 untuk item 2)
      final chipsAll = tester.widgetList<FilterChip>(find.byType(FilterChip)).toList();
      expect(chipsAll.length, 4);
      // Item 1 masih tercentang
      expect(chipsAll[0].selected, isTrue);
      expect(chipsAll[1].selected, isTrue);
      // Item 2 kosong (tidak tercentang)
      expect(chipsAll[2].selected, isFalse);
      expect(chipsAll[3].selected, isFalse);

      // 3. Aksi massal: "Centang semua" untuk seluruh bill
      expect(find.text('Centang semua'), findsOneWidget);
      expect(find.text('Kosongkan semua'), findsOneWidget);

      await tester.tap(find.text('Centang semua'));
      await tester.pumpAndSettle();

      final chipsAfterCheckAll = tester.widgetList<FilterChip>(find.byType(FilterChip)).toList();
      for (final chip in chipsAfterCheckAll) {
        expect(chip.selected, isTrue);
      }

      // Aksi massal: "Kosongkan semua" untuk seluruh bill
      await tester.tap(find.text('Kosongkan semua'));
      await tester.pumpAndSettle();

      final chipsAfterUncheckAll = tester.widgetList<FilterChip>(find.byType(FilterChip)).toList();
      for (final chip in chipsAfterUncheckAll) {
        expect(chip.selected, isFalse);
      }

      // 4. Perilaku per-item tetap:
      // Klik chip individual (Budi pada item 1)
      final chipBudiItem1 = find.widgetWithText(FilterChip, 'Budi').first;
      await tester.ensureVisible(chipBudiItem1);
      await tester.tap(chipBudiItem1);
      await tester.pumpAndSettle();

      final budiChipsAfterSingle = tester.widgetList<FilterChip>(find.widgetWithText(FilterChip, 'Budi')).toList();
      final andiChipsAfterSingle = tester.widgetList<FilterChip>(find.widgetWithText(FilterChip, 'Andi')).toList();
      expect(budiChipsAfterSingle[0].selected, isTrue); // Budi item 1
      expect(andiChipsAfterSingle[0].selected, isFalse); // Andi item 1
      expect(budiChipsAfterSingle[1].selected, isFalse); // Budi item 2
      expect(andiChipsAfterSingle[1].selected, isFalse); // Andi item 2

      // Klik 'Pilih semua' pada item 2
      final pilihSemuaItem2 = find.text('Pilih semua').last;
      await tester.ensureVisible(pilihSemuaItem2);
      await tester.tap(pilihSemuaItem2);
      await tester.pumpAndSettle();

      final budiChipsAfterItem2 = tester.widgetList<FilterChip>(find.widgetWithText(FilterChip, 'Budi')).toList();
      final andiChipsAfterItem2 = tester.widgetList<FilterChip>(find.widgetWithText(FilterChip, 'Andi')).toList();
      expect(budiChipsAfterItem2[0].selected, isTrue); // Budi item 1 (tidak terpengaruh)
      expect(andiChipsAfterItem2[0].selected, isFalse); // Andi item 1 (tidak terpengaruh)
      expect(budiChipsAfterItem2[1].selected, isTrue); // Budi item 2
      expect(andiChipsAfterItem2[1].selected, isTrue); // Andi item 2
    },
  );
}
