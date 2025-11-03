import 'package:logger/logger.dart';

class Log {
  static Logger? _logger;

  static void init() {
    _logger ??= Logger(
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 10,
        lineLength: 80,
      ),
    );
  }

  static Logger get i => _logger ??= Logger();
}
