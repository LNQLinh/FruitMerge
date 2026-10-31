import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Rewarded ad unit TEST chính thức của Google, dùng khi chạy debug để không
/// tự bấm nhầm vào quảng cáo thật (có thể bị khoá tài khoản AdMob).
const _testAndroidUnit = 'ca-app-pub-3940256099942544/5224354917';
const _testIosUnit = 'ca-app-pub-3940256099942544/1712485313';

/// Rewarded ad unit thật trên AdMob, chỉ dùng ở bản release.
const _releaseAndroidUnit = 'ca-app-pub-6858780985829486/9549979466';
const _releaseIosUnit = 'ca-app-pub-6858780985829486/9717500424';

/// Chọn ad unit theo nền tảng: debug/profile luôn dùng test, release dùng thật.
final _adUnitId = kReleaseMode
    ? (Platform.isAndroid ? _releaseAndroidUnit : _releaseIosUnit)
    : (Platform.isAndroid ? _testAndroidUnit : _testIosUnit);

/// Interstitial (quảng cáo xen kẽ toàn màn hình) TEST chính thức của Google.
const _testAndroidInterstitial = 'ca-app-pub-3940256099942544/1033173712';
const _testIosInterstitial = 'ca-app-pub-3940256099942544/4411468910';

// TODO: tạo ad unit "Quảng cáo xen kẽ" (Interstitial) thật trên AdMob cho
// Android và iOS rồi thay vào hai hằng số dưới đây trước khi phát hành.
const _releaseAndroidInterstitial = _testAndroidInterstitial;
const _releaseIosInterstitial = _testIosInterstitial;

final _interstitialUnitId = kReleaseMode
    ? (Platform.isAndroid
          ? _releaseAndroidInterstitial
          : _releaseIosInterstitial)
    : (Platform.isAndroid ? _testAndroidInterstitial : _testIosInterstitial);

/// Thời gian chờ trước khi thử tải lại khi tải quảng cáo thất bại.
const _retryDelay = Duration(seconds: 30);

/// Quản lý quảng cáo của game: xin đồng ý quảng cáo (GDPR), khởi tạo SDK,
/// luôn tải sẵn một quảng cáo có thưởng (xem để nhận trợ giúp/coin) và một
/// quảng cáo xen kẽ (chiếu trước khi chơi lại).
class GameAds {
  /// Đã có quảng cáo tải xong, sẵn sàng hiển thị.
  final isReady = ValueNotifier<bool>(false);

  RewardedAd? _ad;
  InterstitialAd? _interstitial;
  bool _started = false;

  /// Hỏi ý kiến người dùng về quảng cáo (form chỉ hiện ở nơi luật yêu cầu,
  /// như châu Âu), sau đó khởi tạo SDK và tải quảng cáo đầu tiên.
  void init() {
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((error) {
        if (error != null) debugPrint('Consent form error: ${error.message}');
        _start();
      }),
      // Lỗi cập nhật thông tin đồng ý (thường do mạng): vẫn thử dùng trạng thái
      // đã lưu từ lần trước.
      (error) {
        debugPrint('Consent info update failed: ${error.message}');
        _start();
      },
    );
  }

  /// Khởi tạo SDK một lần duy nhất, chỉ khi đã được phép xin quảng cáo.
  /// Chưa được phép (ví dụ lần đầu mở app mà mạng lỗi nên chưa kiểm tra được
  /// GDPR) thì đợi một lúc rồi kiểm tra lại, thay vì tắt quảng cáo cả phiên.
  Future<void> _start() async {
    if (_started) return;
    if (!await ConsentInformation.instance.canRequestAds()) {
      debugPrint('Cannot request ads yet, retrying consent check later');
      Timer(_retryDelay, init);
      return;
    }
    _started = true;
    await _requestTracking();
    await MobileAds.instance.initialize();
    _load();
    _loadInterstitial();
  }

  /// iOS: hiện popup ATT xin phép theo dõi để quảng cáo được cá nhân hoá.
  /// Chỉ hỏi một lần (khi chưa quyết định); từ chối thì quảng cáo vẫn chạy
  /// nhưng không cá nhân hoá.
  Future<void> _requestTracking() async {
    if (!Platform.isIOS) return;
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status != TrackingStatus.notDetermined) return;
    // iOS bỏ qua yêu cầu nếu app chưa thực sự hiện lên màn hình.
    await _waitUntilActive();
    await AppTrackingTransparency.requestTrackingAuthorization();
  }

  /// Chờ tới khi app ở trạng thái đang hoạt động (resumed).
  Future<void> _waitUntilActive() async {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      return;
    }
    final active = Completer<void>();
    final listener = AppLifecycleListener(
      onResume: () {
        if (!active.isCompleted) active.complete();
      },
    );
    await active.future;
    listener.dispose();
  }

  /// Tải trước một quảng cáo; thất bại thì đợi một lúc rồi thử lại.
  void _load() {
    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          isReady.value = true;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad failed to load: $error');
          Timer(_retryDelay, _load);
        },
      ),
    );
  }

  /// Tải trước một quảng cáo xen kẽ; thất bại thì đợi một lúc rồi thử lại.
  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial ad failed to load: $error');
          Timer(_retryDelay, _loadInterstitial);
        },
      ),
    );
  }

  /// Chiếu quảng cáo xen kẽ rồi gọi [onDone] khi người chơi đóng nó. Chưa có
  /// quảng cáo sẵn thì gọi [onDone] ngay, để không bắt người chơi phải chờ.
  void showInterstitial(VoidCallback onDone) {
    final ad = _interstitial;
    if (ad == null) {
      onDone();
      return;
    }
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        onDone();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        onDone();
        _loadInterstitial();
      },
    );
    ad.show();
  }

  /// Hiển thị quảng cáo đã tải sẵn. [onReward] chỉ được gọi khi người chơi
  /// xem đủ để nhận thưởng; [onClosed] luôn được gọi khi quảng cáo đóng lại
  /// (kể cả khi lỗi không hiển thị được). Xong thì tải sẵn quảng cáo kế tiếp.
  void show({required VoidCallback onReward, required VoidCallback onClosed}) {
    final ad = _ad;
    if (ad == null) return;
    _ad = null;
    isReady.value = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        onClosed();
        _load();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        onClosed();
        _load();
      },
    );
    ad.show(onUserEarnedReward: (_, _) => onReward());
  }
}
