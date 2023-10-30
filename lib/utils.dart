import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Generic AsyncValueWidget to work with values of type T
class AsyncValueWidget<T> extends StatelessWidget {
  const AsyncValueWidget({super.key, required this.value, required this.data});

  // input async value
  final AsyncValue<T> value;
  // output builder function
  final Widget Function(T) data;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (
        err,
        _,
      ) =>
          Center(
        child: Text(
          err.toString(),
          style: Theme.of(context)
              .textTheme
              .titleLarge!
              .copyWith(color: Colors.red),
        ),
      ),
    );
  }
}
