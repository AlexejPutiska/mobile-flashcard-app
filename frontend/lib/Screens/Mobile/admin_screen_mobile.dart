import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../models.dart';

/// AdminScreenMobile zobrazuje administrátorské rozhranie pre mobilné zariadenia.
///
/// Umožňuje administrátorovi:
/// - vytvárať nové verejné flashcard sety (public sets),
/// - zobraziť zoznam všetkých aktuálne dostupných public setov,
/// - upravovať existujúce sety.
///
/// Tento widget využíva `ApiService` na volania backendu.
/// Zobrazované sety sú reprezentované triedou [FlashcardSet].
class AdminScreenMobile extends StatefulWidget {
  const AdminScreenMobile({super.key});

  @override
  State<AdminScreenMobile> createState() => _AdminScreenState();
}

/// Stavová trieda pre [AdminScreenMobile].
///
/// Obsahuje:
/// - správu vstupného poľa pre názov setu,
/// - zoznam načítaných verejných setov,
/// - metódy na vytváranie a načítanie setov cez API,
/// - UI pre tvorbu a správu setov.
class _AdminScreenState extends State<AdminScreenMobile> {
  /// Textový kontrolér pre názov nového setu.
  final TextEditingController _setNameController = TextEditingController();

  /// Zoznam všetkých verejných setov.
  List<FlashcardSet> publicSets = [];

  /// Vytvorí nový public set cez API a aktualizuje UI.
  Future<void> createPublicSet() async {
    final name = _setNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the name of the set')),
      );
      return;
    }

    try {
      final success = await ApiService().createPublicSet(name);
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Set created')));
        _setNameController.clear();
        fetchPublicSets();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to create')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  /// Načíta zoznam public setov z backendu a uloží ich do [publicSets].
  Future<void> fetchPublicSets() async {
    final rawSets = await ApiService().getPublicSets();
    final sets =
        rawSets
            .map<FlashcardSet>((json) => FlashcardSet.fromJson(json))
            .toList();
    setState(() => publicSets = sets);
  }

  @override
  void initState() {
    super.initState();
    fetchPublicSets();
  }

  /// Buduje používateľské rozhranie pre mobilnú verziu admin panelu.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create a new public set:',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _setNameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Set name',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: createPublicSet,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text('Create a set'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: fetchPublicSets,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondaryContainer,
                foregroundColor: theme.colorScheme.onSecondaryContainer,
              ),
              child: const Text('View public sets'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: publicSets.length,
                itemBuilder: (context, index) {
                  final set = publicSets[index];
                  return ListTile(
                    title: Text(set.name),
                    subtitle: Text('Set ID: ${set.setId}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () async {
                        final result = await Navigator.pushNamed(
                          context,
                          '/editset',
                          arguments: set,
                        );
                        if (result == true) fetchPublicSets();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
