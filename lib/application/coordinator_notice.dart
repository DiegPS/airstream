import 'package:airstream/models/app_notice.dart';

class CoordinatorNotice {
  const CoordinatorNotice(this.code, this.severity);

  final AppNoticeCode code;
  final AppNoticeSeverity severity;
}
