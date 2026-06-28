import 'package:flutter/widgets.dart';

Alignment chatHorizontalAlignment(String value) {
  return switch (value) {
    'center' => Alignment.center,
    'right' => Alignment.centerRight,
    _ => Alignment.centerLeft,
  };
}
