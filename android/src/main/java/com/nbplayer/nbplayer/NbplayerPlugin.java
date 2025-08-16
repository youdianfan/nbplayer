/*
 * 参考实现要点摘要 (基于 ijk/fijkplayer):
 * - Channel 名称: "com.newsbang.nbplayer/methods_{playerId}" (方法调用)
 * - 核心方法: setDataSource, prepareAsync, start, pause, stop, reset, release
 * - 状态机: idle(0) -> initialized(1) -> asyncPreparing(2) -> prepared(3) -> started(4)/paused(5)/completed(6)/stopped(7)/error(8)/end(9)
 * - 事件处理: 通过 EventChannel 发送播放状态变化、错误等事件
 * - 依赖: 使用 IjkMediaPlayer 作为底层音频播放引擎
 */

package com.nbplayer.nbplayer;

import androidx.annotation.NonNull;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.net.Uri;
import android.util.Log;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import tv.danmaku.ijk.media.player.IjkMediaPlayer;
import tv.danmaku.ijk.media.player.IMediaPlayer;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/** NbplayerPlugin */
public class NbplayerPlugin implements FlutterPlugin, MethodCallHandler {
    private static final String TAG = "NbplayerPlugin";

    // 状态常量 - 对应参考实现
    private static final int STATE_IDLE = 0;
    private static final int STATE_INITIALIZED = 1;
    private static final int STATE_ASYNC_PREPARING = 2;
    private static final int STATE_PREPARED = 3;
    private static final int STATE_STARTED = 4;
    private static final int STATE_PAUSED = 5;
    private static final int STATE_COMPLETED = 6;
    private static final int STATE_STOPPED = 7;
    private static final int STATE_ERROR = 8;
    private static final int STATE_END = 9;

    private Context context;
    private FlutterPluginBinding flutterPluginBinding;
    private MethodChannel globalChannel;
    private final Map<String, NbAudioPlayer> players = new ConcurrentHashMap<>();

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        this.context = flutterPluginBinding.getApplicationContext();
        this.flutterPluginBinding = flutterPluginBinding;

        // 创建全局 channel 用于播放器实例管理
        globalChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "com.newsbang.nbplayer/global");
        globalChannel.setMethodCallHandler(this);

        // Initialize IJKPlayer
        try {
            IjkMediaPlayer.loadLibrariesOnce(null);
            IjkMediaPlayer.native_profileBegin("libijkplayer.so");
            Log.i(TAG, "IJKPlayer libraries loaded successfully");
        } catch (Exception e) {
            Log.e(TAG, "Failed to load IJKPlayer libraries", e);
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        // Release all players
        for (NbAudioPlayer player : players.values()) {
            player.release();
        }
        players.clear();

        if (globalChannel != null) {
            globalChannel.setMethodCallHandler(null);
        }

        try {
            IjkMediaPlayer.native_profileEnd();
        } catch (Exception e) {
            Log.e(TAG, "Error ending IJKPlayer profile", e);
        }
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        try {
            switch (call.method) {
                case "createPlayer":
                    handleCreatePlayer(call, result);
                    break;
                case "releasePlayer":
                    handleReleasePlayer(call, result);
                    break;
                default:
                    result.notImplemented();
                    break;
            }
        } catch (Exception e) {
            Log.e(TAG, "Error handling global method call: " + call.method, e);
            result.error("GLOBAL_ERROR", e.getMessage(), null);
        }
    }

    private void handleCreatePlayer(@NonNull MethodCall call, @NonNull Result result) {
        String playerId = call.argument("playerId");
        if (playerId == null) {
            result.error("INVALID_ARGUMENT", "playerId cannot be null", null);
            return;
        }

        if (!players.containsKey(playerId)) {
            NbAudioPlayer player = new NbAudioPlayer(playerId, flutterPluginBinding);
            players.put(playerId, player);
            Log.i(TAG, "Created player: " + playerId);
        }
        result.success(null);
    }

    private void handleReleasePlayer(@NonNull MethodCall call, @NonNull Result result) {
        String playerId = call.argument("playerId");
        if (playerId == null) {
            result.error("INVALID_ARGUMENT", "playerId cannot be null", null);
            return;
        }

        NbAudioPlayer player = players.get(playerId);
        if (player != null) {
            player.release();
            Log.i(TAG, "Released player: " + playerId);
        }
        result.success(null);
    }

    // 内部音频播放器类
    private class NbAudioPlayer implements MethodCallHandler {
        private final String playerId;
        private final MethodChannel methodChannel;
        private final EventChannel eventChannel;
        private EventChannel.EventSink eventSink;

        private IjkMediaPlayer ijkMediaPlayer;
        private int currentState = STATE_IDLE;
        private final Handler mainHandler;

        public NbAudioPlayer(String playerId, FlutterPluginBinding binding) {
            this.playerId = playerId;
            this.mainHandler = new Handler(Looper.getMainLooper());

            // 创建 MethodChannel 和 EventChannel
            this.methodChannel = new MethodChannel(
                binding.getBinaryMessenger(),
                "com.newsbang.nbplayer/methods_" + playerId
            );
            this.eventChannel = new EventChannel(
                binding.getBinaryMessenger(),
                "com.newsbang.nbplayer/events_" + playerId
            );

            this.methodChannel.setMethodCallHandler(this);
            this.eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
                @Override
                public void onListen(Object arguments, EventChannel.EventSink events) {
                    eventSink = events;
                }

                @Override
                public void onCancel(Object arguments) {
                    eventSink = null;
                }
            });
        }

        @Override
        public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
            try {
                switch (call.method) {
                    case "getPlatformVersion":
                        result.success("Android " + android.os.Build.VERSION.RELEASE);
                        break;
                    case "setDataSource":
                        handleSetDataSource(call, result);
                        break;
                    case "prepareAsync":
                        handlePrepareAsync(result);
                        break;
                    case "start":
                        handleStart(result);
                        break;
                    case "startFromInitialized":
                        handleStartFromInitialized(result);
                        break;
                    case "pause":
                        handlePause(result);
                        break;
                    case "stop":
                        handleStop(result);
                        break;
                    case "reset":
                        handleReset(result);
                        break;
                    case "release":
                        handleRelease(result);
                        break;
                    default:
                        result.notImplemented();
                        break;
                }
            } catch (Exception e) {
                Log.e(TAG, "Error handling method call: " + call.method, e);
                result.error("NATIVE_ERROR", e.getMessage(), null);
            }
        }

        private void handleSetDataSource(@NonNull MethodCall call, @NonNull Result result) {
            if (currentState != STATE_IDLE && currentState != STATE_INITIALIZED) {
                result.error("INVALID_STATE", "setDataSource called in invalid state: " + currentState, null);
                return;
            }

            String url = call.argument("url");
            if (url == null || url.isEmpty()) {
                result.error("INVALID_ARGUMENT", "URL cannot be null or empty", null);
                return;
            }

            try {
                // 释放之前的播放器实例
                if (ijkMediaPlayer != null) {
                    ijkMediaPlayer.release();
                }

                // 创建新的播放器实例
                ijkMediaPlayer = new IjkMediaPlayer();
                setupIjkPlayerOptions();
                setupIjkPlayerListeners();

                // 设置数据源
                Uri uri = Uri.parse(url);
                ijkMediaPlayer.setDataSource(context, uri);

                updateState(STATE_INITIALIZED);
                result.success(null);

                Log.i(TAG, "Data source set successfully: " + url);
            } catch (Exception e) {
                Log.e(TAG, "Failed to set data source: " + url, e);
                updateState(STATE_ERROR);
                result.error("SET_DATA_SOURCE_ERROR", e.getMessage(), null);
            }
        }

        private void handlePrepareAsync(@NonNull Result result) {
            if (currentState != STATE_INITIALIZED) {
                result.error("INVALID_STATE", "prepareAsync called in invalid state: " + currentState, null);
                return;
            }

            try {
                updateState(STATE_ASYNC_PREPARING);
                ijkMediaPlayer.prepareAsync();
                result.success(null);
                Log.i(TAG, "prepareAsync called successfully");
            } catch (Exception e) {
                Log.e(TAG, "Failed to prepare async", e);
                updateState(STATE_ERROR);
                result.error("PREPARE_ERROR", e.getMessage(), null);
            }
        }

        private void handleStart(@NonNull Result result) {
            if (!isPlayableState(currentState)) {
                result.error("INVALID_STATE", "start called in invalid state: " + currentState, null);
                return;
            }

            try {
                ijkMediaPlayer.start();
                result.success(null);
                Log.i(TAG, "start called successfully");
            } catch (Exception e) {
                Log.e(TAG, "Failed to start", e);
                updateState(STATE_ERROR);
                result.error("START_ERROR", e.getMessage(), null);
            }
        }

        private void handleStartFromInitialized(@NonNull Result result) {
            if (currentState != STATE_INITIALIZED) {
                result.error("INVALID_STATE", "startFromInitialized called in invalid state: " + currentState, null);
                return;
            }

            try {
                // 设置自动开始播放选项
                ijkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "start-on-prepared", 1);
                updateState(STATE_ASYNC_PREPARING);
                ijkMediaPlayer.prepareAsync();
                result.success(null);
                Log.i(TAG, "startFromInitialized called successfully");
            } catch (Exception e) {
                Log.e(TAG, "Failed to startFromInitialized", e);
                updateState(STATE_ERROR);
                result.error("START_FROM_INITIALIZED_ERROR", e.getMessage(), null);
            }
        }

        private void handlePause(@NonNull Result result) {
            if (!isPlayableState(currentState)) {
                result.error("INVALID_STATE", "pause called in invalid state: " + currentState, null);
                return;
            }

            try {
                ijkMediaPlayer.pause();
                result.success(null);
                Log.i(TAG, "pause called successfully");
            } catch (Exception e) {
                Log.e(TAG, "Failed to pause", e);
                updateState(STATE_ERROR);
                result.error("PAUSE_ERROR", e.getMessage(), null);
            }
        }

        private void handleStop(@NonNull Result result) {
            if (currentState == STATE_IDLE || currentState == STATE_INITIALIZED || currentState == STATE_END) {
                result.error("INVALID_STATE", "stop called in invalid state: " + currentState, null);
                return;
            }

            try {
                ijkMediaPlayer.stop();
                updateState(STATE_STOPPED);
                result.success(null);
                Log.i(TAG, "stop called successfully");
            } catch (Exception e) {
                Log.e(TAG, "Failed to stop", e);
                updateState(STATE_ERROR);
                result.error("STOP_ERROR", e.getMessage(), null);
            }
        }

        private void handleReset(@NonNull Result result) {
            if (currentState == STATE_END) {
                result.error("INVALID_STATE", "reset called in invalid state: " + currentState, null);
                return;
            }

            try {
                if (ijkMediaPlayer != null) {
                    ijkMediaPlayer.reset();
                }
                updateState(STATE_IDLE);
                result.success(null);
                Log.i(TAG, "reset called successfully");
            } catch (Exception e) {
                Log.e(TAG, "Failed to reset", e);
                updateState(STATE_ERROR);
                result.error("RESET_ERROR", e.getMessage(), null);
            }
        }

        private void handleRelease(@NonNull Result result) {
            try {
                release();
                result.success(null);
                Log.i(TAG, "release called successfully");
            } catch (Exception e) {
                Log.e(TAG, "Failed to release", e);
                result.error("RELEASE_ERROR", e.getMessage(), null);
            }
        }

        private void setupIjkPlayerOptions() {
            // 音频播放相关选项
            ijkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec", 0);
            ijkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "opensles", 1);
            ijkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "start-on-prepared", 0);

            // 网络相关选项
            ijkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "http-detect-range-support", 0);
            ijkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "timeout", 30000000);
            ijkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "reconnect", 1);

            // 解码相关选项
            ijkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_CODEC, "skip_loop_filter", 48);
        }

        private void setupIjkPlayerListeners() {
            ijkMediaPlayer.setOnPreparedListener(new IMediaPlayer.OnPreparedListener() {
                @Override
                public void onPrepared(IMediaPlayer iMediaPlayer) {
                    Log.i(TAG, "onPrepared");
                    updateState(STATE_PREPARED);
                }
            });

            ijkMediaPlayer.setOnCompletionListener(new IMediaPlayer.OnCompletionListener() {
                @Override
                public void onCompletion(IMediaPlayer iMediaPlayer) {
                    Log.i(TAG, "onCompletion");
                    updateState(STATE_COMPLETED);
                }
            });

            ijkMediaPlayer.setOnErrorListener(new IMediaPlayer.OnErrorListener() {
                @Override
                public boolean onError(IMediaPlayer iMediaPlayer, int what, int extra) {
                    Log.e(TAG, "onError: what=" + what + ", extra=" + extra);
                    updateState(STATE_ERROR);
                    return true;
                }
            });

            ijkMediaPlayer.setOnInfoListener(new IMediaPlayer.OnInfoListener() {
                @Override
                public boolean onInfo(IMediaPlayer iMediaPlayer, int what, int extra) {
                    switch (what) {
                        case IMediaPlayer.MEDIA_INFO_VIDEO_RENDERING_START:
                        case IMediaPlayer.MEDIA_INFO_AUDIO_RENDERING_START:
                            if (currentState == STATE_ASYNC_PREPARING || currentState == STATE_PREPARED) {
                                updateState(STATE_STARTED);
                            }
                            break;
                    }
                    return false;
                }
            });

            ijkMediaPlayer.setOnSeekCompleteListener(new IMediaPlayer.OnSeekCompleteListener() {
                @Override
                public void onSeekComplete(IMediaPlayer iMediaPlayer) {
                    Log.i(TAG, "onSeekComplete");
                }
            });
        }

        private void updateState(int newState) {
            if (currentState != newState) {
                int oldState = currentState;
                currentState = newState;
                sendStateChangeEvent(newState, oldState);
                Log.i(TAG, "State changed: " + oldState + " -> " + newState);
            }
        }

        private void sendStateChangeEvent(int newState, int oldState) {
            if (eventSink != null) {
                Map<String, Object> event = new HashMap<>();
                event.put("event", "state_change");
                event.put("state", newState);
                event.put("oldState", oldState);

                mainHandler.post(() -> {
                    if (eventSink != null) {
                        eventSink.success(event);
                    }
                });
            }
        }

        private boolean isPlayableState(int state) {
            return state == STATE_PREPARED ||
                   state == STATE_STARTED ||
                   state == STATE_PAUSED ||
                   state == STATE_COMPLETED;
        }

        public void release() {
            updateState(STATE_END);

            if (ijkMediaPlayer != null) {
                try {
                    ijkMediaPlayer.release();
                } catch (Exception e) {
                    Log.e(TAG, "Error releasing media player", e);
                }
                ijkMediaPlayer = null;
            }

            if (methodChannel != null) {
                methodChannel.setMethodCallHandler(null);
            }

            if (eventChannel != null) {
                eventChannel.setStreamHandler(null);
            }

            eventSink = null;
            players.remove(playerId);
        }
    }
}
