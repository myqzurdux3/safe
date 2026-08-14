import 'package:flutter/material.dart';

import '../crypto/vault_crypto.dart';
import '../state/vault_session.dart';

/// Longueur minimale exigée à la création. Pas de règle de composition: la
/// longueur est ce qui compte face à Argon2id, les règles arbitraires poussent
/// surtout à choisir des mots de passe mémorisables et faibles.
const int minMasterPasswordLength = 12;

/// Écran d'entrée: création du coffre s'il n'existe pas encore, déverrouillage
/// sinon.
class UnlockScreen extends StatefulWidget {
  const UnlockScreen({
    required this.session,
    required this.isCreation,
    super.key,
  });

  final VaultSession session;
  final bool isCreation;

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _passwordFocus = FocusNode();

  String? _error;
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    final password = _passwordController.text;
    if (widget.isCreation) {
      if (password.length < minMasterPasswordLength) {
        setState(() {
          _error =
              'Le mot de passe doit faire au moins $minMasterPasswordLength caractères';
        });
        return;
      }
      if (password != _confirmController.text) {
        setState(() => _error = 'Les mots de passe ne correspondent pas');
        return;
      }
    } else if (password.isEmpty) {
      setState(() => _error = 'Mot de passe incorrect');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.isCreation) {
        await widget.session.create(password);
      } else {
        await widget.session.unlock(password);
      }
    } on WrongPasswordException {
      // Même message pour un mauvais mot de passe et pour un fichier altéré:
      // distinguer les deux renseignerait un attaquant sur l'état du coffre.
      _fail('Mot de passe incorrect');
    } on FormatException {
      _fail('Mot de passe incorrect');
    } catch (error) {
      _fail('Impossible d\'ouvrir le coffre: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _fail(String message) {
    _passwordController.clear();
    _confirmController.clear();
    if (mounted) {
      setState(() => _error = message);
      _passwordFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  widget.isCreation ? Icons.shield_outlined : Icons.lock_outline,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.isCreation ? 'Créer votre coffre' : 'safe',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                TextField(
                  key: const Key('password'),
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  autofocus: true,
                  obscureText: _obscure,
                  enabled: !_busy,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe maître',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      tooltip: _obscure ? 'Afficher' : 'Masquer',
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                if (widget.isCreation) ...[
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('confirm'),
                    controller: _confirmController,
                    obscureText: _obscure,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Confirmation',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ce mot de passe est la seule clef du coffre. S\'il est '
                    'perdu, il n\'y a aucun moyen de récupérer son contenu.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('submit'),
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          widget.isCreation
                              ? 'Créer le coffre'
                              : 'Déverrouiller',
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
