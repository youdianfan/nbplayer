import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'nbplayer_platform_interface.dart';

/// An implementation of [NbplayerPlatform] that uses method channels.
class MethodChannelNbplayer extends NbplayerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('nbplayer');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<void> setDataSource(String url) async {
    await methodChannel.invokeMethod<void>('setDataSource', {'url': url});
  }

  @override
  Future<void> start() async {
    await methodChannel.invokeMethod<void>('start');
  }

  @override
  Future<void> pause() async {
    await methodChannel.invokeMethod<void>('pause');
  }

  @override
  Future<void> stop() async {
    await methodChannel.invokeMethod<void>('stop');
  }

  @override
  Future<void> reset() async {
    await methodChannel.invokeMethod<void>('reset');
  }

  @override
  Future<void> dispose() async {
    await methodChannel.invokeMethod<void>('dispose');
  }
}
