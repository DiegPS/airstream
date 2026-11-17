import 'dart:async';
import 'package:airstream/application/rules/rule_engine.dart';
import 'package:airstream/application/rules/rule_events.dart';

class RulesTestTarget implements RuleActionTarget {
  final calls = <Map<String, dynamic>>[];
  @override
  bool streaming = true;
  @override
  String currentScene = 'Gameplay';
  @override
  Map<String, int> counters = {};
  @override
  String? skipReason(Map<String, dynamic> action, RuleEvent event) => null;
  @override
  Future<RuleActionResult> execute(
      Map<String, dynamic> action, RuleRun run) async {
    calls.add(action);
    return RuleActionResult.done;
  }
}
