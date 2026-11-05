import 'package:ae_coaching/l10n/app_localizations_ar.dart';
import 'package:ae_coaching/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Personal Hub and settings labels exist in both supported languages',
    () {
      final english = AppLocalizationsEn();
      final arabic = AppLocalizationsAr();

      expect(english.personalHubTitle, 'Personal Hub');
      expect(english.profileAddPhoto, 'Add photo');
      expect(english.myProgressTitle, 'My progress');
      expect(english.progressPersonalRecords, 'Personal records');
      expect(english.appSettingsTitle, 'App settings');
      expect(arabic.personalHubTitle, isNotEmpty);
      expect(arabic.profileAddPhoto, isNotEmpty);
      expect(arabic.myProgressTitle, isNotEmpty);
      expect(arabic.progressPersonalRecords, isNotEmpty);
      expect(arabic.appSettingsTitle, isNotEmpty);
    },
  );
}
