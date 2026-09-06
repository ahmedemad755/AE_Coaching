part of 'progress_photo_cubit.dart';

enum ProgressPhotoOperation { load, add, delete }

abstract class ProgressPhotoState {
  const ProgressPhotoState();
}

class ProgressPhotoInitial extends ProgressPhotoState {
  const ProgressPhotoInitial();
}

class ProgressPhotoLoading extends ProgressPhotoState {
  final ProgressPhotoOperation operation;

  const ProgressPhotoLoading({required this.operation});
}

class ProgressPhotoSuccess extends ProgressPhotoState {
  final ProgressPhotoOperation operation;
  final Box<ProgressPhoto> box;
  final String message;

  const ProgressPhotoSuccess({
    required this.operation,
    required this.box,
    required this.message,
  });
}

class ProgressPhotoError extends ProgressPhotoState {
  final ProgressPhotoOperation operation;
  final String message;

  const ProgressPhotoError({
    required this.operation,
    required this.message,
  });
}
