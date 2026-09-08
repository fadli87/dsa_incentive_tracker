import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_incentive_tracker/main.dart';

void main() {
  testWidgets('App renders and navigates tabs smoke test',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('KALKULATOR INCENTIVE'), findsOneWidget);
    expect(find.text('WILAYAH'), findsOneWidget);
    expect(find.text('KAB. CILACAP'), findsOneWidget);

    // Tap on 'Insentif' tab
    await tester.tap(find.text('Insentif'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Histori Pencapaian'), findsOneWidget);
  });
}
