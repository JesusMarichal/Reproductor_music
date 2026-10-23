/// Minúsculas y sin acentos, para comparar textos: "Angèle" → "angele".
String foldText(String text) {
  const from = 'àáâãäåèéêëìíîïòóôõöùúûüýÿñç';
  const to = 'aaaaaaeeeeiiiiooooouuuuyync';
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final i = from.indexOf(char);
    buffer.write(i == -1 ? char : to[i]);
  }
  return buffer.toString();
}

/// Palabras de [text] ya normalizadas con [foldText], sin signos.
List<String> foldedWords(String text) => foldText(text)
    .replaceAll(RegExp(r"[^\p{L}\p{N}' ]", unicode: true), ' ')
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .toList();
