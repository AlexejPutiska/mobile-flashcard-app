import 'package:flutter/material.dart';
import '../../api_service.dart';

/// Obrazovka režimu hosťa (Guest Mode) pre mobilné zariadenia.
///
/// Umožňuje hosťovskému používateľovi zobraziť zoznam verejných sád.
/// Používateľ si môže sady obnoviť, prezerať a vstúpiť do režimu učenia.
/// Zároveň má prístup k nastaveniam aplikácie.
class GuestScreenMobile extends StatefulWidget {
  const GuestScreenMobile({super.key});

  @override
  State<GuestScreenMobile> createState() => _GuestScreenState();
}

class _GuestScreenState extends State<GuestScreenMobile> {
  List<dynamic> publicSets = [];

  /// Inicializuje stav obrazovky a načíta zoznam verejných sád po načítaní widgetu.
  @override
  void initState() {
    super.initState();
    fetchPublicSets();
  }

  /// Načíta zoznam verejných sád flashkariet pomocou `ApiService.getPublicSets`.
  ///
  /// V prípade chyby zobrazí upozornenie pomocou `SnackBar`.
  Future<void> fetchPublicSets() async {
    try {
      final sets = await ApiService().getPublicSets();
      setState(() {
        publicSets = sets;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error with loading Sets: $e')));
    }
  }

  /// Odhlási používateľa v režime hosťa a presmeruje ho na prihlasovaciu obrazovku.
  Future<void> _logout() async {
    await ApiService().logout();
    Navigator.pushReplacementNamed(context, '/login');
  }

  /// Vytvára a vracia vizuálne rozhranie obrazovky pre režim hosťa.
  ///
  /// Obsahuje:
  /// - Tlačidlo na obnovenie verejných sád
  /// - Zoznam dostupných verejných sád (alebo hlášku o ich neprítomnosti)
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guest Mode'),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ElevatedButton(
                onPressed: fetchPublicSets,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  foregroundColor: theme.colorScheme.onSecondaryContainer,
                ),
                child: const Text('Refresh public sets'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Available public sets:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),

            Expanded(
              child:
                  publicSets.isEmpty
                      ? const Center(child: Text('No Sets Available'))
                      : ListView.builder(
                        itemCount: publicSets.length,
                        itemBuilder: (context, index) {
                          final set = publicSets[index];
                          return ListTile(
                            title: Text(set['name']),
                            subtitle: Text('Set ID: ${set['set_id']}'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/learn',
                                arguments: set['set_id'],
                              );
                            },
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
