import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:math';
import '../../api_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../main.dart';

/// Obrazovka pre vytvorenie novej kartičky (flashcard) pre mobilné zariadenia.
///
/// Očakáva `setId` ako argument v route, ktorý určuje, do ktorého setu sa
/// má kartička uložiť.
///
/// Táto trieda len inicializuje stavovú obrazovku `NewCardScreenContent`.
class NewCardScreenMobile extends StatelessWidget {
  const NewCardScreenMobile({super.key});

  @override
  Widget build(BuildContext context) {
    final int setId = ModalRoute.of(context)!.settings.arguments as int;
    return NewCardScreenContent(setId: setId);
  }
}

/// Stavová obrazovka pre vytváranie novej kartičky.
///
/// Umožňuje:
/// - zadať text pre prednú a zadnú stranu,
/// - nahrať obrázok pre každú stranu z kamery alebo galérie,
/// - otáčať kartičku animáciou pomocou `AnimationController`,
/// - validovať, či sú vyplnené obe strany,
/// - odoslať kartu na backend pomocou `ApiService().saveCardToSet()`.
///
/// V prípade úspešného uloženia sa karta vráti späť do nadriadenej obrazovky
/// ako `Map<String, dynamic>`.
class NewCardScreenContent extends StatefulWidget {
  final int setId;

  const NewCardScreenContent({super.key, required this.setId});

  @override
  State<NewCardScreenContent> createState() => _NewCardScreenContentState();
}

class _NewCardScreenContentState extends State<NewCardScreenContent>
    with SingleTickerProviderStateMixin {
  bool isFrontSide = true;
  String frontText = '';
  String backText = '';
  Uint8List? frontImage;
  Uint8List? backImage;

  late AnimationController _controller;
  late Animation<double> _animation;

  final ImagePicker _picker = ImagePicker();

  /// Inicializuje animáciu pre otáčanie kartičky.
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: pi).animate(_controller);
  }

  /// Uvoľní zdroje kontroléra animácie.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Zistí, či je karta platná – musí mať obsah aspoň na jednej strane.
  ///
  /// Predná aj zadná strana musia obsahovať buď text, alebo obrázok.
  bool _isCardFilled() {
    return (frontText.trim().isNotEmpty || frontImage != null) &&
        (backText.trim().isNotEmpty || backImage != null);
  }

  /// Otočí kartu – zmení pohľad z prednej na zadnú a naopak.
  void _flipCard() {
    if (isFrontSide) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() => isFrontSide = !isFrontSide);
  }

  /// Otvorí modálne dialógové okno na úpravu textu kartičky.
  ///
  /// Po potvrdení aktualizuje buď `frontText`, alebo `backText`
  /// a zároveň odstráni prípadný obrázok.
  Future<void> _editText() async {
    final controller = TextEditingController(
      text: isFrontSide ? frontText : backText,
    );

    final typedText = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isLargeText = MyApp.of(context)?.isLargeText ?? false;
        final theme = Theme.of(context);
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 360,
              height: 540,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 8),
              child: Column(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      maxLines: null,
                      maxLength: 500,
                      expands: true,
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: isLargeText ? 25 : 18,
                      ),
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black,
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(fontSize: isLargeText ? 20 : 14),
                        ),
                      ),
                      ElevatedButton(
                        onPressed:
                            () =>
                                Navigator.pop(context, controller.text.trim()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          'OK',
                          style: TextStyle(fontSize: isLargeText ? 20 : 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (typedText != null) {
      setState(() {
        if (isFrontSide) {
          frontText = typedText;
          frontImage = null;
        } else {
          backText = typedText;
          backImage = null;
        }
      });
    }
  }

  bool isPickingImage = false;

  /// Vyberie obrázok z galérie alebo kamery a priradí ho k správnej strane.
  ///
  /// Pred použitím vyžiada potrebné oprávnenia.
  /// Ak je obrázok vybraný, nahradí aktuálny text danej strany.
  Future<void> _pickImage() async {
    if (isPickingImage) return;
    setState(() => isPickingImage = true);

    final isLargeText = MyApp.of(context)?.isLargeText ?? false;

    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              'Choose source',
              style: TextStyle(
                fontSize: isLargeText ? 26 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Select image source:',
              style: TextStyle(fontSize: isLargeText ? 22 : 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, ImageSource.camera),
                child: Text(
                  'Camera',
                  style: TextStyle(fontSize: isLargeText ? 24 : 16),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
                child: Text(
                  'Gallery',
                  style: TextStyle(fontSize: isLargeText ? 24 : 16),
                ),
              ),
            ],
          ),
    );

    if (source == null) {
      setState(() => isPickingImage = false);
      return;
    }

    bool granted = false;
    if (source == ImageSource.camera) {
      granted = await Permission.camera.request().isGranted;
    } else {
      if (await Permission.photos.request().isGranted) {
        granted = true;
      } else if (await Permission.mediaLibrary.request().isGranted) {
        granted = true;
      } else if (await Permission.storage.request().isGranted) {
        granted = true;
      }
    }

    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Permission denied for ${source == ImageSource.camera ? 'camera' : 'gallery'}',
            style: TextStyle(fontSize: isLargeText ? 20 : 16),
          ),
        ),
      );
      setState(() => isPickingImage = false);
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          if (isFrontSide) {
            frontImage = bytes;
            frontText = '';
          } else {
            backImage = bytes;
            backText = '';
          }
        });
      }
    } catch (e) {
      debugPrint('Image picking failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to pick image',
            style: TextStyle(fontSize: isLargeText ? 20 : 16),
          ),
        ),
      );
    } finally {
      setState(() => isPickingImage = false);
    }
  }

  /// Vytvára samotné rozhranie obrazovky.
  ///
  /// Obsahuje:
  /// - animovanú kartu (predná/zadná strana),
  /// - tlačidlá na zmenu textu alebo obrázku,
  /// - spodné tlačidlo „Update card“, ktoré uloží kartu,
  /// - upozornenie pri nevyplnenej karte.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
    final frontCardColor = isDark ? Colors.grey[800] : const Color(0xFFE1E1E1);
    final backCardColor = isDark ? Colors.grey[700] : const Color(0xFFC1C1C1);
    final isLargeText = MyApp.of(context)?.isLargeText ?? false;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: () => Navigator.pop(context),
            child: Icon(
              Icons.arrow_back,
              color: theme.iconTheme.color,
              size: 32,
            ),
          ),
        ),
        title: Text(
          isFrontSide ? 'Front side' : 'Back side',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: isLargeText ? 30 : 20,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _flipCard,
              child: SizedBox(
                width: 360,
                height: 540,
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    final isBack = _animation.value >= pi / 2;
                    final content =
                        isBack
                            ? (backImage != null
                                ? Image.memory(backImage!, fit: BoxFit.contain)
                                : Text(
                                  backText,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontSize: isLargeText ? 25 : 18,
                                  ),
                                ))
                            : (frontImage != null
                                ? Image.memory(frontImage!, fit: BoxFit.contain)
                                : Text(
                                  frontText,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontSize: isLargeText ? 25 : 18,
                                  ),
                                ));

                    return Transform(
                      alignment: Alignment.center,
                      transform:
                          Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(_animation.value),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isBack ? backCardColor : frontCardColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform(
                              alignment: Alignment.center,
                              transform:
                                  isBack
                                      ? Matrix4.rotationY(pi)
                                      : Matrix4.identity(),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  24,
                                  24,
                                  48,
                                ),
                                child: content,
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              child: GestureDetector(
                                onTap: _flipCard,
                                child: Icon(
                                  Icons.sync,
                                  size: 28,
                                  color: isDark ? Colors.white : Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 38),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _editText,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isDark ? Colors.grey[800] : Colors.grey[200],
                    foregroundColor: textColor,
                  ),
                  child: Text(
                    'Change text',
                    style: TextStyle(fontSize: isLargeText ? 19 : 15),
                  ),
                ),
                ElevatedButton(
                  onPressed: _pickImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isDark ? Colors.grey[800] : Colors.grey[200],
                    foregroundColor: textColor,
                  ),
                  child: Text(
                    'Change image',
                    style: TextStyle(fontSize: isLargeText ? 19 : 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed:
                    _isCardFilled()
                        ? () async {
                          final int? cardId = await ApiService().saveCardToSet(
                            setId: widget.setId,
                            frontText: frontText,
                            backText: backText,
                            frontImage: frontImage,
                            backImage: backImage,
                          );

                          if (cardId != null) {
                            String frontDisplay =
                                frontText.trim().isNotEmpty
                                    ? frontText.trim()
                                    : (frontImage != null ? '[image]' : '');

                            Navigator.pop(context, {
                              'id': cardId,
                              'front': frontDisplay,
                              'back': backText,
                              if (frontImage != null) 'image_front': frontImage,
                            });
                            debugPrint('🔁 Returning new card ID: $cardId');
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to save card'),
                              ),
                            );
                          }
                        }
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Update card',
                  style: TextStyle(
                    fontSize: isLargeText ? 24 : 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (!_isCardFilled())
              Text(
                'You must fill both sides of the card',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: isLargeText ? 18 : 14,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
