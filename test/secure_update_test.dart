import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_tech/services/secure_update_service.dart';

void main() {
  group('SecureUpdateService', () {
    test('isNewer detecte une version plus recente', () {
      expect(SecureUpdateService.isNewer('1.13.4', '1.13.3'), true);
      expect(SecureUpdateService.isNewer('1.14.0', '1.13.3'), true);
      expect(SecureUpdateService.isNewer('1.13.3', '1.13.3'), false);
      expect(SecureUpdateService.isNewer('1.13.2', '1.13.3'), false);
    });
  });
}
