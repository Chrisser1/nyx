.pragma library

// Emoji search is plain substring matching: every word of the query must hit
// the name or a keyword. Name hits outrank keyword hits, and word starts
// outrank the middle of a word. Equal scores keep the incoming (recent-first)
// order, and an empty query lists everything.

function index(entries) {
  return entries.map(entry => ({
    name: ` ${entry.name.toLowerCase()}`,
    keywords: ` ${entry.comment.toLowerCase().replace(/, /g, " ")}`,
    entry
  }));
}

function score(item, word) {
  if (item.name.includes(` ${word}`)) return 0;
  if (item.name.includes(word)) return 1;
  if (item.keywords.includes(` ${word}`)) return 2;
  if (item.keywords.includes(word)) return 3;
  return -1;
}

function search(query, items, cap) {
  const words = query.toLowerCase().split(/\s+/).filter(Boolean);
  if (words.length === 0) return items.map(i => i.entry);
  const hits = [];
  for (let i = 0; i < items.length; i++) {
    let total = 0;
    for (const word of words) {
      const s = score(items[i], word);
      if (s < 0) { total = -1; break; }
      total += s;
    }
    if (total >= 0) hits.push({ total, i });
  }
  hits.sort((a, b) => a.total - b.total || a.i - b.i);
  return hits.slice(0, cap).map(h => items[h.i].entry);
}
