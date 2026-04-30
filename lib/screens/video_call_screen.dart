import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../app_theme.dart';
import '../services/firestore_service.dart';
import 'post_session_quiz_screen.dart';

// ─── Agora Credentials ────────────────────────────────────────────────────────
const String _agoraAppId = '50b48e839a6a4d4087b98674b68039ed';

// ─── Token Server (optional) ──────────────────────────────────────────────────
// If App Certificate is DISABLED in Agora Console: leave _tokenServerUrl = ''
// If App Certificate is ENABLED : host the open-source token server from
//   https://github.com/AgoraIO-Community/agora-token-service
//   and put its base URL here, e.g. 'https://your-server.com'
// The app will auto-fetch a fresh token before joining the channel.
const String _tokenServerUrl = ''; // ← set your token server URL here

/// Fetches a fresh RTC token from [_tokenServerUrl].
/// Returns '' (empty string) when no server is configured, which works when
/// App Certificate is disabled in the Agora Console.
Future<String> _fetchToken(String channelName, int uid) async {
  if (_tokenServerUrl.isEmpty) return ''; // no cert → no token needed
  try {
    final url = Uri.parse(
      '$_tokenServerUrl/rtc/$channelName/publisher/uid/$uid/?expiry=3600',
    );
    final resp = await http.get(url).timeout(const Duration(seconds: 8));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return (data['rtcToken'] as String?) ?? '';
    }
  } catch (e) {
    debugPrint('[VideoCall] Token fetch error: $e');
  }
  return '';
}

class VideoCallScreen extends StatefulWidget {
  final String channelName;
  final String peerName;
  final bool isTeacher;
  final String teacherUid;
  final String skill;

  const VideoCallScreen({
    super.key,
    required this.channelName,
    required this.peerName,
    required this.teacherUid,
    required this.skill,
    this.isTeacher = false,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  RtcEngine? _engine;
  bool _localUserJoined = false;
  int? _remoteUid;
  bool _muted = false;
  bool _cameraOff = false;

  // Lifecycle: 'init' | 'connecting' | 'waiting' | 'live' | 'error'
  String _phase = 'init';
  String _errorMessage = '';

  Timer? _connectTimeout;

  // ── Init ────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    if (!mounted) return;
    setState(() => _phase = 'init');

    try {
      // 1. Camera + mic permissions
      final statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      if (statuses[Permission.camera] != PermissionStatus.granted ||
          statuses[Permission.microphone] != PermissionStatus.granted) {
        _setError(
          'Camera or microphone permission denied.\n'
          'Please grant both permissions in Settings and try again.',
        );
        return;
      }

      // 2. Create & initialise engine
      setState(() => _phase = 'connecting');

      final engine = createAgoraRtcEngine();
      await engine.initialize(
        RtcEngineContext(
          appId: _agoraAppId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      _engine = engine;

      // 3. Register event handlers
      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            if (!mounted) return;
            _connectTimeout?.cancel();
            setState(() {
              _localUserJoined = true;
              _phase = 'waiting';
            });
          },
          onUserJoined:
              (RtcConnection connection, int remoteUid, int elapsed) {
            if (!mounted) return;
            setState(() {
              _remoteUid = remoteUid;
              _phase = 'live';
            });
          },
          onUserOffline: (
            RtcConnection connection,
            int remoteUid,
            UserOfflineReasonType reason,
          ) {
            if (!mounted) return;
            setState(() {
              _remoteUid = null;
              _phase = 'waiting';
            });
          },
          onError: (ErrorCodeType code, String msg) {
            if (!mounted) return;
            _connectTimeout?.cancel();

            // ERR_INVALID_TOKEN (101) or ERR_TOKEN_EXPIRED (109)
            final tokenError = code.index == 101 || code.index == 109;
            _setError(
              tokenError
                  ? 'Authentication error (${code.name}).\n'
                      'Agora requires a valid token when App Certificate is enabled.\n'
                      'Please set up a token server or disable App Certificate in the Agora Console.'
                  : 'Agora error: $msg (${code.name})',
            );
          },
        ),
      );

      // 4. Enable video & start local preview
      await engine.enableVideo();
      await engine.startPreview();

      // 5. Start a connection timeout (15 s)
      _connectTimeout = Timer(const Duration(seconds: 15), () {
        if (mounted && _phase == 'connecting') {
          _setError(
            'Connection timed out.\n'
            'Check your internet connection and Agora Console settings.\n'
            'If App Certificate is enabled, ensure _tokenServerUrl is set.',
          );
        }
      });

      // 6. Fetch token (empty if no token server configured)
      final token = await _fetchToken(widget.channelName, 0);

      // 7. Join channel
      await engine.joinChannel(
        token: token,
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
    } catch (e, st) {
      debugPrint('[VideoCall] initAgora error: $e\n$st');
      _connectTimeout?.cancel();
      _setError('Failed to start call: ${e.toString()}');
    }
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() {
      _phase = 'error';
      _errorMessage = msg;
    });
  }

  // ── Dispose ─────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _connectTimeout?.cancel();
    _releaseEngine();
    super.dispose();
  }

  Future<void> _releaseEngine() async {
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (_) {}
  }

  // ── Controls ─────────────────────────────────────────────────────────────────
  void _onToggleMute() {
    setState(() => _muted = !_muted);
    _engine?.muteLocalAudioStream(_muted);
  }

  void _onToggleCamera() {
    setState(() => _cameraOff = !_cameraOff);
    _engine?.muteLocalVideoStream(_cameraOff);
  }

  void _onSwitchCamera() => _engine?.switchCamera();

  Future<void> _onEndCall() async {
    _connectTimeout?.cancel();
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (_) {}

    if (!mounted) return;

    if (widget.isTeacher) {
      await _showTeacherEndDialog();
    } else {
      await _showRatingDialog();
    }

    if (!mounted) return;
    if (!widget.isTeacher) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PostSessionQuizScreen(
            skill: widget.skill,
            teacherUid: widget.teacherUid,
            teacherName: widget.peerName,
          ),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showTeacherEndDialog() async {
    final wantsToSend = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Session Ended',
            style: AppTheme.headingSmall.copyWith(fontSize: 20)),
        content: Text(
          'Would you like to send PDF notes or materials to ${widget.peerName}?',
          style: AppTheme.subtitleStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('No, thanks',
                style: AppTheme.labelStyle.copyWith(
                    color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Attach PDF',
                style: TextStyle(
                    fontFamily: 'Outfit',
                    color: Colors.white,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (wantsToSend == true && mounted) {
      final result = await FilePicker.pickFiles(
          type: FileType.custom, allowedExtensions: ['pdf']);
      if (result != null && result.files.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Notes "${result.files.first.name}" sent!',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  Future<void> _showRatingDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        int rating = 0;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text('Rate Your Session',
                  style: AppTheme.headingSmall.copyWith(fontSize: 20),
                  textAlign: TextAlign.center),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'How was your session with ${widget.peerName}?',
                    style: AppTheme.subtitleStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      return GestureDetector(
                        onTap: () => setDialogState(() => rating = i + 1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            i < rating
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
                  child: Text('Skip',
                      style: AppTheme.labelStyle.copyWith(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w700)),
                ),
                ElevatedButton(
                  onPressed: rating > 0
                      ? () async {
                          Navigator.of(ctx).pop();
                          await FirestoreService.submitRating(
                              widget.teacherUid, rating);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Text('Thank you for your feedback!',
                                style:
                                    TextStyle(fontWeight: FontWeight.w700)),
                            backgroundColor: AppTheme.primaryPurple,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ));
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    disabledBackgroundColor:
                        AppTheme.primaryPurple.withAlpha(80),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Submit',
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          color: Colors.white,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Full-screen content (remote / waiting / error) ────────
            _buildMainContent(),

            // ── Local PiP camera ──────────────────────────────────────
            if (_localUserJoined && !_cameraOff && _engine != null)
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
                        rtcEngine: _engine!,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    ),
                  ),
                ),
              ),

            // ── Top status bar ────────────────────────────────────────
            if (_phase != 'error')
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
                        shadows: [
                          Shadow(blurRadius: 8, color: Colors.black87)
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _phase == 'live'
                            ? Colors.green.withAlpha(50)
                            : Colors.white.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _phaseLabel(),
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _phase == 'live'
                              ? Colors.greenAccent
                              : Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Bottom controls ───────────────────────────────────────
            if (_phase != 'error')
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 32,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallButton(
                      icon: _muted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
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

  String _phaseLabel() {
    switch (_phase) {
      case 'init':
      case 'connecting':
        return 'Connecting...';
      case 'waiting':
        return 'Waiting for ${widget.peerName}...';
      case 'live':
        return '● Live';
      default:
        return '';
    }
  }

  Widget _buildMainContent() {
    // ── Error state ──────────────────────────────────────────────────────────
    if (_phase == 'error') {
      return _ErrorView(
        message: _errorMessage,
        onRetry: () {
          setState(() {
            _phase = 'init';
            _errorMessage = '';
            _localUserJoined = false;
            _remoteUid = null;
          });
          _initAgora();
        },
        onLeave: () => Navigator.of(context).pop(),
      );
    }

    // ── Remote video ─────────────────────────────────────────────────────────
    if (_remoteUid != null && _engine != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine!,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: widget.channelName),
        ),
      );
    }

    // ── Connecting / Waiting ─────────────────────────────────────────────────
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_phase == 'connecting' || _phase == 'init')
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                  color: AppTheme.primaryPurple, strokeWidth: 3),
            )
          else
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryPurple.withAlpha(40),
              ),
              child: const Icon(Icons.person_rounded,
                  color: AppTheme.primaryPurple, size: 50),
            ),
          const SizedBox(height: 20),
          Text(
            _phaseLabel(),
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error View
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onLeave;

  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF141414),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.redAccent.withAlpha(30),
            ),
            child: const Icon(Icons.videocam_off_rounded,
                color: Colors.redAccent, size: 38),
          ),
          const SizedBox(height: 24),
          const Text(
            'Call Failed',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              color: Colors.white60,
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onLeave,
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Go Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontFamily: 'Outfit', fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontFamily: 'Outfit', fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Call Control Button
// ─────────────────────────────────────────────────────────────────────────────
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
