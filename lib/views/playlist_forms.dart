import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../controllers/playlist_controller.dart';
import '../models/playlist.dart';
import '../theme/app_theme.dart';
import '../widgets/playlist_cover.dart';

/// Formulario de creación de una lista normal.
Future<void> showCreatePlaylistSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _PlaylistForm(),
  );
}

/// Formulario de edición: mismos campos, precargados.
Future<void> showEditPlaylistSheet(BuildContext context, Playlist playlist) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PlaylistForm(playlist: playlist),
  );
}

/// Formulario de creación de una lista mixta: combina otras listas.
Future<void> showCreateMixedPlaylistSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _MixedPlaylistForm(),
  );
}

/// Pide confirmación y borra la lista. Devuelve `true` si se borró.
Future<bool> confirmDeletePlaylist(
  BuildContext context,
  Playlist playlist,
) async {
  final controller = context.read<PlaylistController>();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Eliminar lista'),
      content: Text(
        '«${playlist.title}» se eliminará. Las canciones seguirán en tu '
        'biblioteca.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );

  if (confirmed != true) return false;
  await controller.deletePlaylist(playlist.id);
  return true;
}

/// Envoltorio común de las hojas: altura contenida y desplazamiento del
/// teclado respetado.
class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Text(title, style: context.texts.titleLarge),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

/// Crea o edita una lista normal.
class _PlaylistForm extends StatefulWidget {
  const _PlaylistForm({this.playlist});

  /// `null` para crear; una lista para editarla.
  final Playlist? playlist;

  @override
  State<_PlaylistForm> createState() => _PlaylistFormState();
}

class _PlaylistFormState extends State<_PlaylistForm> {
  late final TextEditingController _title =
      TextEditingController(text: widget.playlist?.title ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.playlist?.description ?? '');

  late String? _imagePath = widget.playlist?.imagePath;
  bool _saving = false;

  bool get _isEditing => widget.playlist != null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );
      if (picked == null) return;

      // image_picker deja el fichero en la caché, que el sistema puede
      // vaciar. Lo copiamos al directorio de la app para que la portada
      // sobreviva.
      final directory = await getApplicationDocumentsDirectory();
      final destination = File(
        '${directory.path}/cover_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await destination.writeAsBytes(await picked.readAsBytes());
      if (!mounted) return;
      setState(() => _imagePath = destination.path);
    } catch (e) {
      debugPrint('Error eligiendo la portada: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo cambiar la portada')),
      );
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;

    setState(() => _saving = true);
    final controller = context.read<PlaylistController>();
    final navigator = Navigator.of(context);

    if (_isEditing) {
      await controller.updatePlaylist(
        id: widget.playlist!.id,
        title: title,
        description: _description.text.trim(),
        imagePath: _imagePath,
      );
    } else {
      await controller.createPlaylist(
        title,
        _description.text.trim(),
        const [],
        imagePath: _imagePath,
      );
    }

    if (!mounted) return;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canSave = _title.text.trim().isNotEmpty && !_saving;

    return _SheetScaffold(
      title: _isEditing ? 'Editar lista' : 'Nueva lista',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: _pickCover,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    _CoverPreview(
                      imagePath: _imagePath,
                      isMixed: widget.playlist?.isMixed ?? false,
                    ),
                    Container(
                      margin: const EdgeInsets.all(AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: colors.surface3,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.border),
                      ),
                      child: Icon(
                        Icons.photo_camera_rounded,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextField(
              controller: _title,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _description,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: canSave ? _save : null,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Guardar' : 'Crear lista'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverPreview extends StatelessWidget {
  const _CoverPreview({required this.imagePath, required this.isMixed});

  final String? imagePath;
  final bool isMixed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const side = 132.0;

    final file = imagePath == null ? null : File(imagePath!);

    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
        gradient: file == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.primary.withValues(alpha: 0.55),
                  colors.accent.withValues(alpha: 0.30),
                ],
              )
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: file != null && file.existsSync()
          ? Image.file(file, fit: BoxFit.cover)
          : Icon(
              isMixed
                  ? Icons.auto_awesome_motion_rounded
                  : Icons.add_photo_alternate_outlined,
              size: 40,
              color: Colors.white.withValues(alpha: 0.92),
            ),
    );
  }
}

/// Crea una lista mixta eligiendo qué listas la componen.
class _MixedPlaylistForm extends StatefulWidget {
  const _MixedPlaylistForm();

  @override
  State<_MixedPlaylistForm> createState() => _MixedPlaylistFormState();
}

class _MixedPlaylistFormState extends State<_MixedPlaylistForm> {
  final TextEditingController _title = TextEditingController();
  final Set<String> _selected = {};
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final controller = context.read<PlaylistController>();
    final navigator = Navigator.of(context);
    await controller.createMixedPlaylist(
      _title.text.trim(),
      'Combina ${_selected.length} listas',
      _selected.toList(),
    );
    if (!mounted) return;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlaylistController>();
    // Una lista mixta sólo puede combinar listas normales: anidar mixtas
    // abriría la puerta a ciclos.
    final candidates =
        controller.playlists.where((p) => !p.isMixed).toList();

    final canSave =
        _title.text.trim().isNotEmpty && _selected.isNotEmpty && !_saving;

    return _SheetScaffold(
      title: 'Nueva lista mixta',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Una lista mixta reúne las canciones de varias listas. Si '
                  'cambias una de ellas, la mixta se actualiza sola.',
                  style: context.texts.bodySmall
                      ?.copyWith(color: context.colors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _title,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          Flexible(
            child: candidates.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Text('Necesitas al menos una lista normal.'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: candidates.length,
                    itemBuilder: (context, i) {
                      final playlist = candidates[i];
                      final checked = _selected.contains(playlist.id);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (value) => setState(() {
                          if (value == true) {
                            _selected.add(playlist.id);
                          } else {
                            _selected.remove(playlist.id);
                          }
                        }),
                        secondary:
                            PlaylistCover(playlist: playlist, size: 44),
                        title: Text(playlist.title),
                        subtitle: Text(
                          '${playlist.songIds.length} canciones',
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canSave ? _save : null,
                child: const Text('Crear lista mixta'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
