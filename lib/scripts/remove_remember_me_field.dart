// Script to remove the "rememberMe" field from all users in Firestore
// Run this script with:
// flutter run -d chrome -t lib/scripts/remove_remember_me_field.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const RemoveRememberMeApp());
}

class RemoveRememberMeApp extends StatelessWidget {
  const RemoveRememberMeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const RemoveRememberMeScreen(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
    );
  }
}

class RemoveRememberMeScreen extends StatefulWidget {
  const RemoveRememberMeScreen({Key? key}) : super(key: key);

  @override
  State<RemoveRememberMeScreen> createState() => _RemoveRememberMeScreenState();
}

class _RemoveRememberMeScreenState extends State<RemoveRememberMeScreen> {
  bool _isProcessing = false;
  String _status = 'Ready to remove "rememberMe" field from user documents.';
  int _processedCount = 0;
  int _totalCount = 0;
  List<String> _logs = [];

  Future<void> _removeRememberMeField() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _status = 'Processing...';
      _logs = [];
    });

    try {
      // Get reference to the users collection
      final usersCollection = FirebaseFirestore.instance.collection('users');

      // Get all user documents
      final QuerySnapshot userSnapshot = await usersCollection.get();
      _totalCount = userSnapshot.docs.length;

      setState(() {
        _logs.add('Found $_totalCount user documents.');
      });

      // Count how many users have the rememberMe field
      int usersWithRememberMe = 0;
      for (var doc in userSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('rememberMe')) {
          usersWithRememberMe++;
        }
      }

      setState(() {
        _logs.add(
          'Found $usersWithRememberMe users with the "rememberMe" field.',
        );
      });

      // Remove the rememberMe field from all users that have it
      for (var doc in userSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('rememberMe')) {
          await usersCollection.doc(doc.id).update({
            'rememberMe': FieldValue.delete(),
          });

          _processedCount++;
          setState(() {
            _logs.add('Removed "rememberMe" field from user ${doc.id}');
          });
        }
      }

      setState(() {
        _isProcessing = false;
        _status =
            'Completed! Removed "rememberMe" field from $_processedCount users.';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _status = 'Error: ${e.toString()}';
        _logs.add('Error: ${e.toString()}');
      });
      if (kDebugMode) {
        print('Error removing rememberMe field: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remove RememberMe Field'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Remove "rememberMe" Field Utility',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                _status,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (_isProcessing)
                Column(
                  children: [
                    LinearProgressIndicator(
                      value:
                          _totalCount > 0
                              ? _processedCount / _totalCount
                              : null,
                    ),
                    const SizedBox(height: 10),
                    Text('Processed: $_processedCount / $_totalCount'),
                  ],
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isProcessing ? null : _removeRememberMeField,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('Start Cleanup'),
              ),
              const SizedBox(height: 20),
              if (_logs.isNotEmpty) ...[
                const Divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Logs:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            _logs[_logs.length - 1 - index],
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  _logs[_logs.length - 1 - index].contains(
                                        'Error',
                                      )
                                      ? Colors.red
                                      : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
