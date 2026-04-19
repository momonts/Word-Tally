import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'package:flutter/services.dart';

void main() {
  runApp(const WordTallyApp());
}

class WordTallyApp extends StatelessWidget {
  const WordTallyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Word Tally Counter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const WordTallyPage(),
    );
  }
}

class WordTallyPage extends StatefulWidget {
  const WordTallyPage({super.key});

  @override
  State<WordTallyPage> createState() => _WordTallyPageState();
}

class _WordTallyPageState extends State<WordTallyPage> {
  final TextEditingController _inputController = TextEditingController();

  String _normalizedText = '';
  List<WordCount> _results = const [];
  int _totalWords = 0;
  int _uniqueWords = 0;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_recompute);
  }

  @override
  void dispose() {
    _inputController
      ..removeListener(_recompute)
      ..dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final pasted = data?.text ?? '';
    if (!mounted) return;

    _inputController.text = pasted;
    _inputController.selection = TextSelection.collapsed(
      offset: _inputController.text.length,
    );
  }

  void _clearAll() {
    _inputController.clear();
  }

  void _downloadFile({
    required String fileName,
    required String content,
    required String mimeType,
  }) {
    final blob = web.Blob(
      [content.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName
      ..click();

    web.URL.revokeObjectURL(url);
  }

  String _buildTxtExport() {
    if (_results.isEmpty) return 'No word tally data available.';

    final buffer = StringBuffer()
      ..writeln('Word Tally Export')
      ..writeln('Total words: $_totalWords')
      ..writeln('Unique words: $_uniqueWords')
      ..writeln('')
      ..writeln('Rank	Word	Count');

    for (var i = 0; i < _results.length; i++) {
      final item = _results[i];
      buffer.writeln('${i + 1}	${item.word}	${item.count}');
    }

    return buffer.toString();
  }

  String _csvEscape(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _buildCsvExport() {
    if (_results.isEmpty) return 'rank,word,count';

    final buffer = StringBuffer()..writeln('rank,word,count');

    for (var i = 0; i < _results.length; i++) {
      final item = _results[i];
      buffer.writeln('${i + 1},${_csvEscape(item.word)},${item.count}');
    }

    return buffer.toString();
  }

  void _exportTxt() {
    _downloadFile(
      fileName: 'word_tally_export.txt',
      content: _buildTxtExport(),
      mimeType: 'text/plain;charset=utf-8',
    );
  }

  void _exportCsv() {
    _downloadFile(
      fileName: 'word_tally_export.csv',
      content: _buildCsvExport(),
      mimeType: 'text/csv;charset=utf-8',
    );
  }

  Future<void> _copyOutput() async {
    await Clipboard.setData(ClipboardData(text: _buildTxtExport()));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Output copied to clipboard.')),
    );
  }

  void _recompute() {
    final raw = _inputController.text;
    final normalized = _normalizeText(raw);
    final words = _extractWords(normalized);
    final counts = <String, int>{};

    for (final word in words) {
      counts[word] = (counts[word] ?? 0) + 1;
    }

    final results =
        counts.entries
            .map((entry) => WordCount(word: entry.key, count: entry.value))
            .toList()
          ..sort((a, b) {
            final byCount = b.count.compareTo(a.count);
            if (byCount != 0) return byCount;
            return a.word.compareTo(b.word);
          });

    setState(() {
      _normalizedText = normalized;
      _results = results;
      _totalWords = words.length;
      _uniqueWords = results.length;
    });
  }

  String _normalizeText(String input) {
    return input
        .replaceAll(RegExp(r'[\u00A0\u200B-\u200D\uFEFF]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _extractWords(String input) {
    if (input.isEmpty) return const [];

    final matches = RegExp(
      r"[A-Za-z0-9]+(?:['’-][A-Za-z0-9]+)*",
    ).allMatches(input.toLowerCase());

    return matches.map((match) => match.group(0)!).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 980;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Word Tally Counter'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paste text, normalize it into one line, then count how many times each word appears.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatCard(
                        label: 'Total words',
                        value: _totalWords.toString(),
                      ),
                      _StatCard(
                        label: 'Unique words',
                        value: _uniqueWords.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildInputPanel(context)),
                              const SizedBox(width: 20),
                              Expanded(child: _buildOutputPanel(context)),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(child: _buildInputPanel(context)),
                              const SizedBox(height: 20),
                              Expanded(child: _buildOutputPanel(context)),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputPanel(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Input', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Paste'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _clearAll,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _inputController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Paste any text here...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutputPanel(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Word tallies',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: _results.isEmpty ? null : _copyOutput,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy Output'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _results.isEmpty ? null : _exportTxt,
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Export TXT'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _results.isEmpty ? null : _exportCsv,
                  icon: const Icon(Icons.table_view_outlined),
                  label: const Text('Export CSV'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Sorted from most occurrences to least.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _results.isEmpty
                  ? const Center(child: Text('No words to show yet.'))
                  : Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          return ListTile(
                            leading: CircleAvatar(child: Text('${index + 1}')),
                            title: SelectableText(item.word),
                            trailing: Text(
                              item.count.toString(),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class WordCount {
  final String word;
  final int count;

  const WordCount({required this.word, required this.count});
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    );
  }
}
