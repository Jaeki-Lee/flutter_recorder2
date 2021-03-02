import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new Scaffold(
        body: SafeArea(
          child: new RecorderExample(),
        ),
      ),
    );
  }
}

class RecorderExample extends StatefulWidget {
  // final LocalFileSystem localFileSystem;

  // RecorderExample({localFileSystem})
  //     : this.localFileSystem = localFileSystem ?? LocalFileSystem();

  @override
  State<StatefulWidget> createState() => new RecorderExampleState();
}

class RecorderExampleState extends State<RecorderExample> {
  FlutterSoundPlayer _mPlayer = FlutterSoundPlayer();
  FlutterSoundRecorder _mRecorder = FlutterSoundRecorder();

  bool _mPlayerIsInited = false;
  bool _mRecorderIsInited = false;

  String _mPath;

  double _currentVolume = 0.0;
  double _currentPercent = 0.0;
  Duration _currentDuration = Duration();
  Duration _recordeDuration = Duration();
  bool _mplaybackReady = false;

  StreamSubscription _recorderSubscription;
  StreamSubscription _plyerSubscription;

  @override
  void initState() {
    openThePlayer().then((value) {
      setState(() {
        _mPlayerIsInited = true;
      });
    });

    openTheRecorder().then(
      (value) {
        setState(() {
          _mRecorderIsInited = true;
        });
      },
    );
    super.initState();
  }

  @override
  void dispose() {
    _mPlayer.closeAudioSession();
    _mPlayer = null;

    _mRecorder.closeAudioSession();
    _mRecorder = null;
    if (_mPath != null) {
      var outputFile = File(_mPath);
      if (outputFile.existsSync()) {
        outputFile.delete();
      }
    }

    _recorderSubscription.cancel();
    _plyerSubscription.cancel();

    super.dispose();
  }

  IconData _recorderIconData() {
    if (_mRecorder.isStopped) {
      return Icons.fiber_manual_record;
    } else {
      return Icons.stop;
    }
  }

  IconData _playerIconData() {
    if (_mPlayer.isStopped) {
      return Icons.play_arrow;
    } else {
      return Icons.stop;
    }
  }

  void _recordAction() async {
    if (_mRecorder.isStopped) {
      record();
      _tikTokForRecoder(300);
    } else {
      await stopRecord();
    }
  }

  void _playAction() async {
    if (_mPlayer.isStopped) {
      await _mPlayer.startPlayer(
        fromURI: _mPath,
        codec: Codec.aacADTS,
        whenFinished: () async {
          await stopPlayer();
        },
      );
      print("Play action Record duration ${_recordeDuration.inSeconds}");
      _tikTokForPlayer(_recordeDuration.inSeconds);
      _plyerSubscription = _mPlayer.onProgress.listen((event) {
        setState(() {
          print(event.position);
          // _currentDuration = event.duration;
          _currentDuration = event.position;
        });
      });
    } else {
      await stopPlayer();
    }
  }

  Future<void> stopPlayer() async {
    setState(() {
      _currentVolume = 0.0;
      _currentPercent = 0.0;
      _currentDuration = Duration();
      _mPlayerIsInited = false;
      _mRecorderIsInited = true;
    });
    await _mPlayer.stopPlayer();
  }

  Future<void> stopRecord() async {
    print("========Stop recorde called");
    setState(() {
      _currentVolume = 0.0;
      _currentPercent = 0.0;
      _recordeDuration = _currentDuration;
      _currentDuration = Duration();
      _mplaybackReady = true;
      _mRecorderIsInited = false;
      _mPlayerIsInited = true;
    });
    await stopRecorder();
    print("========Current percent value is $_currentPercent");
  }

  @override
  Widget build(BuildContext context) {
    print("========Rebuild app now Current percent value is $_currentPercent");
    return Scaffold(
      appBar: AppBar(
        title: Text("Voice message"),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 30,
                  child: RotatedBox(
                    quarterTurns: -1,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.grey,
                      value: _currentVolume,
                      // value: _convertAvgPowerToVolumeValue(_current.metering.averagePower),
                    ),
                  ),
                ),
                Stack(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: Padding(
                          padding: const EdgeInsets.all(30.0),
                          child: CircularProgressIndicator(
                            backgroundColor: Colors.grey,
                            value: _currentPercent,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      top: 0,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(70, 80, 70, 70),
                        child: InkWell(
                          child: Icon(
                            //초기 상태는 녹음 버튼
                            _mRecorderIsInited
                                ? _recorderIconData()
                                : _playerIconData(),
                            size: 60,
                            color: Colors.red,
                          ),
                          onTap: () async {
                            print(
                                "Before button tapped recoder status: ${_mRecorder.recorderState}");
                            //초기 상태에는 녹음을 시작한다.
                            if (_mRecorderIsInited) {
                              _recordAction();
                              // record();
                              // _tikTokForRecoder(300);
                              //녹음중 일때 클릭하면 녹음을 멈춘다.
                            } else {
                              _playAction();
                              //녹음이 멈추어진 상태에서 재생 버튼을 누르면 해당 파일을 재생한다
                            }
                          },
                        ),
                      ),
                    )
                  ],
                ),
              ],
            ),
            Text(
              _printDuration(_currentDuration),
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w300,
                color: Colors.black,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextButton(
                child: Text("Init"),
                onPressed: () {
                  // _init();
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> openThePlayer() async {
    await _mPlayer.openAudioSession();
    await _mPlayer.setSubscriptionDuration(Duration(milliseconds: 10));
  }

  Future<void> openTheRecorder() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }

    var tempDir = await getTemporaryDirectory();
    _mPath = '${tempDir.path}/flutter_sound_example.aac';
    var outputFile = File(_mPath);
    if (outputFile.existsSync()) {
      await outputFile.delete();
    }
    await _mRecorder.openAudioSession();
    await _mRecorder.setSubscriptionDuration(Duration(milliseconds: 10));
    // _mRecorderIsInited = true;
  }

  // ----------------------  Here is the code for recording and playback -------

  Future<void> record() async {
    print(_mRecorder.recorderState);
    assert(_mRecorderIsInited && _mPlayer.isStopped);
    await _mRecorder.startRecorder(
      toFile: _mPath,
      codec: Codec.aacADTS,
    );

    _recorderSubscription = _mRecorder.onProgress.listen((event) {
      // print(event.duration);
      // print(event.decibels);
      setState(() {
        _currentDuration = event.duration;
        _currentVolume = event.decibels / 120;
      });
    });

    //50miliseconds 셋팅2
    const tick = const Duration(microseconds: 50);
    //50miliseconds 마다 체크한다.
    new Timer.periodic(
      tick,
      (Timer t) async {
        //_currentStatus 가 RecordingStatus.Stopped 이면 멈춘다. 5분이 넘었다면 멈춘다.
        if (_mRecorder.isStopped) {
          t.cancel();
        }

        if (_currentDuration.inMinutes >= 5) {
          t.cancel();
          stopRecord();
        }
      },
    );

    print(_mRecorder.recorderState);
    setState(() {});
  }

  Future<void> stopRecorder() async {
    await _mRecorder.stopRecorder();
    _mplaybackReady = true;
  }

  void _tikTokForRecoder(int duratonSec) async {
    const tick = const Duration(seconds: 1);
    new Timer.periodic(tick, (Timer t) async {
      double max = 1.0;
      double count = 1 / duratonSec;
      print(t.tick);

      //flutterRecorder.isStopped 이면 progress bar 를 멈춘다.
      if (_currentPercent == max || _mRecorder.isStopped) {
        t.cancel();
      }

      if (_currentPercent < max && _mRecorder.isRecording) {
        setState(() {
          _currentPercent += count;
        });
      } else if (_currentPercent > max) {
        setState(() {
          _currentPercent = 1.0;
        });
      }
    });
  }

  void _tikTokForPlayer(int duratonSec) async {
    const tick = const Duration(seconds: 1);
    new Timer.periodic(
      tick,
      (Timer t) async {
        double max = 1.0;
        double count = 1 / duratonSec;
        print(t.tick);

        //flutterRecorder.isStopped 이면 progress bar 를 멈춘다.
        if (_currentPercent == max || _mPlayer.isStopped) {
          t.cancel();
        }

        if (_currentPercent < max && _mPlayer.isPlaying) {
          setState(() {
            _currentPercent += count;
          });
        } else if (_currentPercent > max) {
          setState(() {
            _currentPercent = 1.0;
          });
        }
      },
    );
  }

  String _printDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

}
