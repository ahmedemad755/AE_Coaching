String normalizeExerciseName(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll(RegExp(r'[\u0623\u0625\u0622\u0671]'), '\u0627')
      .replaceAll('\u0649', '\u064A')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}
