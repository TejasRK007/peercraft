import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

import '../app_theme.dart';
import '../services/firestore_service.dart';

const String _agoraAppId = 'c10d85c17d4343258f2d525283456b30';

class VideoCallScreen extends StatefulWidget {
  final String channelName;
  final String peerName;
  final bool isTeacher;
  final String teacherUid;

  const VideoCallScreen({
    super.key,
    required this.channelName,
    required this.peerName,
    required this.teacherUid,
    this.isTeacher = false,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late RtcEngine _engine;
  bool _localUserJoined = false;
  int? _remoteUid;
  bool _muted = false;
  bool _cameraOff = false;
  bool _isInitializing = true;
  String _statusText = 'Connecting...';

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    // Request permissions
    await [Permission.camera, Permission.microphone].request();

    // Create engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(
      RtcEngineContext(
        appId: _agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    // Register event handlers
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          if (!mounted) return;
          setState(() {
            _localUserJoined = true;
            _isInitializing = false;
            _statusText = 'Waiting for ${widget.peerName}...';
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          if (!mounted) return;
          setState(() {
            _remoteUid = remoteUid;
            _statusText = 'Connected';
          });
        },
        onUserOffline:
            (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
            ) {
              if (!mounted) return;
              setState(() {
                _remoteUid = null;
                _statusText = '${widget.peerName} left the call';
              });
            },
        onError: (ErrorCodeType code, String msg) {
          if (!mounted) return;
          setState(() {
            _statusText = 'Error: $msg';
          });
        },
      ),
    );

    // Enable video
    await _engine.enableVideo();
    await _engine.startPreview();

    // Join channel (no token for testing — use token server for production)
    await _engine.joinChannel(
      token: '',
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  void _onToggleMute() {
    setState(() => _muted = !_muted);
    _engine.muteLocalAudioStream(_muted);
  }

  void _onToggleCamera() {
    setState(() => _cameraOff = !_cameraOff);
    _engine.muteLocalVideoStream(_cameraOff);
  }

  void _onSwitchCamera() {
    _engine.switchCamera();
  }

  Future<void> _onEndCall() async {
    // End the call locally
    try {
      await _engine.leaveChannel();
      await _engine.release();
    } catch (_) {}

    if (!mounted) return;

    if (widget.isTeacher) {
      final wantsToSend = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Session Ended',
            style: AppTheme.headingSmall.copyWith(fontSize: 20),
          ),
          content: Text(
            'Would you like to send PDF notes or materials to ${widget.peerName}?',
            style: AppTheme.subtitleStyle,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'No, thanks',
                style: AppTheme.labelStyle.copyWith(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Attach PDF',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );

      if (wantsToSend == true) {
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );

        if (result != null && result.files.isNotEmpty && mounted) {
          final fileName = result.files.first.name;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Notes "$fileName" sent to ${widget.peerName}!',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              backgroundColor: const Color(0xFF4CAF50),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } else {
      // Is Learner -> Show rating dialog
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          int rating = 0;
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  'Rate Your Session',
                  style: AppTheme.headingSmall.copyWith(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'How was your learning session with ${widget.peerName}?',
                      style: AppTheme.subtitleStyle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              rating = index + 1;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              index < rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: const Color(0xFFFFC857),
                              size: 40,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
                actionsAlignment: MainAxisAlignment.center,
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      'Skip',
                      style: AppTheme.labelStyle.copyWith(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: rating > 0
                        ? () async {
                            Navigator.of(ctx).pop();
                            
                            // Submit rating to Firestore
                            await FirestoreService.submitRating(widget.teacherUid, rating);

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Thank you for your feedback!',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                backgroundColor: AppTheme.primaryPurple,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      disabledBackgroundColor: AppTheme.primaryPurple.withAlpha(80),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Submit',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Remote video (full screen) ────────────────────────────
            _remoteUid != null
                ? AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: _engine,
                      canvas: VideoCanvas(uid: _remoteUid),
                      connection: RtcConnection(channelId: widget.channelName),
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isInitializing)
                          const CircularProgressIndicator(
                            color: AppTheme.primaryPurple,
                          ),
                        if (!_isInitializing)
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryPurple.withAlpha(40),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: AppTheme.primaryPurple,
                              size: 50,
                            ),
                          ),
                        const SizedBox(height: 20),
                        Text(
                          _statusText,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

            // ── Local video (small PiP) ───────────────────────────────
            if (_localUserJoined && !_cameraOff)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 120,
                    height: 160,
                    child: AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: _engine,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    ),
                  ),
                ),
              ),

            // ── Top bar ──────────────────────────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.peerName,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _remoteUid != null
                          ? Colors.green.withAlpha(40)
                          : Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _remoteUid != null ? '● Live' : _statusText,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _remoteUid != null
                            ? Colors.greenAccent
                            : Colors.white60,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Bottom controls ──────────────────────────────────────
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 32,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CallButton(
                    icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: _muted ? 'Unmute' : 'Mute',
                    color: _muted ? Colors.redAccent : Colors.white24,
                    onTap: _onToggleMute,
                  ),
                  _CallButton(
                    icon: _cameraOff
                        ? Icons.videocam_off_rounded
                        : Icons.videocam_rounded,
                    label: _cameraOff ? 'Camera On' : 'Camera Off',
                    color: _cameraOff ? Colors.redAccent : Colors.white24,
                    onTap: _onToggleCamera,
                  ),
                  _CallButton(
                    icon: Icons.cameraswitch_rounded,
                    label: 'Flip',
                    color: Colors.white24,
                    onTap: _onSwitchCamera,
                  ),
                  _CallButton(
                    icon: Icons.call_end_rounded,
                    label: 'End',
                    color: Colors.redAccent,
                    onTap: _onEndCall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
