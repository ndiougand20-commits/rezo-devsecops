part of 'auth_flow.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _videoController;
  String? _nextRoute;
  bool _videoReadyToExit = false;
  bool _didNavigate = false;
  bool _videoFailed = false;
  late final bool _useVideo;

  @override
  void initState() {
    super.initState();
    _useVideo = !kIsWeb;
    if (_useVideo) {
      _videoController = VideoPlayerController.asset(
        'assets/splashscreen/splashscreen.mp4',
      );
      unawaited(_prepareVideo());
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (mounted && !_videoReadyToExit) {
          setState(() => _videoFailed = true);
          _videoReadyToExit = true;
          _tryNavigate();
        }
      });
    } else {
      _videoFailed = true;
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && !_videoReadyToExit) {
          _videoReadyToExit = true;
          _tryNavigate();
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _prepareVideo() async {
    final controller = _videoController;
    if (controller == null) {
      return;
    }

    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(0);
      controller.addListener(_handleVideoProgress);
      await controller.play();
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      _videoFailed = true;
      _videoReadyToExit = true;
      _tryNavigate();
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _bootstrap() async {
    final appState = AppScope.of(context);
    final authenticated = await appState.restoreSession();
    _nextRoute = authenticated ? AppRoutes.dashboard : AppRoutes.roleChoice;
    _tryNavigate();
  }

  void _handleVideoProgress() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final position = controller.value.position;
    final duration = controller.value.duration;
    if (duration == Duration.zero || position < duration) {
      return;
    }

    _videoReadyToExit = true;
    controller.removeListener(_handleVideoProgress);
    _tryNavigate();
  }

  void _tryNavigate() {
    if (!mounted || _didNavigate || !_videoReadyToExit || _nextRoute == null) {
      return;
    }

    _didNavigate = true;
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacementNamed(_nextRoute!);
  }

  @override
  void dispose() {
    final controller = _videoController;
    if (controller != null) {
      controller.removeListener(_handleVideoProgress);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _videoController;
    final shouldShowVideo =
        _useVideo && controller != null && controller.value.isInitialized && !_videoFailed;

    return Scaffold(
      body: ColoredBox(
        color: Colors.black,
        child: shouldShowVideo
            ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const RezoLogo(height: 120, withBackground: false),
                    const SizedBox(height: 24),
                    const Text(
                      'REZO',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation(
                          Colors.white.withAlpha(180),
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
