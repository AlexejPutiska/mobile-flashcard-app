import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../api_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../main.dart';

/// EditCardScreenMobile umožňuje používateľovi upravovať existujúcu kartičku.
///
/// Obsahuje možnosť upraviť text alebo nahrať obrázok pre obe strany kartičky.
/// Používateľ môže medzi stranami preklikávať pomocou animovaného preklápania.
///
/// Funkcionality zahŕňajú:
/// - načítanie pôvodných dát kartičky zo servera cez [ApiService.getFlashcardById],
/// - detekciu zmien oproti pôvodnému obsahu,
/// - overenie a potvrdenie opustenia obrazovky pri neuložených zmenách,
/// - možnosť nahratia obrázka z kamery alebo galérie (s kontrolou oprávnení),
/// - uloženie zmien na server pomocou [ApiService.updateFlashcard],
/// - vymazanie kartičky cez [ApiService.deleteFlashcard].
///
/// Používa animovaný prechod pre preklápanie karty a prispôsobenie veľkosti textu
/// podľa nastavení prístupnosti cez [MyApp.isLargeText].
class EditCardScreenTablet extends StatefulWidget {
  /// ID kartičky, ktorá sa má upraviť.
  final int flashcardId;

  const EditCardScreenTablet({super.key, required this.flashcardId});

  @override
  State<EditCardScreenTablet> createState() => _EditCardScreenState();
}

/// Stavová trieda pre [EditCardScreenMobile].
///
/// Zabezpečuje logiku správy obsahu kartičky, obrázkov, animácií a interakcií
/// so serverom a používateľom.
class _EditCardScreenState extends State<EditCardScreenTablet>
    with SingleTickerProviderStateMixin {
  bool isFrontSide = true;

  String frontText = '';
  String backText = '';
  Uint8List? frontImage;
  Uint8List? backImage;

  String _originalFrontText = '';
  String _originalBackText = '';
  Uint8List? _originalFrontImage;
  Uint8List? _originalBackImage;

  late AnimationController _controller;
  late Animation<double> _animation;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: pi).animate(_controller);
    _loadFlashcardData();
  }

  /// Načíta dáta kartičky zo servera na základe [widget.flashcardId]
  /// a nastaví predvolené hodnoty textu a obrázkov pre obe strany.
  Future<void> _loadFlashcardData() async {
    try {
      final data = await ApiService().getFlashcardById(widget.flashcardId);
      setState(() {
        frontText = data['front_side'] ?? '';
        backText = data['back_side'] ?? '';

        final frontBase64 = data['image_front'];
        final backBase64 = data['image_back'];

        if (frontBase64 != null && frontBase64.isNotEmpty) {
          final cleanedFront = frontBase64.replaceAll(
            RegExp(r'[^A-Za-z0-9+/=]+'),
            '',
          );
          frontImage = base64Decode(cleanedFront);
        }

        if (backBase64 != null && backBase64.isNotEmpty) {
          final cleanedBack = backBase64.replaceAll(
            RegExp(r'[^A-Za-z0-9+/=]+'),
            '',
          );
          backImage = base64Decode(cleanedBack);
        }
      });
    } catch (e) {
      debugPrint('Error loading flashcard: $e');
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Overí, či je kartička vyplnená — t. j. aspoň jedna z oboch strán má text alebo obrázok.
  bool _isCardFilled() {
    return (frontText.trim().isNotEmpty || frontImage != null) &&
        (backText.trim().isNotEmpty || backImage != null);
  }

  /// Porovná aktuálny stav textov/obrázkov s pôvodnými hodnotami
  /// a určí, či došlo k nejakej zmene.
  bool _hasUnsavedChanges() {
    if (frontText.trim() != _originalFrontText.trim()) return true;
    if (backText.trim() != _originalBackText.trim()) return true;

    if ((frontImage == null && _originalFrontImage != null) ||
        (frontImage != null && _originalFrontImage == null)) {
      return true;
    }
    if (frontImage != null && _originalFrontImage != null) {
      if (!listEquals(frontImage, _originalFrontImage)) {
        return true;
      }
    }

    if ((backImage == null && _originalBackImage != null) ||
        (backImage != null && _originalBackImage == null)) {
      return true;
    }
    if (backImage != null && _originalBackImage != null) {
      if (!listEquals(backImage, _originalBackImage)) {
        return true;
      }
    }

    return false;
  }

  /// Zobrazí dialógové okno na potvrdenie opustenia obrazovky
  /// bez uloženia zmien.
  Future<bool> _confirmDiscardChanges() async {
    final isLargeText = MyApp.of(context)?.isLargeText ?? false;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Discard changes?',
              style: TextStyle(
                fontSize: isLargeText ? 24 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'You have unsaved changes. Do you want to leave without saving?',
              style: TextStyle(fontSize: isLargeText ? 20 : 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'No',
                  style: TextStyle(fontSize: isLargeText ? 20 : 16),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Yes',
                  style: TextStyle(fontSize: isLargeText ? 20 : 16),
                ),
              ),
            ],
          ),
    );

    return (shouldDiscard == true);
  }

  /// Volá [_confirmDiscardChanges], ak existujú zmeny.
  /// Ak žiadne zmeny nie sú alebo používateľ potvrdí, umožní návrat späť.
  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges()) return true;

    final discard = await _confirmDiscardChanges();
    return discard;
  }

  /// Otočí kartu a spustí animáciu preklopenia z jednej strany na druhú.
  void _flipCard() {
    if (isFrontSide) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() => isFrontSide = !isFrontSide);
  }

  /// Zobrazí modálny dialóg na úpravu textu aktuálnej strany kartičky.
  /// Po potvrdení nahradí text a odstráni prípadný obrázok.
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
                  const SizedBox(height: 8),
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

  /// Zobrazí dialóg pre výber zdroja obrázka (kamera alebo galéria),
  /// získa oprávnenie a nahrá obrázok.
  /// Po úspešnom výbere nahradí aktuálny obrázok danej strany.
  Future<void> _pickImage() async {
    if (isPickingImage) return;
    setState(() => isPickingImage = true);

    final isLargeText = MyApp.of(context)?.isLargeText ?? false;

    try {
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
        return;
      }

      final XFile? picked = await _picker.pickImage(source: source);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      setState(() {
        if (isFrontSide) {
          frontImage = bytes;
          frontText = '';
        } else {
          backImage = bytes;
          backText = '';
        }
      });
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

  /// Zobrazí potvrdenie na odstránenie kartičky a po potvrdení
  /// zavolá [ApiService.deleteFlashcard].
  Future<void> _confirmAndDeleteCard() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove card?'),
            content: const Text(
              'Are you sure you want to remove this card? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Remove'),
              ),
            ],
          ),
    );

    if (shouldDelete == true) {
      final success = await ApiService().deleteFlashcard(widget.flashcardId);
      if (success && mounted) {
        Navigator.pop(context, 'deleted');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;
    final cardFrontColor = isDark ? Colors.grey[800] : const Color(0xFFE1E1E1);
    final cardBackColor = isDark ? Colors.grey[700] : const Color(0xFFC1C1C1);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final isLargeText = MyApp.of(context)?.isLargeText ?? false;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          centerTitle: true,
          leading: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: InkWell(
              borderRadius: BorderRadius.circular(32),
              onTap: () async {
                final canPop = await _onWillPop();
                if (canPop && mounted) {
                  Navigator.pop(context);
                }
              },
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
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 800;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  Center(
                    child: SizedBox(
                      width: isTablet ? 500 : 360,
                      height: isTablet ? 600 : 540,
                      child: GestureDetector(
                        onTap: _flipCard,
                        child: AnimatedBuilder(
                          animation: _animation,
                          builder: (context, child) {
                            final isBack = _animation.value >= pi / 2;
                            final content =
                                isBack
                                    ? (backImage != null
                                        ? Image.memory(
                                          backImage!,
                                          fit: BoxFit.contain,
                                        )
                                        : Text(
                                          backText,
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
                                                fontSize: isLargeText ? 25 : 18,
                                              ),
                                        ))
                                    : (frontImage != null
                                        ? Image.memory(
                                          frontImage!,
                                          fit: BoxFit.contain,
                                        )
                                        : Text(
                                          frontText,
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
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
                                  color:
                                      isBack ? cardBackColor : cardFrontColor,
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
                                          color:
                                              isDark
                                                  ? Colors.white
                                                  : Colors.black54,
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
                  ),
                  const SizedBox(height: 38),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 20,
                    runSpacing: 12,
                    children: [
                      ElevatedButton(
                        onPressed: _editText,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDark ? Colors.grey[800] : Colors.grey[200],
                          foregroundColor: textColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          'Change image',
                          style: TextStyle(fontSize: isLargeText ? 19 : 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (!_isCardFilled())
                    Text(
                      'You must fill both sides of the card',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: isLargeText ? 18 : 14,
                      ),
                    ),
                  const SizedBox(height: 100),
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 60),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _isCardFilled()
                          ? () async {
                            String baseName =
                                frontText.trim().isNotEmpty
                                    ? (frontText.length > 15
                                        ? '${frontText.substring(0, 15)}...'
                                        : frontText)
                                    : '[image]';

                            final success = await ApiService().updateFlashcard(
                              flashcardId: widget.flashcardId,
                              frontText: frontText,
                              backText: backText,
                              frontImage: frontImage,
                              backImage: backImage,
                              name: baseName,
                            );

                            if (success && mounted) {
                              Navigator.pop(context, true);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to update card'),
                                ),
                              );
                            }
                          }
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Update card',
                    style: TextStyle(
                      fontSize: isLargeText ? 20 : 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: ElevatedButton(
                  onPressed: _confirmAndDeleteCard,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Remove card',
                    style: TextStyle(
                      fontSize: isLargeText ? 20 : 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
