import 'package:flutter_test/flutter_test.dart';
import 'package:prix_vif/main.dart';
import 'package:prix_vif/widgets/magic_title.dart';

void main() {
  testWidgets('App load smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PrixVifApp());

    // Vérifier que le titre du scanner s'affiche bien (via NeonTitle)
    expect(find.byType(NeonTitle), findsWidgets);
  });
}
