import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../session/session_store.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _apiClient = ApiClient();
  final _sessionStore = SessionStore();

  final _nameFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _email;
  bool _loading = true;
  bool _savingName = false;
  bool _savingPassword = false;
  bool _sendingReset = false;
  String? _nameError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _email = await _sessionStore.readUserEmail();
    _nameController.text = await _sessionStore.readUserName() ?? '';
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveName() async {
    if (!_nameFormKey.currentState!.validate()) return;

    setState(() {
      _savingName = true;
      _nameError = null;
    });

    try {
      final name = _nameController.text.trim();
      await _apiClient.updateProfile(name: name);
      await _sessionStore.saveUserName(name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre actualizado')),
      );
    } catch (e) {
      setState(() => _nameError = e.toString());
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() {
      _savingPassword = true;
      _passwordError = null;
    });

    try {
      await _apiClient.updateProfile(password: _newPasswordController.text);
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada')),
      );
    } catch (e) {
      setState(() => _passwordError = e.toString());
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    if (_email == null) return;

    setState(() => _sendingReset = true);
    try {
      await _apiClient.sendPasswordReset(_email!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Te hemos enviado un email de recuperacion a $_email')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text('Email', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(_email ?? '', style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 4),
                    Text(
                      'El email no se puede cambiar.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                    const Divider(height: 40),

                    Text('Nombre', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Form(
                      key: _nameFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Introduce un nombre' : null,
                          ),
                          if (_nameError != null) ...[
                            const SizedBox(height: 8),
                            Text(_nameError!,
                                style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          ],
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _savingName ? null : _saveName,
                            child: _savingName
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Guardar nombre'),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 40),

                    Text('Cambiar contraseña', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Form(
                      key: _passwordFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Nueva contraseña',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (v == null || v.length < 6) {
                                return 'Minimo 6 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Confirmar contraseña',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (v != _newPasswordController.text) {
                                return 'Las contraseñas no coinciden';
                              }
                              return null;
                            },
                          ),
                          if (_passwordError != null) ...[
                            const SizedBox(height: 8),
                            Text(_passwordError!,
                                style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          ],
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _savingPassword ? null : _changePassword,
                            child: _savingPassword
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Cambiar contraseña'),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 40),

                    Text('Recuperar contraseña', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Si prefieres restablecerla por email en vez de escribir una nueva aqui.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _sendingReset ? null : _sendPasswordReset,
                      child: _sendingReset
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Enviarme un email de recuperacion'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
