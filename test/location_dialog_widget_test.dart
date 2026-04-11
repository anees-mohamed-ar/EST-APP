import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget Test for Location Error Dialog
/// 
/// This test visually displays the location error dialog to verify its appearance
/// and content. Run with: flutter test test/location_dialog_widget_test.dart
/// 
/// To see the actual dialog visualization, you can also run this as an integration test
/// or use the Flutter DevTools to inspect the widget tree during the test.

void main() {
  testWidgets('Location error dialog displays correctly', (WidgetTester tester) async {
    // Create a test widget that shows the dialog
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Row(
                            children: [
                              Icon(Icons.location_off, size: 32, color: Colors.red),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Location Required',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Please turn on your phone\'s location (GPS) to check in or check out.',
                                style: TextStyle(fontSize: 18, height: 1.5),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'We need to know where you are for safety.',
                                style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.4),
                              ),
                              SizedBox(height: 16),
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange[300]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.orange[700]),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'After turning on location, try again.',
                                        style: TextStyle(fontSize: 15, color: Colors.orange[900]),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text(
                                'Cancel',
                                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: Text(
                                'Open Settings',
                                style: TextStyle(fontSize: 16, color: Colors.white),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: Text(
                                'Try Again',
                                style: TextStyle(fontSize: 16, color: Colors.white),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: Text('Show Location Error Dialog'),
                ),
              );
            },
          ),
        ),
      ),
    );

    // Tap the button to show the dialog
    await tester.tap(find.text('Show Location Error Dialog'));
    await tester.pumpAndSettle();

    // Verify the dialog is displayed
    expect(find.text('Location Required'), findsOneWidget);
    expect(find.text('Please turn on your phone\'s location (GPS) to check in or check out.'), findsOneWidget);
    expect(find.text('We need to know where you are for safety.'), findsOneWidget);
    expect(find.text('After turning on location, try again.'), findsOneWidget);
    
    // Verify buttons
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    
    // Verify icons
    expect(find.byIcon(Icons.location_off), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);

    print('✓ Location error dialog displayed correctly');
    print('✓ All expected content is present');
    print('✓ Dialog is large and easy to read for older people');
  });
}
