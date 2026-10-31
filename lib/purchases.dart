import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'game/game_feedback.dart';
import 'game/player_progress.dart';

/// Mã sản phẩm, phải trùng với mã tạo trên App Store Connect và Google Play
/// Console. Bỏ quảng cáo vĩnh viễn là loại Non-consumable (mua một lần, khôi
/// phục được); gói 24h là loại Consumable (mua lại được nhiều lần).
const noAdsForeverId = 'no_ads_forever';
const noAdsPassId = 'no_ads_24h';

/// Quản lý mua hàng trong app qua Apple In-App Purchase / Google Play
/// Billing cho hai gói bỏ quảng cáo. Tiền do Apple/Google thu; app chỉ nhận
/// kết quả giao dịch rồi kích hoạt quyền lợi trong [PlayerProgress].
class Purchases {
  Purchases(this.progress);

  final PlayerProgress progress;

  /// Thông tin các gói lấy từ store (đã kèm giá theo tiền địa phương). Rỗng
  /// khi store chưa sẵn sàng hoặc chưa tạo sản phẩm.
  final products = ValueNotifier<Map<String, ProductDetails>>(const {});

  /// Đang chờ store xử lý một giao dịch.
  final busy = ValueNotifier<bool>(false);

  /// Lỗi gần nhất để hiển thị cho người chơi (null nếu không có).
  final error = ValueNotifier<String?>(null);

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Nghe kết quả giao dịch ngay khi mở app (để không bỏ sót giao dịch còn dở
  /// từ lần trước) và tải thông tin, giá của các gói. Store lỗi thì chỉ ghi
  /// log; popup sẽ hiện "store chưa sẵn sàng" thay vì làm hỏng game.
  Future<void> init() async {
    try {
      await _init();
    } catch (e) {
      debugPrint('Store is not available: $e');
    }
  }

  Future<void> _init() async {
    final store = InAppPurchase.instance;
    _subscription = store.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) {
        busy.value = false;
        error.value = 'Purchase failed';
      },
    );
    if (!await store.isAvailable()) return;
    final response = await store.queryProductDetails({
      noAdsForeverId,
      noAdsPassId,
    });
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Store products not found: ${response.notFoundIDs}');
    }
    products.value = {for (final p in response.productDetails) p.id: p};
  }

  void dispose() => _subscription?.cancel();

  /// Mở màn hình thanh toán của store cho gói [id].
  Future<void> buy(String id) async {
    final product = products.value[id];
    if (product == null || busy.value) return;
    error.value = null;
    busy.value = true;
    final param = PurchaseParam(productDetails: product);
    try {
      if (id == noAdsPassId) {
        await InAppPurchase.instance.buyConsumable(purchaseParam: param);
      } else {
        await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
      }
    } catch (e) {
      debugPrint('Purchase could not start: $e');
      busy.value = false;
      error.value = 'Purchase failed';
    }
  }

  /// Khôi phục gói vĩnh viễn đã mua (khi đổi máy hoặc cài lại app). Apple bắt
  /// buộc app phải có chức năng này.
  Future<void> restore() async {
    error.value = null;
    await InAppPurchase.instance.restorePurchases();
  }

  /// Xử lý kết quả giao dịch từ store: kích hoạt quyền lợi khi mua/khôi phục
  /// thành công, báo lỗi khi thất bại, và luôn báo store là đã xử lý xong để
  /// giao dịch không bị hoàn tiền tự động.
  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          busy.value = true;
        case PurchaseStatus.purchased:
          _deliver(p.productID);
          GameFeedback.reward();
          busy.value = false;
        case PurchaseStatus.restored:
          // Chỉ gói vĩnh viễn được khôi phục; gói 24h đã dùng thì thôi.
          if (p.productID == noAdsForeverId) progress.grantNoAdsForever();
          busy.value = false;
        case PurchaseStatus.error:
          busy.value = false;
          error.value = p.error?.message ?? 'Purchase failed';
        case PurchaseStatus.canceled:
          busy.value = false;
      }
      if (p.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(p);
      }
    }
  }

  /// Kích hoạt quyền lợi của gói [id] vừa mua.
  void _deliver(String id) {
    if (id == noAdsForeverId) {
      progress.grantNoAdsForever();
    } else if (id == noAdsPassId) {
      progress.grantNoAdsPass();
    }
  }
}
