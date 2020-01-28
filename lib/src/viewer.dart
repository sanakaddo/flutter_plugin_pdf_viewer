import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_plugin_pdf_viewer/flutter_plugin_pdf_viewer.dart';
import 'package:numberpicker/numberpicker.dart';
import 'tooltip.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';


enum IndicatorPosition { topLeft, topRight, bottomLeft, bottomRight }

class PDFViewer extends StatefulWidget {
  final PDFDocument document;
  final Color indicatorText;
  final Color indicatorBackground;
  final IndicatorPosition indicatorPosition;
  final bool showIndicator;
  final bool showPicker;
  final bool showNavigation;
  final PDFViewerTooltip tooltip;
  final Function(int) onPageChange;
  //final String audioUrl;
  final DocumentSnapshot book;
  List<DocumentSnapshot> audioFiles;
  Map<int, String> audioFilesMap;


  PDFViewer(
      {Key key,
      @required this.document,
        this.onPageChange,
      this.book,
       this.audioFiles,
        this.audioFilesMap,
      this.indicatorText = Colors.white,
      this.indicatorBackground = Colors.black54,
      this.showIndicator = true,
      this.showPicker = true,
      this.showNavigation = true,
      this.tooltip = const PDFViewerTooltip(),
      this.indicatorPosition = IndicatorPosition.topRight})
      : super(key: key);

  _PDFViewerState createState() => _PDFViewerState();
}


class _PDFViewerState extends State<PDFViewer> {
  bool _isLoading = true;
  int _pageNumber = 1;
  int _oldPage = 0;
  PDFPage _page;
  List<PDFPage> _pages = List();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _oldPage = 0;
    _pageNumber = 1;
    _isLoading = true;
    _pages.clear();
    _loadPage();
  }

  @override
  void didUpdateWidget(PDFViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _oldPage = 0;
    _pageNumber = 1;
    _isLoading = true;
    _pages.clear();
    _loadPage();
  }

  _loadPage() async {
    setState(() => _isLoading = true);
    if (_oldPage == 0) {
      _page = await widget.document.get(page: _pageNumber);
    } else if (_oldPage != _pageNumber) {
      _oldPage = _pageNumber;
      _page = await widget.document.get(page: _pageNumber);
    }
    if(this.mounted) {
      setState(() =>
        _isLoading = false
      );
      setState(() {
        widget.onPageChange(_pageNumber);
      });
    }

  }

  Widget _drawIndicator() {
    Widget child = GestureDetector(
        onTap: _pickPage,
        child: Container(
            padding:
                EdgeInsets.only(top: 4.0, left: 16.0, bottom: 4.0, right: 16.0),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4.0),
                color: widget.indicatorBackground),
            child: Text("$_pageNumber/${widget.document.count}",
                style: TextStyle(
                    color: widget.indicatorText,
                    fontSize: 16.0,
                    fontWeight: FontWeight.w400))));

    switch (widget.indicatorPosition) {
      case IndicatorPosition.topLeft:
        return Positioned(top: 20, left: 20, child: child);
      case IndicatorPosition.topRight:
        return Positioned(top: 20, right: 20, child: child);
      case IndicatorPosition.bottomLeft:
        return Positioned(bottom: 20, left: 20, child: child);
      case IndicatorPosition.bottomRight:
        return Positioned(bottom: 20, right: 20, child: child);
      default:
        return Positioned(top: 20, right: 20, child: child);
    }
  }

  _pickPage() {
    showDialog<int>(
        context: context,
        builder: (BuildContext context) {
          return NumberPickerDialog.integer(
            title: Text(widget.tooltip.pick),
            minValue: 1,
            cancelWidget: Container(),
            maxValue: widget.document.count,
            initialIntegerValue: _pageNumber,
          );
        }).then((int value) {
      if (value != null) {
        _pageNumber = value;
        _loadPage();
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          _isLoading ? Center(child: CircularProgressIndicator())
              : Column(
            children: <Widget>[
              _page,
              (widget.audioFilesMap.containsKey(_pageNumber)) ?
              PlayerWidget(url: widget.audioFilesMap[_pageNumber],)
                  : Center(child: Text('No Audio Available', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple))),
            ],
          ),

          (widget.showIndicator && !_isLoading)
              ? _drawIndicator()
              : Container(),
        ],
      ),
      floatingActionButton: widget.showPicker
          ? FloatingActionButton(
              elevation: 4.0,
              tooltip: widget.tooltip.jump,
              child: Icon(Icons.view_carousel),
              onPressed: () {
                _pickPage();
              },
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: (widget.showNavigation || widget.document.count > 1)
          ? BottomAppBar(
              child: new Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: IconButton(
                      icon: Icon(Icons.first_page),
                      tooltip: widget.tooltip.first,
                      onPressed: () {
                        _pageNumber = 1;
                        _loadPage();
                      },
                    ),
                  ),
                  Expanded(
                    child: IconButton(
                      icon: Icon(Icons.chevron_left),
                      tooltip: widget.tooltip.previous,
                      onPressed: () {
                        _pageNumber--;
                        if (1 > _pageNumber) {
                          _pageNumber = 1;
                        }
                        _loadPage();
                      },
                    ),
                  ),
                  widget.showPicker
                      ? Expanded(child: Text(''))
                      : SizedBox(width: 1),
                  Expanded(
                    child: IconButton(
                      icon: Icon(Icons.chevron_right),
                      tooltip: widget.tooltip.next,
                      onPressed: () {
                        _pageNumber++;
                        if (widget.document.count < _pageNumber) {
                          _pageNumber = widget.document.count;
                        }
                        _loadPage();
                      },
                    ),
                  ),
                  Expanded(
                    child: IconButton(
                      icon: Icon(Icons.last_page),
                      tooltip: widget.tooltip.last,
                      onPressed: () {
                        _pageNumber = widget.document.count;
                        _loadPage();
                      },
                    ),
                  ),
                ],
              ),
            )
          : Container(),
    );
  }
}

enum PlayerState { stopped, playing, paused }

class PlayerWidget extends StatefulWidget {

  final String url;
  //PlayerWidget({this.url});
  final PlayerMode mode;
  final number;

  PlayerWidget({@required this.url, this.number, this.mode = PlayerMode.MEDIA_PLAYER});

  @override
  State<StatefulWidget> createState() {
    return _PlayerWidgetState(url, mode);
  }
}

class _PlayerWidgetState extends State<PlayerWidget> {
  String url;
  PlayerMode mode;

  AudioPlayer _audioPlayer;
  AudioPlayerState _audioPlayerState;
  Duration _duration;
  Duration _position;

  PlayerState _playerState = PlayerState.stopped;
  StreamSubscription _durationSubscription;
  StreamSubscription _positionSubscription;
  StreamSubscription _playerCompleteSubscription;
  StreamSubscription _playerErrorSubscription;
  StreamSubscription _playerStateSubscription;

  get _isPlaying => _playerState == PlayerState.playing;
  get _isPaused => _playerState == PlayerState.paused;
  get _durationText => _duration?.toString()?.split('.')?.first ?? '';
  get _positionText => _position?.toString()?.split('.')?.first ?? '';

  _PlayerWidgetState(this.url, this.mode);

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerErrorSubscription?.cancel();
    _playerStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                onPressed: _isPlaying ? null : () => _play(),
                iconSize: 30.0,
                icon: Icon(Icons.play_arrow),
                color: Colors.cyan),
            IconButton(
                onPressed: _isPlaying ? () => _pause() : null,
                iconSize: 30.0,
                icon: Icon(Icons.pause),
                color: Colors.cyan),
            IconButton(
                onPressed: _isPlaying || _isPaused ? () => _stop() : null,
                iconSize: 30.0,
                icon: Icon(Icons.stop),
                color: Colors.cyan),
          ],
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(1.0),
              child: Stack(
                children: [
                  Slider(
                    onChanged: (v) {
                      final position = v * _duration.inMilliseconds;
                      _audioPlayer
                          .seek(Duration(milliseconds: position.round()));
                    },
                    value: (_position != null &&
                        _duration != null &&
                        _position.inMilliseconds > 0 &&
                        _position.inMilliseconds < _duration.inMilliseconds)
                        ? _position.inMilliseconds / _duration.inMilliseconds
                        : 0.0,
                  ),
                ],
              ),
            ),
            Text(
              _position != null
                  ? '${_positionText ?? ''} / ${_durationText ?? ''}'
                  : _duration != null ? _durationText : '',
              style: TextStyle(fontSize: 10.0),
            ),
          ],
        ),
        //Text("State: $_audioPlayerState")
      ],
    );
  }

  void _initAudioPlayer() {
    _audioPlayer = AudioPlayer(mode: mode);

    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      setState(() => _duration = duration);

      // TODO implemented for iOS, waiting for android impl
      if (Theme.of(context).platform == TargetPlatform.iOS) {
        // (Optional) listen for notification updates in the background
        _audioPlayer.startHeadlessService();

        // set at least title to see the notification bar on ios.
        _audioPlayer.setNotification(
            title: 'App Name',
            artist: 'Artist or blank',
            albumTitle: 'Name or blank',
            imageUrl: 'url or blank',
            forwardSkipInterval: const Duration(seconds: 30), // default is 30s
            backwardSkipInterval: const Duration(seconds: 30), // default is 30s
            duration: duration,
            elapsedTime: Duration(seconds: 0));
      }
    });

    _positionSubscription =
        _audioPlayer.onAudioPositionChanged.listen((p) => setState(() {
          _position = p;
        }));

    _playerCompleteSubscription =
        _audioPlayer.onPlayerCompletion.listen((event) {
          _onComplete();
          setState(() {
            _position = _duration;
          });
        });

    _playerErrorSubscription = _audioPlayer.onPlayerError.listen((msg) {
      print('audioPlayer error : $msg');
      setState(() {
        _playerState = PlayerState.stopped;
        _duration = Duration(seconds: 0);
        _position = Duration(seconds: 0);
      });
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _audioPlayerState = state;
      });
    });

    _audioPlayer.onNotificationPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _audioPlayerState = state);
    });
  }

  Future<int> _play() async {
    final playPosition = (_position != null &&
        _duration != null &&
        _position.inMilliseconds > 0 &&
        _position.inMilliseconds < _duration.inMilliseconds)
        ? _position
        : null;
    final result = await _audioPlayer.play(url, position: playPosition);
    if (result == 1) setState(() => _playerState = PlayerState.playing);

    // default playback rate is 1.0
    // this should be called after _audioPlayer.play() or _audioPlayer.resume()
    // this can also be called every time the user wants to change playback rate in the UI
    _audioPlayer.setPlaybackRate(playbackRate: 1.0);

    return result;
  }

  Future<int> _pause() async {
    final result = await _audioPlayer.pause();
    if (result == 1) setState(() => _playerState = PlayerState.paused);
    return result;
  }

  Future<int> _stop() async {
    final result = await _audioPlayer.stop();
    if (result == 1) {
      setState(() {
        _playerState = PlayerState.stopped;
        _position = Duration();
      });
    }
    return result;
  }

  void _onComplete() {
    setState(() => _playerState = PlayerState.stopped);
  }
}

