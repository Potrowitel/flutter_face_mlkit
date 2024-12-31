import 'package:camera/camera.dart' show XFile;

enum FaceScannerStatus {
  initial,
  ready,
  recording,
  inactive,
  saving,
  stopped,
  fail;
}

sealed class FaceScannerState {
  const FaceScannerState.FaceScannerState({required this.status});

  final FaceScannerStatus status;

  bool get isInitial => status == FaceScannerStatus.initial;
  bool get isReady => status == FaceScannerStatus.ready;
  bool get isInactive => status == FaceScannerStatus.inactive;
  bool get isRecording => status == FaceScannerStatus.recording;
  bool get isFail => status == FaceScannerStatus.fail;
  bool get isSaving => status == FaceScannerStatus.saving;
  bool get isStopped => status == FaceScannerStatus.stopped;

  Exception? get exception;

  const factory FaceScannerState.initial() = _InitialState;
  const factory FaceScannerState.ready() = _ReadyState;
  const factory FaceScannerState.inactive() = _InactiveState;
  const factory FaceScannerState.recording() = _RecordingState;
  const factory FaceScannerState.saving() = _SavingState;
  const factory FaceScannerState.stopped({XFile? file}) = _StoppedState;
  const factory FaceScannerState.fail({Exception? exception}) = _FailState;
}

class _InitialState extends FaceScannerState {
  const _InitialState()
      : super.FaceScannerState(status: FaceScannerStatus.initial);

  @override
  Exception? get exception => null;
}

class _ReadyState extends FaceScannerState {
  const _ReadyState() : super.FaceScannerState(status: FaceScannerStatus.ready);

  @override
  Exception? get exception => null;
}

class _InactiveState extends FaceScannerState {
  const _InactiveState()
      : super.FaceScannerState(status: FaceScannerStatus.inactive);

  @override
  Exception? get exception => null;
}

class _RecordingState extends FaceScannerState {
  const _RecordingState()
      : super.FaceScannerState(status: FaceScannerStatus.recording);

  @override
  Exception? get exception => null;
}

class _SavingState extends FaceScannerState {
  const _SavingState()
      : super.FaceScannerState(status: FaceScannerStatus.saving);

  @override
  Exception? get exception => null;
}

class _StoppedState extends FaceScannerState {
  const _StoppedState({this.file})
      : super.FaceScannerState(status: FaceScannerStatus.stopped);

  @override
  Exception? get exception => null;

  final XFile? file;
}

class _FailState extends FaceScannerState {
  const _FailState({this.exception})
      : super.FaceScannerState(status: FaceScannerStatus.fail);

  @override
  final Exception? exception;
}
