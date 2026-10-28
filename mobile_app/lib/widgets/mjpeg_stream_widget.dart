import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MjpegStreamWidget extends StatefulWidget {
  final String streamUrl;
  final double height;
  final String fallbackSubtitle;

  const MjpegStreamWidget({
    super.key,
    required this.streamUrl,
    this.height = 220,
    this.fallbackSubtitle = 'Detection status is shown above',
  });

  @override
  State<MjpegStreamWidget> createState() => _MjpegStreamWidgetState();
}

class _MjpegStreamWidgetState extends State<MjpegStreamWidget> {
  Uint8List? _currentFrame;
  bool _isLoading = true;
  bool _hasError = false;
  http.Client? _client;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void didUpdateWidget(covariant MjpegStreamWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      _stopStream();
      _startStream();
    }
  }

  void _startStream() {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      _client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.streamUrl));
      
      _client!.send(request).then((response) {
        if (response.statusCode != 200) {
          if (mounted) setState(() => _hasError = true);
          return;
        }

        final List<int> buffer = [];
        _subscription = response.stream.listen(
          (data) {
            buffer.addAll(data);

            // Find JPEG SOI (0xFF, 0xD8) and EOI (0xFF, 0xD9)
            int startIndex = -1;
            for (int i = 0; i < buffer.length - 1; i++) {
              if (buffer[i] == 0xFF && buffer[i + 1] == 0xD8) {
                startIndex = i;
                break;
              }
            }

            if (startIndex != -1) {
              int endIndex = -1;
              for (int i = startIndex + 2; i < buffer.length - 1; i++) {
                if (buffer[i] == 0xFF && buffer[i + 1] == 0xD9) {
                  endIndex = i + 2;
                  break;
                }
              }

              if (endIndex != -1) {
                final frameBytes = Uint8List.fromList(buffer.sublist(startIndex, endIndex));
                buffer.removeRange(0, endIndex);

                if (mounted) {
                  setState(() {
                    _currentFrame = frameBytes;
                    _isLoading = false;
                    _hasError = false;
                  });
                }
              }
            }

            // Prevent memory buildup if corrupted
            if (buffer.length > 500000) {
              buffer.clear();
            }
          },
          onError: (e) {
            if (mounted) {
              setState(() {
                _hasError = true;
                _isLoading = false;
              });
            }
          },
          cancelOnError: true,
        );
      }).catchError((e) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  void _stopStream() {
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
    _reconnectTimer?.cancel();
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: double.infinity,
      color: Colors.black,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_currentFrame != null && !_hasError) {
      return Image.memory(
        _currentFrame!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    }

    if (_isLoading && !_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Connecting to camera feed...',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return _buildFallback();
  }

  Widget _buildFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.videocam_off_outlined,
              size: 40,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 10),
            const Text(
              'Camera feed not connected',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.fallbackSubtitle,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 32,
              child: OutlinedButton(
                onPressed: _startStream,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF475569)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'Retry Connection',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
