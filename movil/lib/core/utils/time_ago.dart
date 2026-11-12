/// «unos segundos», «5 min», «3 h», «2 días»: antigüedad legible de un dato.
String timeAgo(DateTime savedAt, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(savedAt);
  if (diff.inMinutes < 1) return 'unos segundos';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours} h';
  final days = diff.inDays;
  return '$days día${days == 1 ? '' : 's'}';
}
