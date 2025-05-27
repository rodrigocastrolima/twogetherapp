import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class MinimalDebugExtraPage extends StatelessWidget {
  final dynamic extraData;

  const MinimalDebugExtraPage({super.key, this.extraData});

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print('[MinimalDebugExtraPage] Received extra: ${extraData?.runtimeType} - ${extraData.toString()}');
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minimal Debug Page'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Extra Received:\nRuntimeType: ${extraData?.runtimeType}\nToString: ${extraData.toString()}',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
} 