import 'dart:io';

import 'package:ae_coaching/features/profile/data/local_profile_photo_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporaryDirectory;
  late Directory documentsDirectory;
  late Box<dynamic> authBox;
  late LocalProfilePhotoStore store;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'profile_photo_test_',
    );
    documentsDirectory = Directory('${temporaryDirectory.path}/documents');
    await documentsDirectory.create(recursive: true);
    Hive.init('${temporaryDirectory.path}/hive');
    authBox = await Hive.openBox<dynamic>('authBox');
    store = LocalProfilePhotoStore(
      authBox,
      documentsDirectory: () async => documentsDirectory,
    );
  });

  tearDown(() async {
    await authBox.close();
    await Hive.deleteFromDisk();
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test(
    'photo is copied to persistent storage and restored after recreation',
    () async {
      final source = File('${temporaryDirectory.path}/picked.jpg');
      await source.writeAsBytes([1, 2, 3, 4]);

      final savedPath = await store.savePhoto(uid: 'user-a', source: source);
      await authBox.close();
      await Hive.close();
      Hive.init('${temporaryDirectory.path}/hive');
      authBox = await Hive.openBox<dynamic>('authBox');
      final recreatedStore = LocalProfilePhotoStore(
        authBox,
        documentsDirectory: () async => documentsDirectory,
      );

      expect(await recreatedStore.getPhotoPath('user-a'), savedPath);
      expect(await File(savedPath).exists(), isTrue);
    },
  );

  test(
    'accounts are isolated and removal only deletes the selected user photo',
    () async {
      final firstSource = File('${temporaryDirectory.path}/first.jpg');
      final secondSource = File('${temporaryDirectory.path}/second.jpg');
      await firstSource.writeAsBytes([1, 2, 3]);
      await secondSource.writeAsBytes([4, 5, 6]);

      final firstPath = await store.savePhoto(
        uid: 'user-a',
        source: firstSource,
      );
      final secondPath = await store.savePhoto(
        uid: 'user-b',
        source: secondSource,
      );
      expect(firstPath, isNot(secondPath));

      await store.removePhoto('user-a');

      expect(await store.getPhotoPath('user-a'), isNull);
      expect(await File(firstPath).exists(), isFalse);
      expect(await store.getPhotoPath('user-b'), secondPath);
      expect(await File(secondPath).exists(), isTrue);
    },
  );

  test(
    'changing a photo replaces only the previous photo for that account',
    () async {
      final firstSource = File('${temporaryDirectory.path}/first-version.jpg');
      final secondSource = File(
        '${temporaryDirectory.path}/second-version.jpg',
      );
      await firstSource.writeAsBytes([1, 2, 3]);
      await secondSource.writeAsBytes([4, 5, 6]);

      final firstPath = await store.savePhoto(
        uid: 'user-a',
        source: firstSource,
      );
      final secondPath = await store.savePhoto(
        uid: 'user-a',
        source: secondSource,
      );

      expect(await store.getPhotoPath('user-a'), secondPath);
      expect(await File(firstPath).exists(), isFalse);
      expect(await File(secondPath).exists(), isTrue);
    },
  );

  test('invalid stored paths are not exposed or deleted', () async {
    final outsideFile = File('${temporaryDirectory.path}/outside.jpg');
    await outsideFile.writeAsBytes([1, 2]);
    await authBox.put('profilePhotoPath.user-a', outsideFile.path);

    expect(await store.getPhotoPath('user-a'), isNull);
    await store.removePhoto('user-a');
    expect(await outsideFile.exists(), isTrue);
  });

  test('restores legacy mixed separators and rejects parent traversal', () async {
    final source = File('${temporaryDirectory.path}/legacy.jpg');
    await source.writeAsBytes([1, 2, 3]);
    final savedPath = await store.savePhoto(uid: 'user-a', source: source);
    await authBox.put('profilePhotoPath.user-a', savedPath.replaceAll(r'\', '/'));
    expect(await store.getPhotoPath('user-a'), savedPath);

    final outside = File.fromUri(File(savedPath).parent.parent.uri.resolve('outside.jpg'));
    await outside.writeAsBytes([4, 5, 6]);
    await authBox.put(
      'profilePhotoPath.user-a',
      '${File(savedPath).parent.path}/../outside.jpg',
    );
    expect(await store.getPhotoPath('user-a'), isNull);
    await store.removePhoto('user-a');
    expect(await outside.exists(), isTrue);
    expect(await File(savedPath).exists(), isTrue);
  });

  test(
    'rejects empty or oversized files without changing the saved pointer',
    () async {
      final validSource = File('${temporaryDirectory.path}/valid.jpg');
      final source = File('${temporaryDirectory.path}/empty.jpg');
      await validSource.writeAsBytes([1, 2, 3]);
      await source.writeAsBytes(const []);
      final savedPath = await store.savePhoto(
        uid: 'user-a',
        source: validSource,
      );

      await expectLater(
        store.savePhoto(uid: 'user-a', source: source),
        throwsA(isA<FileSystemException>()),
      );
      expect(await store.getPhotoPath('user-a'), savedPath);
      expect(await File(savedPath).exists(), isTrue);
    },
  );
}
