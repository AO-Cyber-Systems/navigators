import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Placeholder for turf polygon drawing screen.
/// Full implementation in Task 2.
class TurfDrawScreen extends ConsumerStatefulWidget {
  const TurfDrawScreen({super.key});

  @override
  ConsumerState<TurfDrawScreen> createState() => _TurfDrawScreenState();
}

class _TurfDrawScreenState extends ConsumerState<TurfDrawScreen> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Draw Screen - Loading...')),
    );
  }
}
