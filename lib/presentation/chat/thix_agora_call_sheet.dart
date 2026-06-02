import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:thix_id/services/call_service.dart';
import 'package:thix_id/theme.dart';

class ThixAgoraCallSheet extends StatefulWidget {
  final String callId;
  final String otherUserId;
  final String kind;
  final bool isCaller;
  final CallService calls;

  const ThixAgoraCallSheet({
    super.key,
    required this.callId,
    required this.otherUserId,
    required this.kind,
    required this.isCaller,
    required this.calls,
  });

  @override
  State<ThixAgoraCallSheet> createState() => _ThixAgoraCallSheetState();
}

class _ThixAgoraCallSheetState extends State<ThixAgoraCallSheet> {
  late RtcEngine _engine;
  int? _remoteUid;
  bool _isJoined = false;
  bool _micOn = true;
  bool _camOn = true;
  bool _connected = false;
  bool _ending = false;
  DateTime? _startedAt;
  String _errorMsg = '';
  Timer? _connectionTimeout;

  bool get _isVideo => widget.kind == 'video';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _connectionTimeout?.cancel();
    _disposeEngine();
    super.dispose();
  }

  Future<void> _disposeEngine() async {
    try {
      await _engine.leaveChannel();
      _engine.release();
    } catch (e) {
      debugPrint('disposeEngine error: $e');
    }
  }

  Future<void> _init() async {
    try {
      if (!kIsWeb) {
        await Permission.microphone.request();
        if (_isVideo) await Permission.camera.request();
      }

      _engine = createAgoraRtcEngine();
      await _engine.initialize(const RtcEngineContext(
        appId: '96ed392d17c74fe684bbb9d4a031ad12',
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      _engine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          setState(() {
            _isJoined = true;
            _connected = true;
            _startedAt ??= DateTime.now();
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          _end(reason: 'user_left');
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('Agora Error: $err - $msg');
          if (mounted) _snack('Erreur Agora: $err');
        },
      ));

      await _engine.enableVideo();
      if (!_isVideo) {
        await _engine.enableLocalVideo(false);
      }

      await _engine.joinChannel(
        token: '',
        channelId: 'call_${widget.callId}',
        uid: 0,
        options: const ChannelMediaOptions(),
      );

      _connectionTimeout = Timer(const Duration(seconds: 15), () {
        if (!_connected && mounted) _end(reason: 'timeout');
      });
    } catch (e) {
      debugPrint('Agora init error: $e');
      if (mounted) _snack('Erreur initialisation appel');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _toggleMic() async {
    final enabled = !_micOn;
    await _engine.muteLocalAudioStream(!enabled);
    setState(() => _micOn = enabled);
  }

  Future<void> _toggleCam() async {
    if (!_isVideo) return;
    final enabled = !_camOn;
    await _engine.muteLocalVideoStream(!enabled);
    await _engine.enableLocalVideo(enabled);
    setState(() => _camOn = enabled);
  }

  Future<void> _end({required String reason}) async {
    if (_ending) return;
    setState(() => _ending = true);

    try {
      await widget.calls.completeCall(
        callId: widget.callId,
        startedAt: _startedAt ?? DateTime.now(),
        endedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('completeCall error: $e');
    }

    await _disposeEngine();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_isVideo ? 'Appel Vidéo' : 'Appel Audio', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text(_connected ? 'Connecté' : 'Connexion...', style: TextStyle(color: scheme.onSurface.withOpacity(0.6))),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => _end(reason: 'closed'), icon: const Icon(Icons.close)),
                ],
              ),
            ),

            // Video Area
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(16)),
                child: _isVideo && _remoteUid != null
                    ? Stack(
                        children: [
                          AgoraVideoView(
                            controller: VideoViewController(
                              rtcEngine: _engine,
                              canvas: VideoCanvas(uid: _remoteUid!),
                            ),
                          ),
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: SizedBox(
                              width: 100,
                              height: 140,
                              child: AgoraVideoView(
                                controller: VideoViewController(
                                  rtcEngine: _engine,
                                  canvas: const VideoCanvas(uid: 0),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Center(child: Icon(Icons.graphic_eq, size: 80, color: Colors.white70)),
              ),
            ),

            // Controls
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ControlButton(icon: _micOn ? Icons.mic : Icons.mic_off, label: _micOn ? 'Micro' : 'Muet', onTap: _toggleMic),
                  const SizedBox(width: 12),
                  if (_isVideo)
                    _ControlButton(icon: _camOn ? Icons.videocam : Icons.videocam_off, label: _camOn ? 'Cam' : 'Cam off', onTap: _toggleCam),
                  const SizedBox(width: 12),
                  _HangupButton(onTap: () => _end(reason: 'hangup')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widgets _ControlButton et _HangupButton (déjà dans ton fichier)
