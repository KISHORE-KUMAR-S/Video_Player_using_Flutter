import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:auto_orientation/auto_orientation.dart';
import 'package:connectivity/connectivity.dart';

void main() => runApp(const MyApp());

enum VideoQuality { low, medium, high }

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: VideoPlayerScreen(),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({Key? key}) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  late StreamController<int> _streamController;
  bool _showControls = true;
  bool _isFullScreen = false;
  double _sliderValue = 0.0;
  Duration _lastPosition = Duration.zero;
  Timer? _controlsTimer;

  final Map<VideoQuality, String> videoQualityUrls = {
    VideoQuality.low:
    'https://sample-videos.com/video123/mp4/360/big_buck_bunny_360p_30mb.mp4',
    VideoQuality.medium:
    'https://sample-videos.com/video123/mp4/480/big_buck_bunny_480p_30mb.mp4',
    VideoQuality.high:
    'https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_10mb.mp4',
  };

  @override
  void initState() {
    super.initState();

    _streamController = StreamController<int>.broadcast();

    _videoPlayerController =
        VideoPlayerController.network(videoQualityUrls[VideoQuality.medium]!);

    _videoPlayerController.addListener(() {
      if (_videoPlayerController.value.isInitialized) {
        setState(() {
          _sliderValue =
              _videoPlayerController.value.position.inSeconds.toDouble();
        });
      }
    });


    _videoPlayerController.initialize().then((_) {
      setState(() {});
    });

    _videoPlayerController.setLooping(false);

    _controlsTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (_videoPlayerController.value.isPlaying) {
        if (mounted) {
          setState(() {
            _showControls = false;
          });
        }
      }
    });

    // Start monitoring internet connection
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile) {

        _checkConnectionType();
      }
    });
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _videoPlayerController.dispose();
    _streamController.close();
    AutoOrientation.portraitAutoMode();
    super.dispose();
  }

  Future<void> _checkConnectionType() async {
    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.wifi) {
        _changeVideoQuality(VideoQuality.high);
      }
      else if (connectivityResult == ConnectivityResult.mobile) {
        _changeVideoQuality(VideoQuality.medium);
      }
    }
    catch (e) {
      print('Error checking connection type: $e');
    }
  }

  void _changeVideoQuality(VideoQuality quality) async {
    // Show progress bar while changing video quality
    setState(() {
      _showControls = true;
    });

    String newUrl = videoQualityUrls[quality]!;
    _lastPosition = _videoPlayerController.value.position;

    _videoPlayerController.pause();

    _videoPlayerController = VideoPlayerController.network(newUrl);
    _videoPlayerController.addListener(() {
      if (_videoPlayerController.value.isInitialized) {
        setState(() {
          _sliderValue =
              _videoPlayerController.value.position.inSeconds.toDouble();
        });
      }
    });

    await _videoPlayerController.initialize();

    // Hide progress bar after changing video quality
    setState(() {
      _showControls = true;
    });

    _videoPlayerController.seekTo(_lastPosition);
    _videoPlayerController.play();

    _streamController.add(quality.index);
  }


  void _onSliderChanged(double value) {
    setState(() {
      _showControls = true;
      _sliderValue = value;
      _videoPlayerController.play();
    });
  }


  void _onSliderChangedEnd(double value) {
    Duration position = Duration(seconds: value.toInt());
    Duration bufferedEnd = _videoPlayerController.value.buffered.isNotEmpty
        ? _videoPlayerController.value.buffered.last.end
        : Duration.zero;

    if (position > bufferedEnd) {
      _seekToPosition(position);
    } else {
      setState(() {
        _showControls = true;
      });

      _seekToPosition(position);
      _videoPlayerController.play();
    }
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
      SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isFullScreen
          ? null
          : AppBar(
        title: Text('Video Player Example'),
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          return GestureDetector(
            onTap: () {
              setState(() {
                _showControls = !_showControls;
                if (_showControls) {
                  // Show controls for 30 seconds
                  Future.delayed(const Duration(seconds: 30), () {
                    if (mounted) {
                      setState(() {
                        _showControls = false;
                      });
                    }
                  });
                }
              });
            },
            child: Center(
              child: Stack(
                children: [
                  if (_videoPlayerController.value.isInitialized)
                    _isFullScreen
                        ? AspectRatio(
                      aspectRatio:
                      _videoPlayerController.value.aspectRatio,
                      child: VideoPlayer(_videoPlayerController),
                    )
                        : Container(
                      height:
                      MediaQuery.of(context).size.width * 9 / 16,
                      child: VideoPlayer(_videoPlayerController),
                      decoration: BoxDecoration(
                        color: Colors.black,
                      ),
                    ),
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: _showControls ? 0.5 : 0.0,
                      duration: Duration(milliseconds: 300),
                      child: Container(
                        color: Colors.black,
                        child: Center(
                          child: _videoPlayerController.value.isBuffering ? CircularProgressIndicator() : null,
                        ),
                      ),
                    ),
                  ),
                  if (_showControls &&
                      _videoPlayerController.value.isInitialized ||
                      _videoPlayerController.value.isBuffering)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Center(
                        child: Stack(
                          children: [
                            Positioned(
                              top: 0,
                              right: 0,
                              child: PopupMenuButton<VideoQuality>(
                                color: Colors.white,
                                onSelected: (quality) {
                                  _changeVideoQuality(quality);
                                },
                                itemBuilder: (BuildContext context) {
                                  return VideoQuality.values
                                      .map((quality) {
                                    return PopupMenuItem<VideoQuality>(
                                      value: quality,
                                      child: Text(
                                          quality.toString().split('.').last),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 40,
                              child: IconButton(
                                icon: Icon(
                                  _isFullScreen
                                      ? Icons.fullscreen_exit
                                      : Icons.fullscreen,
                                  color: Colors.white,
                                ),
                                onPressed: _toggleFullScreen,
                              ),
                            ),
                            Center(
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.fast_rewind_rounded),
                                    onPressed: _fastBackward,
                                    color: Colors.white,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.fast_forward_rounded),
                                    onPressed: _fastForward,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                            Center(
                              child: FloatingActionButton(
                                backgroundColor: Colors.transparent,
                                child: Icon(
                                  _videoPlayerController.value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow_rounded,
                                  size: 50,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _videoPlayerController.value.isPlaying
                                        ? _videoPlayerController.pause()
                                        : _videoPlayerController.play();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_showControls &&
                      _videoPlayerController.value.isInitialized &&
                      !_videoPlayerController.value.isBuffering)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding:
                                const EdgeInsets.fromLTRB(10, 0, 0, 0),
                                child: Text(
                                  '${formatDuration(_videoPlayerController.value.position)}',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              Padding(
                                padding:
                                const EdgeInsets.fromLTRB(0, 0, 10, 0),
                                child: Text(
                                  '${formatDuration(_videoPlayerController.value.duration)}',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: _sliderValue,
                            min: 0.0,
                            max: _videoPlayerController.value.duration
                                .inSeconds
                                .toDouble(),
                            onChanged: _onSliderChanged,
                            onChangeEnd: _onSliderChangedEnd,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _fastForward() {
    setState(() {
      _videoPlayerController.seekTo(
          Duration(seconds: _sliderValue.toInt() + 10));
    });
  }

  void _fastBackward() {
    setState(() {
      int newPosition = _sliderValue.toInt() - 10;
      if (newPosition < 0) {
        newPosition = 0;
      }
      _videoPlayerController.seekTo(Duration(seconds: newPosition));
    });
  }

  String formatDuration(Duration position) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');

    String hours = twoDigits(position.inHours);
    String minutes = twoDigits(position.inMinutes.remainder(60));
    String seconds = twoDigits(position.inSeconds.remainder(60));

    return '$hours:$minutes:$seconds';
  }

  void _seekToPosition(Duration position) {
    setState(() {
      _sliderValue = position.inSeconds.toDouble();
    });

    _videoPlayerController.seekTo(position);
  }
}
