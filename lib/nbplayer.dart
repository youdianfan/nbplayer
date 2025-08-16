/*
 * 参考实现要点摘要 (基于 ijk/fijkplayer & ijk/lib):
 * - Channel 名称: "com.newsbang.nbplayer/methods_{playerId}" (方法调用)
 * - 核心方法: setDataSource, prepareAsync, start, pause, stop, reset, release
 * - 状态机: idle(0) -> initialized(1) -> asyncPreparing(2) -> prepared(3) -> started(4)/paused(5)/completed(6)/stopped(7)/error(8)/end(9)
 * - 事件处理: 通过 EventChannel 接收播放状态变化、错误等事件
 * - 依赖: 使用 IjkMediaPlayer 作为底层音频播放引擎
 */

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// 播放器状态枚举，对应参考实现的状态机
enum NbPlayerState {
  idle,           // 0 - 空闲状态
  initialized,    // 1 - 已初始化
  asyncPreparing, // 2 - 异步准备中
  prepared,       // 3 - 准备完成
  started,        // 4 - 播放中
  paused,         // 5 - 暂停
  completed,      // 6 - 播放完成
  stopped,        // 7 - 停止
  error,          // 8 - 错误
  end             // 9 - 结束/释放
}

/// 基于 ijkplayer 的音频播放器，API 设计参考 FijkPlayer
/// 支持 setDataSource, prepareAsync, start, pause, stop, reset, release 方法
class Nbplayer extends ChangeNotifier {
  static int _nextPlayerId = 1;
  static final MethodChannel _globalChannel = MethodChannel('com.newsbang.nbplayer/global');

  final int _playerId = _nextPlayerId++;
  late MethodChannel _methodChannel;
  late EventChannel _eventChannel;
  StreamSubscription<dynamic>? _eventSubscription;

  NbPlayerState _state = NbPlayerState.idle;
  String? _dataSource;
  bool _disposed = false;
  bool _initialized = false;

  /// 获取当前播放器状态
  NbPlayerState get state => _state;

  /// 获取播放器ID
  int get playerId => _playerId;

  /// 获取数据源
  String? get dataSource => _dataSource;

  /// 是否已释放
  bool get disposed => _disposed;

  Nbplayer() {
    _methodChannel = MethodChannel('com.newsbang.nbplayer/methods_$_playerId');
    _eventChannel = EventChannel('com.newsbang.nbplayer/events_$_playerId');
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // 通知 Android 端创建播放器实例
      await _globalChannel.invokeMethod('createPlayer', {'playerId': _playerId.toString()});
      _setupEventListener();
      _initialized = true;
      debugPrint('NbPlayer $_playerId initialized');
    } catch (e) {
      debugPrint('Failed to initialize NbPlayer $_playerId: $e');
      _updateState(NbPlayerState.error);
    }
  }

  void _setupEventListener() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _onEvent,
      onError: _onError,
    );
  }

  void _onEvent(dynamic event) {
    if (event is Map) {
      final String? eventType = event['event'];
      final int? newState = event['state'];

      if (eventType == 'state_change' && newState != null) {
        _updateState(NbPlayerState.values[newState]);
      }
    }
  }

  void _onError(dynamic error) {
    debugPrint('NbPlayer $_playerId event error: $error');
    _updateState(NbPlayerState.error);
  }

  void _updateState(NbPlayerState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  /// 设置数据源，支持 HTTP/HTTPS URL
  /// 参数 [url] 音频文件的 URL
  /// 参数 [headers] 可选的 HTTP 请求头
  Future<void> setDataSource(String url, {Map<String, String>? headers}) async {
    await _ensureInitialized();
    _throwIfDisposed();

    if (_state != NbPlayerState.idle && _state != NbPlayerState.initialized) {
      throw StateError('setDataSource called in invalid state: $_state');
    }

    try {
      await _methodChannel.invokeMethod('setDataSource', {
        'url': url,
        'headers': headers,
      });
      _dataSource = url;
      _updateState(NbPlayerState.initialized);
    } on PlatformException catch (e) {
      _updateState(NbPlayerState.error);
      throw Exception('Failed to set data source: ${e.message}');
    }
  }

  /// 异步准备播放器
  Future<void> prepareAsync() async {
    await _ensureInitialized();
    _throwIfDisposed();

    if (_state != NbPlayerState.initialized) {
      throw StateError('prepareAsync called in invalid state: $_state');
    }

    try {
      _updateState(NbPlayerState.asyncPreparing);
      await _methodChannel.invokeMethod('prepareAsync');
    } on PlatformException catch (e) {
      _updateState(NbPlayerState.error);
      throw Exception('Failed to prepare: ${e.message}');
    }
  }

  /// 开始播放
  Future<void> start() async {
    await _ensureInitialized();
    _throwIfDisposed();

    // 如果是 initialized 状态，自动调用 prepareAsync 并开始播放
    if (_state == NbPlayerState.initialized) {
      try {
        await _methodChannel.invokeMethod('startFromInitialized');
      } on PlatformException catch (e) {
        _updateState(NbPlayerState.error);
        throw Exception('Failed to start from initialized: ${e.message}');
      }
      return;
    }

    // 其他可播放状态直接开始
    if (_isPlayableState()) {
      try {
        await _methodChannel.invokeMethod('start');
      } on PlatformException catch (e) {
        _updateState(NbPlayerState.error);
        throw Exception('Failed to start: ${e.message}');
      }
    } else {
      throw StateError('start called in invalid state: $_state');
    }
  }

  /// 暂停播放
  Future<void> pause() async {
    await _ensureInitialized();
    _throwIfDisposed();

    if (!_isPlayableState()) {
      throw StateError('pause called in invalid state: $_state');
    }

    try {
      await _methodChannel.invokeMethod('pause');
    } on PlatformException catch (e) {
      _updateState(NbPlayerState.error);
      throw Exception('Failed to pause: ${e.message}');
    }
  }

  /// 停止播放
  Future<void> stop() async {
    await _ensureInitialized();
    _throwIfDisposed();

    if (_state == NbPlayerState.idle ||
        _state == NbPlayerState.initialized ||
        _state == NbPlayerState.end) {
      throw StateError('stop called in invalid state: $_state');
    }

    try {
      await _methodChannel.invokeMethod('stop');
      _updateState(NbPlayerState.stopped);
    } on PlatformException catch (e) {
      _updateState(NbPlayerState.error);
      throw Exception('Failed to stop: ${e.message}');
    }
  }

  /// 重置播放器到初始状态
  Future<void> reset() async {
    await _ensureInitialized();
    _throwIfDisposed();

    if (_state == NbPlayerState.end) {
      throw StateError('reset called in invalid state: $_state');
    }

    try {
      await _methodChannel.invokeMethod('reset');
      _dataSource = null;
      _updateState(NbPlayerState.idle);
    } on PlatformException catch (e) {
      _updateState(NbPlayerState.error);
      throw Exception('Failed to reset: ${e.message}');
    }
  }

  /// 释放播放器资源
  Future<void> release() async {
    if (_disposed) return;

    try {
      if (_initialized) {
        await _methodChannel.invokeMethod('release');
        await _globalChannel.invokeMethod('releasePlayer', {'playerId': _playerId.toString()});
      }
    } catch (e) {
      debugPrint('Error during release: $e');
    } finally {
      await _eventSubscription?.cancel();
      _eventSubscription = null;
      _disposed = true;
      _updateState(NbPlayerState.end);
    }
  }

  @override
  void dispose() {
    if (!_disposed) {
      release();
    }
    super.dispose();
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized && !_disposed) {
      await _initialize();
    }
  }

  bool _isPlayableState() {
    return _state == NbPlayerState.prepared ||
           _state == NbPlayerState.started ||
           _state == NbPlayerState.paused ||
           _state == NbPlayerState.completed;
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw StateError('Player has been disposed');
    }
  }

  /// 兼容原有 API - 获取平台版本
  Future<String?> getPlatformVersion() async {
    await _ensureInitialized();
    _throwIfDisposed();

    try {
      return await _methodChannel.invokeMethod<String>('getPlatformVersion');
    } on PlatformException catch (e) {
      throw Exception('Failed to get platform version: ${e.message}');
    }
  }
}
