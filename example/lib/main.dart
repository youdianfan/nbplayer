import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:nbplayer/nbplayer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _nbplayer = Nbplayer();
  final _urlController = TextEditingController();
  final _logController = ScrollController();
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    initPlatformState();
    setupPlayer();
    // 设置默认测试音频URL
    _urlController.text = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
  }

  @override
  void dispose() {
    _nbplayer.dispose();
    _urlController.dispose();
    _logController.dispose();
    super.dispose();
  }

  void setupPlayer() {
    // 监听播放器状态变化
    _nbplayer.addListener(() {
      _addLog('状态变化: ${_nbplayer.state.name}');
    });
  }

  Future<void> initPlatformState() async {
    String platformVersion;
    try {
      platformVersion = await _nbplayer.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
    _addLog('平台版本: $_platformVersion');
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
      if (_logs.length > 50) {
        _logs.removeAt(0);
      }
    });
    // 自动滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logController.hasClients) {
        _logController.animateTo(
          _logController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _setDataSource() async {
    try {
      final url = _urlController.text.trim();
      if (url.isEmpty) {
        _addLog('错误: URL 不能为空');
        return;
      }
      _addLog('设置数据源: $url');
      await _nbplayer.setDataSource(url);
      _addLog('✅ 数据源设置成功');
    } catch (e) {
      _addLog('❌ 设置数据源失败: $e');
    }
  }

  Future<void> _prepareAsync() async {
    try {
      _addLog('开始异步准备...');
      await _nbplayer.prepareAsync();
      _addLog('✅ 异步准备完成');
    } catch (e) {
      _addLog('❌ 异步准备失败: $e');
    }
  }

  Future<void> _start() async {
    try {
      _addLog('开始播放...');
      await _nbplayer.start();
      _addLog('✅ 播放开始');
    } catch (e) {
      _addLog('❌ 播放失败: $e');
    }
  }

  Future<void> _pause() async {
    try {
      _addLog('暂停播放...');
      await _nbplayer.pause();
      _addLog('✅ 播放暂停');
    } catch (e) {
      _addLog('❌ 暂停失败: $e');
    }
  }

  Future<void> _stop() async {
    try {
      _addLog('停止播放...');
      await _nbplayer.stop();
      _addLog('✅ 播放停止');
    } catch (e) {
      _addLog('❌ 停止失败: $e');
    }
  }

  Future<void> _reset() async {
    try {
      _addLog('重置播放器...');
      await _nbplayer.reset();
      _addLog('✅ 播放器重置成功');
    } catch (e) {
      _addLog('❌ 重置失败: $e');
    }
  }

  Future<void> _release() async {
    try {
      _addLog('释放播放器资源...');
      await _nbplayer.release();
      _addLog('✅ 播放器资源释放成功');
    } catch (e) {
      _addLog('❌ 释放失败: $e');
    }
  }

  Color _getStateColor() {
    switch (_nbplayer.state) {
      case NbPlayerState.idle:
        return Colors.grey;
      case NbPlayerState.initialized:
        return Colors.blue;
      case NbPlayerState.asyncPreparing:
        return Colors.orange;
      case NbPlayerState.prepared:
        return Colors.cyan;
      case NbPlayerState.started:
        return Colors.green;
      case NbPlayerState.paused:
        return Colors.yellow;
      case NbPlayerState.completed:
        return Colors.purple;
      case NbPlayerState.stopped:
        return Colors.red;
      case NbPlayerState.error:
        return Colors.redAccent;
      case NbPlayerState.end:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('NBPlayer 音频播放器测试'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // 状态显示
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('平台版本: $_platformVersion'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('播放器状态: '),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStateColor(),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _nbplayer.state.name.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('播放器ID: ${_nbplayer.playerId}'),
                      if (_nbplayer.dataSource != null)
                        Text('数据源: ${_nbplayer.dataSource}'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // URL 输入
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: '音频 URL',
                  hintText: '输入音频文件的 HTTPS URL',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),

              const SizedBox(height: 16),

              // 控制按钮
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: _setDataSource,
                    child: const Text('setDataSource'),
                  ),
                  ElevatedButton(
                    onPressed: _prepareAsync,
                    child: const Text('prepareAsync'),
                  ),
                  ElevatedButton(
                    onPressed: _start,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('start'),
                  ),
                  ElevatedButton(
                    onPressed: _pause,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text('pause'),
                  ),
                  ElevatedButton(
                    onPressed: _stop,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('stop'),
                  ),
                  ElevatedButton(
                    onPressed: _reset,
                    child: const Text('reset'),
                  ),
                  ElevatedButton(
                    onPressed: _release,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                    child: const Text('release'),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 日志显示
              Expanded(
                child: Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          '执行日志',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ListView.builder(
                            controller: _logController,
                            itemCount: _logs.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 1),
                                child: Text(
                                  _logs[index],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
