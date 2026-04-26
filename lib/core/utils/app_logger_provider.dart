import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_logger.dart';

final appLoggerProvider = Provider<AppLogger>((_) => AppLogger());
