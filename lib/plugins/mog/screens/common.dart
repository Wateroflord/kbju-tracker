import 'package:flutter/material.dart';

import '../photo.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Место для фото: пусто — кнопка выбора, выбрано — превью с кнопкой «сменить».
class PhotoSlot extends StatelessWidget {
  final Photo? photo;
  final String label;
  final Color color;
  final double aspect;
  final ValueChanged<Photo> onPicked;
  final VoidCallback? onClear;

  const PhotoSlot({
    super.key,
    required this.photo,
    required this.label,
    required this.color,
    required this.onPicked,
    this.onClear,
    this.aspect = 0.78,
  });

  Future<void> _pick(BuildContext context) async {
    final p = await pickPhoto(context);
    if (p != null) onPicked(p);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspect,
      child: Material(
        color: C.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _pick(context),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: photo == null ? C.border : color, width: photo == null ? 1 : 2),
            ),
            child: photo == null
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                      child: Icon(Icons.add_a_photo_outlined, color: color),
                    ),
                    const SizedBox(height: 12),
                    Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 15)),
                    const SizedBox(height: 4),
                    const Text('нажми, чтобы выбрать', textAlign: TextAlign.center, style: TextStyle(color: C.muted, fontSize: 12)),
                  ])
                : Stack(fit: StackFit.expand, children: [
                    Image.memory(photo!.full, fit: BoxFit.cover, gaplessPlayback: true),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                        child: Text(label,
                            style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 12.5)),
                      ),
                    ),
                    if (onClear != null)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          onPressed: onClear,
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        color: Colors.black.withValues(alpha: 0.45),
                        child: const Text('сменить фото',
                            textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Colors.white)),
                      ),
                    ),
                  ]),
          ),
        ),
      ),
    );
  }
}

/// Плашка «нет ключа».
class NoKeyBanner extends StatelessWidget {
  final VoidCallback onOpenSettings;
  const NoKeyBanner({super.key, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Panel(
          borderColor: C.gold.withValues(alpha: 0.5),
          child: Row(children: [
            const Icon(Icons.key_rounded, color: C.gold),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Для оценки нужен бесплатный ключ Gemini — тот же, что в КБЖУ Трекере.',
                  style: TextStyle(height: 1.35)),
            ),
            TextButton(onPressed: onOpenSettings, child: const Text('Добавить')),
          ]),
        ),
      );
}

/// Слушает Store и перестраивается при изменениях.
class StoreBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, Store s) builder;
  const StoreBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: Store.I, builder: (context, _) => builder(context, Store.I));
}
