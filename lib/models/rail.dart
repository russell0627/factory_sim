import 'package:flutter/foundation.dart';

@immutable
class Rail {
  const Rail({required this.row, required this.col});
  final int row;
  final int col;
}