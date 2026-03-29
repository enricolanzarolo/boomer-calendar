import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/gestore_database.dart';
import '../models/models.dart';
import '../schermate/modulo_evento.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  List<Event> _results = [];
  List<Category> _cats = [];
  bool _searched = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCats();
  }

  Future<void> _loadCats() async {
    final cats = await DatabaseHelper.instance.getCategories();
    if (mounted) setState(() => _cats = cats);
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _results = []; _searched = false; });
      return;
    }
    setState(() => _loading = true);
    final all = await DatabaseHelper.instance.getAllEvents();
    final q = query.toLowerCase().trim();
    final found = all.where((e) =>
      e.title.toLowerCase().contains(q) ||
      (e.description?.toLowerCase().contains(q) ?? false)
    ).toList();
    if (mounted) setState(() { _results = found; _searched = true; _loading = false; });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            hintText: 'Cerca un evento...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4)),
          ),
          onChanged: _search,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(icon: const Icon(Icons.clear),
                onPressed: () { _ctrl.clear(); _search(''); }),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_searched
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🔍', style: TextStyle(fontSize: 52)),
                  const SizedBox(height: 12),
                  Text('Scrivi per cercare un evento', style: TextStyle(fontSize: 17,
                      color: theme.colorScheme.onSurface.withOpacity(0.4))),
                ]))
              : _results.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('😕', style: TextStyle(fontSize: 52)),
                      const SizedBox(height: 12),
                      Text('Nessun evento trovato\nper "${_ctrl.text}"',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 17,
                              color: theme.colorScheme.onSurface.withOpacity(0.45))),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _results.length,
                      itemBuilder: (_, i) {
                        final ev = _results[i];
                        final cat = _cats.firstWhere(
                          (c) => c.id == ev.categoryId,
                          orElse: () => _cats.isNotEmpty
                              ? _cats.first
                              : const Category(name: 'Varie', colorValue: 0xFF90A4AE));
                        final col = cat.color;
                        final bgCol = Color.lerp(col, Colors.white,
                            theme.brightness == Brightness.dark ? 0.75 : 0.82)!;

                        return GestureDetector(
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(
                                builder: (_) => EventFormScreen(event: ev, initialDate: ev.startTime)));
                            _search(_ctrl.text);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: bgCol,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: col.withOpacity(0.3), width: 1.5),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              // Data
                              Text(_formatDate(ev.startTime), style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600,
                                  color: col.withOpacity(0.7))),
                              const SizedBox(height: 4),
                              // Titolo + categoria
                              Row(children: [
                                Expanded(child: Text(ev.title, style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700,
                                    color: col.withOpacity(0.85)),
                                  maxLines: 1, overflow: TextOverflow.ellipsis)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                      color: col.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Text(cat.name, style: TextStyle(
                                      color: col, fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                              ]),
                              if (ev.description != null && ev.description!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(ev.description!, style: TextStyle(fontSize: 13,
                                    color: col.withOpacity(0.6)),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                              const SizedBox(height: 6),
                              Text(DateFormat('HH:mm', 'it_IT').format(ev.startTime),
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                      color: col.withOpacity(0.65))),
                            ]),
                          ),
                        );
                      },
                    ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) return '📅 Oggi';
    final f = DateFormat('EEEE d MMMM yyyy', 'it_IT').format(dt);
    return '📅 ${f[0].toUpperCase()}${f.substring(1)}';
  }
}
