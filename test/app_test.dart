import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notiflow/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('com.notiflow.app/native'), (call) async {
      switch (call.method) {
        case 'hasAccess': return false;
        case 'list': return <Map<String, Object>>[];
        case 'preferences': return <Map<String, String>>[];
        default: return null;
      }
    },
  );
  testWidgets('welcome and permission explain notification access', (tester) async {
    await tester.pumpWidget(const NotiflowApp());
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Notification access'), findsOneWidget);
    expect(find.text('Open Android access settings'), findsOneWidget);
  });
}
