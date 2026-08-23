import 'package:flutter_test/flutter_test.dart';
import 'package:gobran/main.dart';

void main() {
  testWidgets('Menampilkan halaman konfigurasi ketika Firebase bermasalah', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      GoBranApp(firebaseError: Exception('Firebase test')),
    );

    await tester.pumpAndSettle();

    expect(find.text('Hubungkan Firebase'), findsOneWidget);
  });
}
