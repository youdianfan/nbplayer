# NBPlayer - 基于 IJKPlayer 的 Flutter 音频播放插件

NBPlayer 是一个基于 ijkplayer 的 Flutter 音频播放插件，专为音频播放而设计，提供了完整的播放控制功能。

## 功能特性

- ✅ 支持 HTTP/HTTPS 音频流播放
- ✅ 完整的播放器状态管理
- ✅ 支持 setDataSource, prepareAsync, start, pause, stop, reset, release 方法
- ✅ 基于 ijkplayer 的高性能音频解码
- ✅ V2 插件架构，支持 null-safety
- ✅ 多播放器实例支持

## 参考实现要点摘要

基于 `ijk/fijkplayer` 和 `ijk/lib` 的实现：

- **Channel 名称**: `com.newsbang.nbplayer/methods_{playerId}` (方法调用)
- **核心方法**: setDataSource, prepareAsync, start, pause, stop, reset, release  
- **状态机**: idle(0) → initialized(1) → asyncPreparing(2) → prepared(3) → started(4)/paused(5)/completed(6)/stopped(7)/error(8)/end(9)
- **事件处理**: 通过 EventChannel 接收播放状态变化、错误等事件
- **依赖**: 使用 IjkMediaPlayer 作为底层音频播放引擎

## 安装

在 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  nbplayer: ^0.0.1
```

## 快速开始

### 基本用法

```dart
import 'package:nbplayer/nbplayer.dart';

// 创建播放器实例
final player = Nbplayer();

// 监听状态变化
player.addListener(() {
  print('播放器状态: ${player.state}');
});

// 设置音频数据源
await player.setDataSource('https://example.com/audio.mp3');

// 开始播放（会自动调用 prepareAsync）
await player.start();

// 暂停播放
await player.pause();

// 停止播放
await player.stop();

// 重置播放器
await player.reset();

// 释放资源
await player.release();
```

### 分步播放控制

```dart
// 1. 设置数据源
await player.setDataSource('https://example.com/audio.mp3');

// 2. 异步准备
await player.prepareAsync();

// 3. 开始播放
await player.start();
```

## API 文档

### 播放器状态

```dart
enum NbPlayerState {
  idle,           // 空闲状态
  initialized,    // 已初始化
  asyncPreparing, // 异步准备中  
  prepared,       // 准备完成
  started,        // 播放中
  paused,         // 暂停
  completed,      // 播放完成
  stopped,        // 停止
  error,          // 错误
  end             // 结束/释放
}
```

### 核心方法

#### `setDataSource(String url, {Map<String, String>? headers})`
设置音频数据源。

- `url`: 音频文件的 HTTP/HTTPS URL
- `headers`: 可选的 HTTP 请求头

#### `prepareAsync()`
异步准备播放器。必须在 `initialized` 状态下调用。

#### `start()`
开始播放。如果在 `initialized` 状态下调用，会自动执行 `prepareAsync` 并开始播放。

#### `pause()`
暂停播放。只能在可播放状态下调用。

#### `stop()`
停止播放并进入 `stopped` 状态。

#### `reset()`
重置播放器到 `idle` 状态，清除数据源。

#### `release()`
释放播放器资源，进入 `end` 状态。调用后播放器不可再使用。

### 属性

- `state`: 当前播放器状态
- `playerId`: 播放器唯一标识符
- `dataSource`: 当前数据源 URL
- `disposed`: 是否已释放

## 依赖配置

### Android 配置

插件已包含 ijkplayer 依赖 (`ijkplayer-cmake-release.aar`)，并自动配置以下权限：

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

### 依赖放置位置

- **ijkplayer AAR**: `android/libs/ijkplayer-cmake-release.aar`
- **原生 .so 库**: 已打包在 AAR 中
- **Java 实现**: `android/src/main/java/com/nbplayer/nbplayer/NbplayerPlugin.java`

## 示例应用

运行示例应用：

```bash
cd example
flutter run -d android
```

示例应用包含：
- 完整的播放器控制界面
- 六个核心方法按钮
- 实时状态显示
- 执行日志输出

## 测试音频 URL

可以使用以下测试 URL：

```
https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3
https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3
```

## 状态转换图

```
idle ──setDataSource──> initialized ──prepareAsync/start──> asyncPreparing
                            │                                      │
                            └──────start──────────────────────────┘
                                                                   │
                                                                   ▼
   ┌─────pause────► paused ◄──start──┐                         prepared
   │                                  │                            │
   ▼                                  │                            ▼
started ──────────────────────────────┼──────stop──────────────► stopped
   │                                  │                            │
   └──────────────stop────────────────┘                            │
   │                                                               │
   └─────────────────completion────────► completed                │
                                             │                     │
                                             └──start──────────────┘
                                                                   │
                     ┌─────────────reset──────────────────────────┘
                     │
                     ▼
                   idle
                     │
                  release
                     │
                     ▼
                   end
```

## 与参考实现差异点

1. **Channel 命名**: 使用 `com.newsbang.nbplayer` 前缀替代原 `befovy.com/fijkplayer`
2. **多播放器支持**: 通过全局 channel 管理播放器实例创建和释放
3. **简化 API**: 专注于音频播放，移除视频相关功能
4. **状态管理**: 优化状态转换逻辑，确保线程安全

## 故障排除

### 常见问题

1. **播放失败**: 检查 URL 是否可访问，确保有网络权限
2. **状态异常**: 按照状态转换图调用方法
3. **内存泄漏**: 确保调用 `release()` 释放资源

### 调试方法

启用详细日志查看播放器状态变化和错误信息。

## 许可证

MIT License

## 版本历史

- **0.0.1**: 初始版本，基于 ijkplayer 的音频播放功能
