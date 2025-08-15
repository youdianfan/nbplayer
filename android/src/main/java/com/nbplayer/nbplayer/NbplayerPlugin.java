package com.nbplayer.nbplayer;

import androidx.annotation.NonNull;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import tv.danmaku.ijk.media.player.IjkMediaPlayer;
import tv.danmaku.ijk.media.player.IMediaPlayer;

/** NbplayerPlugin */
public class NbplayerPlugin implements FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private MethodChannel channel;
  private IjkMediaPlayer mediaPlayer;
  private Context context;
  private Handler mainHandler;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "nbplayer");
    channel.setMethodCallHandler(this);
    context = flutterPluginBinding.getApplicationContext();
    mainHandler = new Handler(Looper.getMainLooper());

    // Initialize IJKPlayer
    IjkMediaPlayer.loadLibrariesOnce(null);
    IjkMediaPlayer.native_profileBegin("libijkplayer.so");
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch (call.method) {
      case "getPlatformVersion":
        result.success("Android " + android.os.Build.VERSION.RELEASE);
        break;
      case "setDataSource":
        String url = call.argument("url");
        setDataSource(url, result);
        break;
      case "start":
        start(result);
        break;
      case "pause":
        pause(result);
        break;
      case "stop":
        stop(result);
        break;
      case "reset":
        reset(result);
        break;
      case "dispose":
        dispose(result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private void setDataSource(String url, Result result) {
    try {
      if (mediaPlayer != null) {
        mediaPlayer.release();
      }

      mediaPlayer = new IjkMediaPlayer();

      // Set IJKPlayer options for audio playback
      mediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec", 0);
      mediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "opensles", 1);
      mediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "overlay-format", IjkMediaPlayer.SDL_FCC_RV32);
      mediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "framedrop", 1);
      mediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "start-on-prepared", 0);
      mediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "http-detect-range-support", 0);
      mediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_CODEC, "skip_loop_filter", 48);

      // Set listeners
      mediaPlayer.setOnPreparedListener(new IMediaPlayer.OnPreparedListener() {
        @Override
        public void onPrepared(IMediaPlayer iMediaPlayer) {
          // Player is ready
        }
      });

      mediaPlayer.setOnErrorListener(new IMediaPlayer.OnErrorListener() {
        @Override
        public boolean onError(IMediaPlayer iMediaPlayer, int what, int extra) {
          return false;
        }
      });

      mediaPlayer.setOnCompletionListener(new IMediaPlayer.OnCompletionListener() {
        @Override
        public void onCompletion(IMediaPlayer iMediaPlayer) {
          // Playback completed
        }
      });

      mediaPlayer.setDataSource(url);
      mediaPlayer.prepareAsync();

      result.success(null);
    } catch (Exception e) {
      result.error("SET_DATA_SOURCE_ERROR", e.getMessage(), null);
    }
  }

  private void start(Result result) {
    try {
      if (mediaPlayer != null) {
        mediaPlayer.start();
        result.success(null);
      } else {
        result.error("PLAYER_NOT_INITIALIZED", "Media player not initialized", null);
      }
    } catch (Exception e) {
      result.error("START_ERROR", e.getMessage(), null);
    }
  }

  private void pause(Result result) {
    try {
      if (mediaPlayer != null && mediaPlayer.isPlaying()) {
        mediaPlayer.pause();
        result.success(null);
      } else {
        result.error("PLAYER_NOT_PLAYING", "Media player is not playing", null);
      }
    } catch (Exception e) {
      result.error("PAUSE_ERROR", e.getMessage(), null);
    }
  }

  private void stop(Result result) {
    try {
      if (mediaPlayer != null) {
        mediaPlayer.stop();
        result.success(null);
      } else {
        result.error("PLAYER_NOT_INITIALIZED", "Media player not initialized", null);
      }
    } catch (Exception e) {
      result.error("STOP_ERROR", e.getMessage(), null);
    }
  }

  private void reset(Result result) {
    try {
      if (mediaPlayer != null) {
        mediaPlayer.reset();
        result.success(null);
      } else {
        result.error("PLAYER_NOT_INITIALIZED", "Media player not initialized", null);
      }
    } catch (Exception e) {
      result.error("RESET_ERROR", e.getMessage(), null);
    }
  }

  private void dispose(Result result) {
    try {
      if (mediaPlayer != null) {
        mediaPlayer.stop();
        mediaPlayer.release();
        mediaPlayer = null;
        result.success(null);
      } else {
        result.success(null); // Already disposed
      }
    } catch (Exception e) {
      result.error("DISPOSE_ERROR", e.getMessage(), null);
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);

    // Release media player resources
    if (mediaPlayer != null) {
      mediaPlayer.release();
      mediaPlayer = null;
    }

    IjkMediaPlayer.native_profileEnd();
  }
}
