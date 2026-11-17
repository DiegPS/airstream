import 'dart:io';
import 'package:airstream/services/templates/template_library.dart';

// No platform channels or existing user templates in legacy server tests.
TemplateLibrary emptyTemplateLibrary() => TemplateLibrary(
    Directory('${Directory.systemTemp.path}/airstream-absent-templates-$pid'));
