import 'package:meta/meta.dart';
import 'package:quiver_hashcode/hashcode.dart';

import 'helpers.dart';

/// Gateway used to make payments.
class PaymentGateway {
  /// Apple App Store
  static const PaymentGateway appStore = PaymentGateway._('appStore');

  /// Google Play Store
  static const PaymentGateway playStore = PaymentGateway._('playStore');

  /// Special gateway to provide "free" purchases.
  static const PaymentGateway free = PaymentGateway._('free');

  const PaymentGateway._(this.value);

  final String value;

  factory PaymentGateway.from(value) {
    if (value == free.value) return free;
    if (value == appStore.value) return appStore;
    if (value == playStore.value) return playStore;
    throw new ArgumentError.value(value, 'value', 'Invalid payment gateway.');
  }

  @override
  bool operator ==(other) {
    if (identical(this, other)) return true;
    if (other is! PaymentGateway) return false;
    PaymentGateway that = other;
    return this.value == that.value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
  String toJson() => value;
}

class PurchaseCredentials {
  final PaymentGateway gateway;
  final Map<String, Object> _data;

  PurchaseCredentials._(this.gateway, this._data);

  factory PurchaseCredentials.appStore(String transactionId, String receipt) {
    assert(transactionId != null);
    assert(receipt != null);
    return PurchaseCredentials._(PaymentGateway.appStore, {
      'transactionId': transactionId,
      'receipt': receipt,
    });
  }

  factory PurchaseCredentials.playStore(
      String productId, String packageName, String purchaseToken) {
    assert(productId != null);
    assert(packageName != null);
    assert(purchaseToken != null);
    return PurchaseCredentials._(PaymentGateway.playStore, {
      'productId': productId,
      'packageName': packageName,
      'purchaseToken': purchaseToken,
    });
  }

  Map<String, Object> toJson() {
    return {
      'gateway': gateway.value,
      'credentials': Map<String, Object>.from(_data),
    };
  }
}

/// Base interface for subscription purchases.
abstract class BasePurchase {
  /// The product identifier of the item that was purchased.
  String get productId;

  /// Whether user is eligible for free trial period.
  bool get isFreeTrialEligible;

  /// Whether or not subscription will auto renew at the end of
  /// current billing cycle.
  bool get willAutoRenew;

  /// Whether this subscription is currently in billing grace period.
  bool get isInGracePeriod;

  /// The expiration date for the purchase.
  DateTime get expiresAt;

  /// Whether this purchase expired.
  ///
  /// Returns `true` if [expiredAt] is in the past.
  ///
  /// Note that expired subscription may still be in grace period or just
  /// haven't been updated with latest purchase details from its gateway.
  ///
  /// Use [isEnded] to check if subscription is not in effect anymore.
  bool get isExpired {
    if (expiresAt == null) {
      // Expire time is not set which means it never expires.
      return false;
    }
    final now = DateTime.now().toUtc();
    return now.isAfter(expiresAt);
  }

  /// Whether subscription backed by this purchase has ended.
  ///
  /// Ended subscription will not renew, has [expiredAt] date in the past
  /// and is not in grace period.
  bool get isEnded {
    if (!isExpired) return false;
    if (isInGracePeriod) return false;
    if (willAutoRenew) return false;
    return true;
  }
}

/// Purchase that is given for free to the user.
///
/// Free purchases are provided by free payment gateway ([PaymentGateway.free])
/// and never expire.
///
/// Useful for providing free access to application functionality.
class FreePurchase extends BasePurchase {
  @override
  final String productId;

  @override
  final bool willAutoRenew = true;

  @override
  final bool isFreeTrialEligible = true;

  @override
  final DateTime expiresAt = null;

  @override
  final bool isInGracePeriod = false;

  FreePurchase({@required this.productId}) : assert(productId != null);

  factory FreePurchase.fromJson(Map<String, Object> data) {
    assert(data != null);
    return FreePurchase(productId: data['productId'] as String);
  }

  Map<String, Object> toJson() {
    return {'productId': productId};
  }

  @override
  bool operator ==(other) {
    if (identical(this, other)) return true;
    if (other is! FreePurchase) return false;
    final FreePurchase typedOther = other;
    return productId == typedOther.productId;
  }

  @override
  int get hashCode => productId.hashCode;

  @override
  String toString() => 'FreePurchase($productId)';
}

/// Purchase made using Apple AppStore gateway.
///
/// Holds details specific to AppStore purchase model.
class AppStorePurchase extends BasePurchase {
  /// The unique identifier of the item that was purchased.
  final String productId;

  /// The original transaction identifier.
  ///
  /// This serves as a unique identifier for this subscription.
  final String originalTransactionId;

  /// The date and time of the original transaction.
  ///
  /// Indicates the beginning of the subscription period, even if the
  /// subscription has been renewed.
  final DateTime originalPurchasedAt;

  @override
  final bool isFreeTrialEligible;

  @override
  final DateTime expiresAt;

  /// The time and date of the cancellation.
  ///
  /// Present for a transaction that was canceled by payment gateway customer
  /// support.
  ///
  /// Treat a canceled receipt the same as if no purchase had ever been made.
  final DateTime cancelledAt;

  /// For an expired subscription, the reason for the subscription expiration.
  ///
  /// You can use this value to decide whether to display appropriate
  /// messaging in your app for customers to resubscribe.
  final int expirationIntent;

  /// For an expired subscription, whether or not the AppStore is
  /// still attempting to automatically renew the subscription.
  final bool inBillingRetryPeriod;

  /// For a subscription, whether or not it is in the free trial period.
  final bool inFreeTrialPeriod;

  /// For a subscription, whether or not it will auto renew at the end of
  /// current billing cycle.
  /// `1` means auto-renew is turned on, `0` - it's turned off.
  final int autoRenewStatus;

  /// Latest encoded iOS receipt used to verify this purchase.
  final String receipt;

  AppStorePurchase({
    @required this.productId,
    @required this.originalTransactionId,
    @required this.originalPurchasedAt,
    @required this.isFreeTrialEligible,
    @required this.expiresAt,
    @required this.cancelledAt,
    @required this.expirationIntent,
    @required this.inBillingRetryPeriod,
    @required this.inFreeTrialPeriod,
    @required this.autoRenewStatus,
    @required this.receipt,
  });

  factory AppStorePurchase.fromJson(Map<String, Object> data) {
    assert(data != null);
    return AppStorePurchase(
      productId: data['productId'] as String,
      originalTransactionId: data['originalTransactionId'] as String,
      originalPurchasedAt: parseDate(data['originalPurchasedAt']),
      isFreeTrialEligible: data['isFreeTrialEligible'] as bool,
      expiresAt: parseDate(data['expiresAt']),
      cancelledAt: parseDate(data['cancelledAt']),
      expirationIntent: data['expirationIntent'] as int,
      inBillingRetryPeriod: data['inBillingRetryPeriod'] as bool,
      inFreeTrialPeriod: data['inFreeTrialPeriod'] as bool,
      autoRenewStatus: data['autoRenewStatus'] as int,
      receipt: data['receipt'] as String,
    );
  }

  @override
  bool get willAutoRenew => autoRenewStatus == 1;

  @override
  bool get isInGracePeriod => inBillingRetryPeriod;

  @override
  bool operator ==(other) {
    if (identical(this, other)) return true;
    if (other is! AppStorePurchase) return false;
    AppStorePurchase that = other;
    return productId == that.productId &&
        originalTransactionId == that.originalTransactionId &&
        originalPurchasedAt == that.originalPurchasedAt &&
        isFreeTrialEligible == that.isFreeTrialEligible &&
        expiresAt == that.expiresAt &&
        cancelledAt == that.cancelledAt &&
        expirationIntent == that.expirationIntent &&
        inBillingRetryPeriod == that.inBillingRetryPeriod &&
        inFreeTrialPeriod == that.inFreeTrialPeriod &&
        autoRenewStatus == that.autoRenewStatus &&
        receipt == that.receipt;
  }

  @override
  int get hashCode => hashObjects([
        productId,
        originalTransactionId,
        originalPurchasedAt,
        isFreeTrialEligible,
        expiresAt,
        cancelledAt,
        expirationIntent,
        inBillingRetryPeriod,
        inFreeTrialPeriod,
        autoRenewStatus,
        receipt,
      ]);

  Map<String, Object> toJson() {
    return {
      'productId': productId,
      'originalTransactionId': originalTransactionId,
      'originalPurchasedAt': originalPurchasedAt?.toIso8601String(),
      'isFreeTrialEligible': isFreeTrialEligible,
      'expiresAt': expiresAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'expirationIntent': expirationIntent,
      'inBillingRetryPeriod': inBillingRetryPeriod,
      'inFreeTrialPeriod': inFreeTrialPeriod,
      'autoRenewStatus': autoRenewStatus,
      'receipt': receipt,
    };
  }

  @override
  String toString() {
    return 'AppStorePurchase(${toJson()})';
  }
}

/// Purchase made using Google PlayStore gateway.
///
/// Holds details specific to PlayStore purchase model.
class PlayStorePurchase extends BasePurchase {
  @override
  final String productId;

  /// Whether the subscription will automatically be renewed when it reaches
  /// its current expiry time.
  final bool autoRenewing;

  /// The reason why a subscription was canceled or is not auto-renewing.
  ///
  /// `0` - user canceled.
  /// `1` - canceled by the system, e.g. because of billing problem.
  /// `2` - replaced with a new subscription.
  /// `3` - canceled by developer.
  final int cancelReason;

  /// The application package from which the purchase originated.
  final String packageName;

  /// Current purchase token of user's subscription.
  ///
  /// Can be used to fetch fresh state of this purchase.
  final String purchaseToken;

  /// List of all previous purchase tokens associated with this purchase.
  final List<String> purchaseTokenHistory;

  /// The payment state of the subscription.
  ///
  /// Values:
  ///
  /// - `0` - payment pending, billing error, user must take action.
  /// - `1` - payment received, all is ok.
  /// - `2` - free trial.
  ///
  /// Note that Play API automatically extends expiration time during
  /// grace period (paymentState == 0).
  final int paymentState;

  /// Time at which the subscription was granted.
  final DateTime startedAt;

  /// The time at which the subscription was canceled by the user.
  ///
  /// Only set when [cancelReason] is 0.
  final DateTime userCanceledAt;

  @override
  final DateTime expiresAt;

  PlayStorePurchase({
    @required this.productId,
    @required this.autoRenewing,
    @required this.cancelReason,
    @required this.packageName,
    @required this.purchaseToken,
    @required this.purchaseTokenHistory,
    @required this.paymentState,
    @required this.startedAt,
    @required this.userCanceledAt,
    @required this.expiresAt,
  });

  factory PlayStorePurchase.fromJson(Map<String, Object> data) {
    assert(data != null);
    final purchaseTokenHistory = data['purchaseTokenHistory'] ?? [];
    return PlayStorePurchase(
      productId: data['productId'] as String,
      autoRenewing: data['autoRenewing'] as bool,
      cancelReason: data['cancelReason'] as int,
      packageName: data['packageName'] as String,
      purchaseToken: data['purchaseToken'] as String,
      purchaseTokenHistory: List<String>.from(purchaseTokenHistory),
      paymentState: data['paymentState'] as int,
      startedAt: parseDate(data['startedAt']),
      userCanceledAt: parseDate(data['userCanceledAt']),
      expiresAt: parseDate(data['expiresAt']),
    );
  }

  // There is no built-in way on Android to check for free trial eligibility.
  // We assume that if user purchased subscription at least once they've used
  // their free trial.
  @override
  bool get isFreeTrialEligible => false;

  @override
  bool get willAutoRenew => autoRenewing;

  @override
  bool get isInGracePeriod => paymentState == 0;

  PlayStorePurchase copyWith({
    String productId,
    bool autoRenewing,
    int cancelReason,
    String purchaseToken,
    List<String> purchaseTokenHistory,
    int paymentState,
    DateTime startedAt,
    DateTime userCanceledAt,
    DateTime expiresAt,
  }) {
    return PlayStorePurchase(
      productId: productId ?? this.productId,
      autoRenewing: autoRenewing ?? this.autoRenewing,
      cancelReason: cancelReason ?? this.cancelReason,
      packageName: this.packageName,
      purchaseToken: purchaseToken ?? this.purchaseToken,
      purchaseTokenHistory: purchaseTokenHistory ?? this.purchaseTokenHistory,
      paymentState: paymentState ?? this.paymentState,
      startedAt: startedAt ?? this.startedAt,
      userCanceledAt: userCanceledAt ?? this.userCanceledAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  bool operator ==(other) {
    if (identical(this, other)) return true;
    if (other is! PlayStorePurchase) return false;
    final PlayStorePurchase typedOther = other;
    return productId == typedOther.productId &&
        autoRenewing == typedOther.autoRenewing &&
        cancelReason == typedOther.cancelReason &&
        packageName == typedOther.packageName &&
        purchaseToken == typedOther.purchaseToken &&
        paymentState == typedOther.paymentState &&
        startedAt == typedOther.startedAt &&
        userCanceledAt == typedOther.userCanceledAt &&
        expiresAt == typedOther.expiresAt;
  }

  @override
  int get hashCode {
    return hashObjects([
      productId,
      autoRenewing,
      cancelReason,
      packageName,
      purchaseToken,
      paymentState,
      startedAt,
      userCanceledAt,
      expiresAt,
    ]);
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'autoRenewing': autoRenewing,
      'cancelReason': cancelReason,
      'packageName': packageName,
      'purchaseToken': purchaseToken,
      'purchaseTokenHistory': purchaseTokenHistory,
      'paymentState': paymentState,
      'startedAt': startedAt?.toIso8601String(),
      'userCanceledAt': userCanceledAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'PlayStorePurchase${toJson()}';
  }
}

/// User subscription.
class Subscription {
  /// The user ID of this subscription.
  final String userId;

  /// The gateway used to make purchase.
  final PaymentGateway gateway;

  /// Free purchase details. Only set if [PaymentGateway.free] was used.
  final FreePurchase freePurchase;

  /// AppStore purchase details. Set if AppStore was used at least once by the
  /// user.
  final AppStorePurchase appStorePurchase;

  /// PlayStore purchase details. Set if PlayStore was used at least once by the
  /// user.
  final PlayStorePurchase playStorePurchase;

  /// Date and time when this subscription was created.
  final DateTime createdAt;

  /// Date and time of the latest update to this subscription.
  final DateTime updatedAt;

  Subscription({
    @required this.userId,
    @required this.gateway,
    @required this.freePurchase,
    @required this.appStorePurchase,
    @required this.playStorePurchase,
    @required this.createdAt,
    @required this.updatedAt,
  })  : assert(userId != null, 'userId is required and cannot be null'),
        assert(gateway != null, 'gateway is required and cannot be null'),
        assert(createdAt != null, 'createdAt is required and cannot be null'),
        assert(updatedAt != null, 'updatedAt is required and cannot be null');

  /// Date and time when this subscription expires.
  ///
  /// Note that [FreePurchase]s never expire in which case this field can
  /// be `null`.
  /// Depending on state of [activePurchase] this subscription may automatically
  /// renew which would consequently update this value.
  DateTime get expiresAt => activePurchase.expiresAt;

  /// Returns currently active purchase associated with this subscription.
  ///
  /// Active purchase is determined by currently used payment [gateway].
  BasePurchase get activePurchase {
    assert(gateway != null);
    if (gateway == PaymentGateway.free) {
      return freePurchase;
    } else if (gateway == PaymentGateway.appStore) {
      return appStorePurchase;
    } else if (gateway == PaymentGateway.playStore) {
      return playStorePurchase;
    } else {
      throw UnimplementedError('Unimplemented payment gateway $gateway.');
    }
  }

  /// Returns `true` if current subscription will
  /// auto-renew at the end of current billing cycle.
  bool get willAutoRenew => activePurchase.willAutoRenew;

  /// Whether current user is eligible for free trial on specified
  /// payment [gateway].
  ///
  /// Note that this method throws [StateError] for [PaymentGateway.free]
  /// as there is no concept of free trial for already free subscription. Your
  /// code shouldn't need to perform such check.
  bool isFreeTrialEligible(PaymentGateway gateway) {
    if (gateway == PaymentGateway.appStore) {
      return appStorePurchase?.isFreeTrialEligible ?? true;
    } else if (gateway == PaymentGateway.playStore) {
      return playStorePurchase?.isFreeTrialEligible ?? true;
    } else if (gateway == PaymentGateway.free) {
      throw StateError(
          'Attempting to check for free trial eligibility with Free payment gateway is not allowed.');
    } else {
      throw UnimplementedError(
          'Must implement $gateway for isFreeTrialEligible.');
    }
  }

  @override
  bool operator ==(other) {
    if (identical(this, other)) return true;
    if (other is! Subscription) return false;
    Subscription that = other;
    return userId == that.userId &&
        gateway == that.gateway &&
        freePurchase == that.freePurchase &&
        appStorePurchase == that.appStorePurchase &&
        createdAt == that.createdAt &&
        updatedAt == that.updatedAt;
  }

  @override
  int get hashCode {
    return hashObjects([
      userId,
      gateway,
      freePurchase,
      appStorePurchase,
      createdAt,
      updatedAt,
    ]);
  }

  factory Subscription.fromJson(Map<String, Object> data) {
    final userId = data['userId'] as String;
    final freePurchase = data.containsKey('freePurchase')
        ? FreePurchase.fromJson(data['freePurchase'])
        : null;
    final appStorePurchase = data.containsKey('appStorePurchase')
        ? AppStorePurchase.fromJson(data['appStorePurchase'])
        : null;
    final playStorePurchase = data.containsKey('playStorePurchase')
        ? PlayStorePurchase.fromJson(data['playStorePurchase'])
        : null;

    return Subscription(
      userId: userId,
      gateway: PaymentGateway.from(data['gateway']),
      freePurchase: freePurchase,
      appStorePurchase: appStorePurchase,
      playStorePurchase: playStorePurchase,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Subscription copyWith({
    PaymentGateway gateway,
    FreePurchase freePurchase,
    AppStorePurchase appStorePurchase,
    PlayStorePurchase playStorePurchase,
    DateTime updatedAt,
  }) {
    return Subscription(
      userId: this.userId,
      gateway: gateway ?? this.gateway,
      freePurchase: freePurchase ?? this.freePurchase,
      appStorePurchase: appStorePurchase ?? this.appStorePurchase,
      playStorePurchase: playStorePurchase ?? this.playStorePurchase,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'userId': userId,
      'gateway': gateway.value,
      'freePurchase': freePurchase,
      'appStorePurchase': appStorePurchase,
      'playStorePurchase': playStorePurchase,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Subscription(${toJson()})';
  }
}
