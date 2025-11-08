import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/trial_service.dart';

class TrialController extends ChangeNotifier {
  final TrialService _service = TrialService();
  bool loading = false;
  bool expired = false;
  bool activated = false;
  bool unlimited = false;
  Duration? remaining;
  DateTime? expiry;
  Timer? _ticker;

  Future<void> init() async {
    loading = true;
    notifyListeners();
    activated = await _service.isActivated();
    unlimited = await _service.isUnlimited();
    expired = activated ? await _service.isExpired() : false;
    if (activated && !unlimited && !expired) {
      expiry = await _service.getExpiryTimestamp();
      _recomputeRemaining();
      _startTicker();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> forceExpire() async {
    await _service.forceExpire();
    expired = true;
    notifyListeners();
  }

  Future<ActivationResult> submitCode(String code) async {
    if (code == '654321') {
      await _service.activateUnlimited();
      activated = true;
      unlimited = true;
      expired = false;
      remaining = null;
      _stopTicker();
      notifyListeners();
      return ActivationResult.unlimited;
    }
    if (code == '000000') {
      await _service.activateLimitedNow();
      activated = true;
      unlimited = false;
      expired = false;
      expiry = await _service.getExpiryTimestamp();
      _recomputeRemaining();
      _startTicker();
      notifyListeners();
      return ActivationResult.limited;
    }
    return ActivationResult.invalid;
  }

  void _recomputeRemaining() {
    if (expiry == null) {
      remaining = null;
      return;
    }
    final diff = expiry!.difference(DateTime.now());
    if (diff.isNegative) {
      remaining = Duration.zero;
      expired = true;
      _stopTicker();
    } else {
      remaining = diff;
    }
  }

  void _startTicker() {
    _stopTicker();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _recomputeRemaining();
      notifyListeners();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }
}

enum ActivationResult { invalid, limited, unlimited }
