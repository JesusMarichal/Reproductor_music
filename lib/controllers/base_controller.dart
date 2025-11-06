import 'package:flutter/foundation.dart';

/// BaseController ahora extiende [ChangeNotifier] para permitir
/// notificar cambios a la UI de forma eficiente.
abstract class BaseController extends ChangeNotifier {}
