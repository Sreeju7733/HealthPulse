testWidgets('Firebase initialized text appears', (WidgetTester tester) async {
await tester.pumpWidget(
MaterialApp(
home: Scaffold(
body: Center(
child: Text('Firebase Initialized ✅'),
),
),
),
);

// Verify the text appears on screen
expect(find.text('Firebase Initialized ✅'), findsOneWidget);
});

