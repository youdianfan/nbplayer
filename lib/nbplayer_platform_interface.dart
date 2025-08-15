import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'nbplayer_method_channel.dart';

abstract class NbplayerPlatform extends PlatformInterface {
  /// Constructs a NbplayerPlatform.
  NbplayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static NbplayerPlatform _instance = MethodChannelNbplayer();

  /// The default instance of [NbplayerPlatform] to use.
  ///
  /// Defaults to [MethodChannelNbplayer].
  static NbplayerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [NbplayerPlatform] when
  /// they register themselves.
  static set instance(NbplayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Set the data source for the audio player
  Future<void> setDataSource(String url) {
    throw UnimplementedError('setDataSource() has not been implemented.');
  }

  /// Start audio playback
  Future<void> start() {
    throw UnimplementedError('start() has not been implemented.');
  }

  /// Pause audio playback
  Future<void> pause() {
    throw UnimplementedError('pause() has not been implemented.');
  }

  /// Stop audio playback
  Future<void> stop() {
    throw UnimplementedError('stop() has not been implemented.');
  }

  /// Reset the audio player
  Future<void> reset() {
    throw UnimplementedError('reset() has not been implemented.');
  }

  /// Dispose and release all player resources
  Future<void> dispose() {
    throw UnimplementedError('dispose() has not been implemented.');
  }
}
