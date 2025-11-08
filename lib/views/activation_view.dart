import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/trial_controller.dart';

class ActivationView extends StatefulWidget {
  const ActivationView({super.key});

  @override
  State<ActivationView> createState() => _ActivationViewState();
}

class _ActivationViewState extends State<ActivationView> {
  final _codeCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'El código debe tener 6 dígitos');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final trial = context.read<TrialController>();
    final result = await trial.submitCode(code);
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (result) {
      case ActivationResult.invalid:
        setState(() => _error = 'Código inválido');
        break;
      case ActivationResult.limited:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inicio Fase de Prueba 2 dias disponible'),
          ),
        );
        break;
      case ActivationResult.unlimited:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Activación completa')));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activar aplicación')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Introduce el código de activación de 6 dígitos',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeCtrl,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Código',
                    counterText: '',
                    errorText: _error,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_open),
                    label: const Text('Activar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
