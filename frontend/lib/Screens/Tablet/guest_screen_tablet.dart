import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../main.dart';

/// Obrazovka režimu hosťa (Guest Mode) pre tabletove zariadenia.
///
/// Umožňuje hosťovskému používateľovi zobraziť zoznam verejných sád.
/// Používateľ si môže sady obnoviť, prezerať a vstúpiť do režimu učenia.
/// Zároveň má prístup k nastaveniam aplikácie.
class GuestScreenTablet extends StatefulWidget {
  const GuestScreenTablet({super.key});

  @override
  State<GuestScreenTablet> createState() => _GuestScreenState();
}

class _GuestScreenState extends State<GuestScreenTablet> {
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
    final isLargeText = MyApp.of(context)?.isLargeText ?? false;
    final isTablet = MediaQuery.of(context).size.width >= 800;
    final double textScale = isLargeText ? 1.3 : 1.0;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaleFactor: textScale),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Guest Mode',
            style: TextStyle(fontSize: isLargeText ? 30 : 22),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.settings, size: isLargeText ? 34 : 28),
              onPressed: () {
                Navigator.pushNamed(context, '/settings');
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child:
              isTablet
                  ? Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ElevatedButton(
                              onPressed: fetchPublicSets,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    theme.colorScheme.secondaryContainer,
                                foregroundColor:
                                    theme.colorScheme.onSecondaryContainer,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                              ),
                              child: Text(
                                'Refresh public sets',
                                style: TextStyle(
                                  fontSize: isLargeText ? 22 : 18,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Available public sets:',
                              style: TextStyle(
                                fontSize: isLargeText ? 22 : 18,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        flex: 5,
                        child:
                            publicSets.isEmpty
                                ? Center(
                                  child: Text(
                                    'No Sets Available',
                                    style: TextStyle(
                                      fontSize: isLargeText ? 22 : 18,
                                    ),
                                  ),
                                )
                                : ListView.separated(
                                  itemCount: publicSets.length,
                                  separatorBuilder: (_, __) => const Divider(),
                                  itemBuilder: (context, index) {
                                    final set = publicSets[index];
                                    return ListTile(
                                      title: Text(
                                        set['name'],
                                        style: TextStyle(
                                          fontSize: isLargeText ? 20 : 16,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Set ID: ${set['set_id']}',
                                      ),
                                      trailing: const Icon(
                                        Icons.arrow_forward_ios,
                                      ),
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
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: ElevatedButton(
                          onPressed: fetchPublicSets,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                theme.colorScheme.secondaryContainer,
                            foregroundColor:
                                theme.colorScheme.onSecondaryContainer,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                          child: Text(
                            'Refresh public sets',
                            style: TextStyle(fontSize: isLargeText ? 20 : 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Available public sets:',
                        style: TextStyle(
                          fontSize: isLargeText ? 22 : 18,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child:
                            publicSets.isEmpty
                                ? Center(
                                  child: Text(
                                    'No Sets Available',
                                    style: TextStyle(
                                      fontSize: isLargeText ? 20 : 16,
                                    ),
                                  ),
                                )
                                : ListView.builder(
                                  itemCount: publicSets.length,
                                  itemBuilder: (context, index) {
                                    final set = publicSets[index];
                                    return ListTile(
                                      title: Text(
                                        set['name'],
                                        style: TextStyle(
                                          fontSize: isLargeText ? 20 : 16,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Set ID: ${set['set_id']}',
                                      ),
                                      trailing: const Icon(
                                        Icons.arrow_forward_ios,
                                      ),
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
      ),
    );
  }
}
