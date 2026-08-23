import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../crypto/vault_crypto.dart';
import '../state/vault_session.dart';
import 'safe_logo.dart';
import 'theme/safe_theme.dart';
import 'widgets/primary_button.dart';

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
    // Les libellés sont lus AVANT le premier `await`: après, le contexte a
    // pu disparaître, et l'analyseur a raison de le refuser.
    final t = L.of(context);
    final password = _passwordController.text;
    if (widget.isCreation) {
      if (password.length < minMasterPasswordLength) {
        setState(() {
          _error = t.unlockTooShort(minMasterPasswordLength);
        });
        return;
      }
      if (password != _confirmController.text) {
        setState(() => _error = t.unlockMismatch);
        return;
      }
    } else if (password.isEmpty) {
      setState(() => _error = t.unlockWrongPassword);
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
      _fail(t.unlockWrongPassword);
    } on FormatException {
      _fail(t.unlockWrongPassword);
    } catch (error) {
      _fail(t.unlockOpenFailed('$error'));
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

  /// Filet bas commun aux deux états du champ: le handoff ne dessine pas de
  /// boîte, seulement un trait sous le texte.
  UnderlineInputBorder _underline(SafeTokens tokens) => UnderlineInputBorder(
    borderSide: BorderSide(color: tokens.ink, width: 1.5),
  );

  @override
  Widget build(BuildContext context) {
    final tokens = SafeTokens.of(context);
    final t = L.of(context);
    return Scaffold(
      backgroundColor: tokens.pageBackground,
      // Le contenu et le pied de page sont deux enfants distincts: l'un
      // centré dans l'espace qui reste, l'autre ancré au bord bas. Empilés
      // dans une seule colonne à `min`, le pied de page se retrouvait collé
      // sous le bouton, au milieu de l'écran, plutôt qu'à sa marge de 34 px.
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 40,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SafeLogo(size: 34),
                        const SizedBox(height: 26),
                        Text(
                          widget.isCreation
                              ? t.unlockWelcome
                              : t.unlockWelcomeBack,
                          style: SafeText.screenTitle.copyWith(
                            fontSize: 30,
                            height: 1.15,
                            color: tokens.ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.isCreation
                              // Seul endroit où l'utilisateur apprend qu'un mot de
                              // passe oublié rend le coffre définitivement
                              // illisible: cet avertissement ne doit jamais
                              // disparaître de l'écran de création.
                              ? t.unlockCreateSubtitle
                              : t.unlockSubtitle,
                          style: TextStyle(
                            fontFamily: safeSans,
                            fontWeight: FontWeight.w400,
                            fontSize: 13.5,
                            height: 1.6,
                            color: tokens.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextField(
                          key: const Key('password'),
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          autofocus: true,
                          obscureText: _obscure,
                          enabled: !_busy,
                          style: TextStyle(
                            fontFamily: safeMono,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                            letterSpacing: 2.56,
                            color: tokens.ink,
                          ),
                          cursorColor: tokens.accent,
                          cursorWidth: 2,
                          decoration: InputDecoration(
                            hintText: t.unlockPasswordHint,
                            hintStyle: TextStyle(
                              fontFamily: safeSans,
                              fontSize: 13.5,
                              // Remis à zéro: Flutter fusionne ce style
                              // PAR-DESSUS celui du champ, dont l'espacement
                              // de .16em est fait pour une suite de points.
                              // Hérité, il écarte les lettres d'un mot
                              // français jusqu'à le rendre pénible à lire.
                              letterSpacing: 0,
                              color: tokens.hintText,
                            ),
                            border: InputBorder.none,
                            enabledBorder: _underline(tokens),
                            focusedBorder: _underline(tokens),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                                color: tokens.tertiaryText,
                              ),
                              iconSize: 20,
                              constraints: BoxConstraints.tightFor(
                                width: SafeMetrics.touchTarget,
                                height: SafeMetrics.touchTarget,
                              ),
                              tooltip: _obscure ? t.unlockShow : t.unlockHide,
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
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
                            style: TextStyle(
                              fontFamily: safeMono,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              letterSpacing: 2.56,
                              color: tokens.ink,
                            ),
                            cursorColor: tokens.accent,
                            cursorWidth: 2,
                            decoration: InputDecoration(
                              hintText: t.unlockConfirmHint,
                              hintStyle: TextStyle(
                                fontFamily: safeSans,
                                fontSize: 13.5,
                                // Voir le champ ci-dessus: sans cette remise
                                // à zéro, l'invite hérite de l'espacement des
                                // points.
                                letterSpacing: 0,
                                color: tokens.hintText,
                              ),
                              border: InputBorder.none,
                              enabledBorder: _underline(tokens),
                              focusedBorder: _underline(tokens),
                            ),
                            onSubmitted: (_) => _submit(),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: TextStyle(
                              fontFamily: safeSans,
                              fontSize: 13.5,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SafePrimaryButton(
                          key: const Key('submit'),
                          label: widget.isCreation
                              ? t.unlockCreate
                              : t.unlockOpen,
                          onPressed: _busy ? null : _submit,
                          // La dérivation Argon2id prend plusieurs secondes:
                          // une roue distingue l'attente d'un simple bouton
                          // invalide.
                          busy: _busy,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Ancré au bord bas, hors du bloc défilant: sur un petit écran
            // avec le clavier ouvert, le contenu continue de défiler dans
            // l'`Expanded` sans que ce texte ne soit poussé hors de l'écran.
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 34),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(
                    t.unlockAutoLockFooter(
                      _delaiLisible(t, widget.session.autoLockDelay),
                    ),
                    style: SafeText.meta.copyWith(color: tokens.hintText),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « 30 s », « 1 min », « 2 min »… La maquette affichait « 5 min » en dur; le
/// délai est un réglage, et deux vérités pour un même réglage, on en a déjà
/// corrigé une.
String _delaiLisible(L t, Duration delay) => delay.inMinutes >= 1
    ? t.delayMinutes(delay.inMinutes)
    : t.delaySeconds(delay.inSeconds);
