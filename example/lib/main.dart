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
  String _status = 'Ready';
  final _nbplayerPlugin = Nbplayer();
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initPlatformState();
    // 设置一个默认的音频URL用于测试
    _urlController.text = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await _nbplayerPlugin.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  Future<void> _setDataSource() async {
    try {
      await _nbplayerPlugin.setDataSource(_urlController.text);
      setState(() {
        _status = 'Data source set successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Error setting data source: $e';
      });
    }
  }

  Future<void> _start() async {
    try {
      await _nbplayerPlugin.start();
      setState(() {
        _status = 'Playing';
      });
    } catch (e) {
      setState(() {
        _status = 'Error starting playback: $e';
      });
    }
  }

  Future<void> _pause() async {
    try {
      await _nbplayerPlugin.pause();
      setState(() {
        _status = 'Paused';
      });
    } catch (e) {
      setState(() {
        _status = 'Error pausing playback: $e';
      });
    }
  }

  Future<void> _stop() async {
    try {
      await _nbplayerPlugin.stop();
      setState(() {
        _status = 'Stopped';
      });
    } catch (e) {
      setState(() {
        _status = 'Error stopping playback: $e';
      });
    }
  }

  Future<void> _reset() async {
    try {
      await _nbplayerPlugin.reset();
      setState(() {
        _status = 'Reset';
      });
    } catch (e) {
      setState(() {
        _status = 'Error resetting player: $e';
      });
    }
  }

  Future<void> _dispose() async {
    try {
      await _nbplayerPlugin.dispose();
      setState(() {
        _status = 'Player disposed';
      });
    } catch (e) {
      setState(() {
        _status = 'Error disposing player: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('NBPlayer Example'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Running on: $_platformVersion\n'),
              Text('Status: $_status\n'),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Audio URL',
                  hintText: 'Enter audio URL here',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _setDataSource,
                child: const Text('Set Data Source'),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _start,
                    child: const Text('Start'),
                  ),
                  ElevatedButton(
                    onPressed: _pause,
                    child: const Text('Pause'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _stop,
                    child: const Text('Stop'),
                  ),
                  ElevatedButton(
                    onPressed: _reset,
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _dispose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Dispose Player'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    // 在Widget销毁时也销毁播放器
    _nbplayerPlugin.dispose();
    super.dispose();
  }
}
