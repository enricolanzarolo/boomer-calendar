import 'package:flutter/material.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _TutorialPage(
      emoji: '👋',
      title: 'Benvenuta!',
      description:
          'Questo è il tuo calendario personale.\nQui puoi tenere traccia di tutto quello che devi fare, senza perdere niente!',
      color: Color(0xFF6C63FF),
    ),
    _TutorialPage(
      emoji: '➕',
      title: 'Come aggiungere un evento',
      description:
          'Premi il grande pulsante "Nuovo evento" in basso.\nScrivi il nome, scegli il giorno e l\'ora, e premi "Salva".\nFacile!',
      color: Color(0xFF4FC3F7),
    ),
    _TutorialPage(
      emoji: '📅',
      title: 'Le tre viste del calendario',
      description:
          'In alto puoi scegliere tra:\n• GIORNO: vedi solo oggi\n• SETTIMANA: vedi 7 giorni\n• MESE: vedi il mese intero\nI pallini colorati indicano che hai eventi quel giorno.',
      color: Color(0xFF81C784),
    ),
    _TutorialPage(
      emoji: '🎨',
      title: 'I colori delle categorie',
      description:
          'Ogni evento ha un colore diverso secondo la categoria.\nBlu = Famiglia, Viola = Personale, Verde = Salute...\nPuoi anche creare le tue categorie con il colore che vuoi!',
      color: Color(0xFFBA68C8),
    ),
    _TutorialPage(
      emoji: '🔔',
      title: 'Le notifiche promemoria',
      description:
          'Quando crei un evento puoi scegliere quando vuoi essere avvisata.\nPuoi ricevere l\'avviso 5 minuti prima, 1 ora prima, o anche il giorno prima.\nNon dimenticherai più niente!',
      color: Color(0xFFFFB74D),
    ),
    _TutorialPage(
      emoji: '✏️',
      title: 'Modificare o cancellare',
      description:
          'Tocca un evento per modificarlo.\nPer cancellarlo, fai scorrere il dito da destra a sinistra sull\'evento e poi tocca "Elimina".',
      color: Color(0xFFFF8A65),
    ),
    _TutorialPage(
      emoji: '☁️',
      title: 'Il backup',
      description:
          'Vai nelle Impostazioni (rotellina in alto a destra) e premi "Salva backup".\nI tuoi dati verranno salvati su Google Drive.\nSe cambi telefono, premi "Ripristina" e ritroverai tutto!',
      color: Color(0xFF4FC3F7),
    ),
    _TutorialPage(
      emoji: '🌙',
      title: 'Tema chiaro o scuro',
      description:
          'Nelle Impostazioni puoi cambiare il colore dell\'app.\nSe la luce dello schermo ti dà fastidio di sera, attiva il "Tema scuro"!',
      color: Color(0xFF78909C),
    ),
    _TutorialPage(
      emoji: '🌸',
      title: 'Sei pronta!',
      description:
          'Ora sai tutto quello che ti serve.\nBuona organizzazione! Se hai bisogno, torna qui quando vuoi dalla rotellina → ?',
      color: Color(0xFF6C63FF),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Come si usa l\'app'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── Pagine ────────────────────────────────
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemCount: _pages.length,
              itemBuilder: (context, i) => _pages[i],
            ),
          ),

          // ── Indicatori pagina ─────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
                width: _currentPage == i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == i
                      ? _pages[i].color
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          // ── Bottoni navigazione ────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Row(
              children: [
                if (_currentPage > 0)
                  OutlinedButton(
                    onPressed: () =>
                        _controller.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('◀ Indietro',
                        style: TextStyle(fontSize: 16)),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _pages.length - 1) {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: Text(
                    _currentPage < _pages.length - 1
                        ? 'Avanti ▶'
                        : '✅ Ho capito!',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialPage extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;
  final Color color;

  const _TutorialPage({
    required this.emoji,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Cerchio grande con emoji
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 64)),
            ),
          ),

          const SizedBox(height: 40),

          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),

          const SizedBox(height: 20),

          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
            ),
          ),
        ],
      ),
    );
  }
}
