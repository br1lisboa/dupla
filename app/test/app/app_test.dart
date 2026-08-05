import 'package:dupla/app/index.dart';
import 'package:dupla/features/home/index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots and lands on the home screen', (tester) async {
    await tester.pumpWidget(const DuplaApp());

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
