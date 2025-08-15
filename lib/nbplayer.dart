import 'nbplayer_platform_interface.dart';

class Nbplayer {
  Future<String?> getPlatformVersion() {
    return NbplayerPlatform.instance.getPlatformVersion();
  }

  /// Set the data source for the audio player
  Future<void> setDataSource(String url) {
    return NbplayerPlatform.instance.setDataSource(url);
  }

  /// Start audio playback
  Future<void> start() {
    return NbplayerPlatform.instance.start();
  }

  /// Pause audio playback
  Future<void> pause() {
    return NbplayerPlatform.instance.pause();
  }

  /// Stop audio playback
  Future<void> stop() {
    return NbplayerPlatform.instance.stop();
  }

  /// Reset the audio player
  Future<void> reset() {
    return NbplayerPlatform.instance.reset();
  }

  /// Dispose and release all player resources
  Future<void> dispose() {
    return NbplayerPlatform.instance.dispose();
  }
}
