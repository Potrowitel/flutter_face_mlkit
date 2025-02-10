import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_face_mlkit/isolates/face_detection_isolate.dart';
import 'package:flutter_face_mlkit/ui/face_scanner_state.dart';
import 'package:flutter_face_mlkit/utils/camera_type.dart';
import 'package:flutter_face_mlkit/utils/extension.dart';
import 'package:flutter_face_mlkit/utils/face_scanner.dart';

class FaceScannerScope extends StatefulWidget {
  final Widget child;
  const FaceScannerScope({super.key, required this.child});

  static FaceScannerScopeState of(BuildContext context, {bool listen = true}) =>
      context.inhOf<_FaceScannerInherited>(listen: listen).scopeState;

  @override
  State<FaceScannerScope> createState() => FaceScannerScopeState();
}

class FaceScannerScopeState extends State<FaceScannerScope> {
  //Scope states
  late final StreamController<FaceScannerState> _stream;
  late final StreamSubscription<FaceScannerState> _subscription;
  FaceScannerState _state = const FaceScannerState.initial();

  //FaceScanner
  final FaceScanner _faceScanner = FaceScanner();

  //AppLifecycle
  late final AppLifecycleListener _lifecycleListener;
  AppLifecycleState? _lifecyclestate;

  //Getters
  FaceScannerState get state => _state;
  FaceScannerStatus get status => _state.status;
  bool get isInitial => _state.isInitial;
  Size? get previewSize => _faceScanner.controller?.value.previewSize;
  CameraController? get controller => _faceScanner.controller;
  Stream<ProcessResponse> get processStream => _faceScanner.streamFace;

  FaceScanner get scanner => _faceScanner;

  @override
  void initState() {
    super.initState();
    //Scope initialization
    _stream = StreamController();
    _subscription = _stream.stream.listen(
      _didChangeState,
      onError: _errorHandler,
    );

    _lifecycleListener = AppLifecycleListener(
        binding: WidgetsBinding.instance,
        onStateChange: _onLifecycleStateChange);

    //Camera initialize
    _initializeCamera();
  }

  @override
  void dispose() {
    _faceScanner.dispose();
    _lifecycleListener.dispose();
    _subscription.cancel();
    _stream.close();
    super.dispose();
  }

  void save() async {
    _stream.add(FaceScannerState.saving());
    XFile? file = await _faceScanner.stopVideo();
    _stream.add(FaceScannerState.stopped(file: file));
  }

  void _onLifecycleStateChange(AppLifecycleState state) async {
    if (_lifecyclestate == AppLifecycleState.resumed &&
        state == AppLifecycleState.inactive) {
      _stream.add(FaceScannerState.inactive());
    } else if (state == AppLifecycleState.hidden) {
      _stream.add(FaceScannerState.fail(
          exception: Exception(
        'Пожалуйста, не сворачивайте приложение во время выполнения процесса. Это может привести к его прерыванию или ошибкам.',
      )));
    } else if (!_state.isFail && state == AppLifecycleState.resumed) {
      _stream.add(FaceScannerState.initial());
    }
    _lifecyclestate = state;
  }

  void _didChangeState(FaceScannerState state) async {
    if (_state != state) {
      print(
          'State change from ${_state.status} to ${state.status} ${_state.exception} ${state.exception}');
      if (!_state.isFail && state.isInitial) {
        await _initializeCamera();
      } else if (state.isFail || state.isInactive) {
        await _disposeScanner();
      }
      setState(() => _state = state);
    }
  }

  Future<void> _disposeScanner() async {
    await _faceScanner.stopVideo();
    await _faceScanner.dispose();
  }

  void _errorHandler(Object err) {
    if (err is CameraException) {
      _stream.add(FaceScannerState.fail(exception: err));
    } else {
      _stream.add(FaceScannerState.fail(exception: Exception(err)));
    }
  }

  Future<void> _initializeCamera() async {
    try {
      await _faceScanner.initial(CameraType.front);
      _stream.add(FaceScannerState.ready());
      await _faceScanner.startRecord();
      _stream.add(FaceScannerState.recording());
    } catch (err, stackTrace) {
      _stream.addError(err, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FaceScannerInherited(
      state: _state,
      scopeState: this,
      child: widget.child,
    );
  }
}

class _FaceScannerInherited extends InheritedWidget {
  const _FaceScannerInherited({
    required super.child,
    required this.state,
    required this.scopeState,
  });

  final FaceScannerState state;
  final FaceScannerScopeState scopeState;

  @override
  bool updateShouldNotify(_FaceScannerInherited oldWidget) =>
      state != oldWidget.state;
}
