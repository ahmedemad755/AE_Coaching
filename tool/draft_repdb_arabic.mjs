// REJECTED quality experiment: initial fitness samples failed contextual review.
// Build-only drafting. Never writes app assets or marks text reviewed.
// Default: ten samples only; --all is an explicit experimental opt-in.
// npm install --prefix build/repdb-audit/translation-runtime @huggingface/transformers
import { readFile, writeFile, appendFile, mkdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { pipeline, env } from '../build/repdb-audit/translation-runtime/node_modules/@huggingface/transformers/dist/transformers.node.mjs';

const root = 'build/repdb-audit/arabic-drafts';
await mkdir(root, { recursive: true });
env.cacheDir = `${root}/model-cache`;
const model = 'Xenova/opus-mt-en-ar';
const metadata = await (await fetch(`https://huggingface.co/api/models/${model}`)).json();
if (!/^[a-f0-9]{40}$/.test(metadata.sha ?? '')) throw Error('No pinned model revision');
const modelCard = await (await fetch('https://huggingface.co/Helsinki-NLP/opus-mt-en-ar/raw/main/README.md')).text();
if (!modelCard.includes('license: apache-2.0')) throw Error('Translation model license not verified');
await writeFile(`${root}/MODEL-README.md`, modelCard);
await writeFile(`${root}/provenance.json`, JSON.stringify({ model, revision: metadata.sha,
  license: 'Apache-2.0 (Helsinki-NLP model card)', datasetCommit: '66c4298af8d99b9dc397dad6699e508fb871d249',
  status: 'machine_draft_NOT_REVIEWED', runtime: 'build-only; no app dependency, API, or model shipped' }, null, 2));
const source = JSON.parse(await readFile('lib/assets/repdb/exercises.json', 'utf8'));
const cachePath = `${root}/sentences.jsonl`;
const cache = new Map();
try { for (const line of (await readFile(cachePath, 'utf8')).trim().split('\n')) {
  if (line) { const row = JSON.parse(line); cache.set(row.en, row.ar); }
} } catch (error) { if (error.code !== 'ENOENT') throw error; }
const translate = await pipeline('translation', model, { revision: metadata.sha, dtype: 'q8', device: 'cpu' });
const allSentences = [...new Set(source.exercises.flatMap(e => [...e.instructions_en ?? [], ...e.tips_en ?? []]))];
const unique = process.argv.includes('--all') ? allSentences : allSentences.slice(0, 10);
for (let index = 0; index < unique.length; index++) {
  const en = unique[index];
  if (!cache.has(en)) {
    const result = await translate(`>>ara<< ${en}`, { max_new_tokens: 256, num_beams: 4 });
    const ar = result[0].translation_text;
    if (typeof ar !== 'string' || !ar.trim()) throw Error(`Empty translation: ${index}`);
    cache.set(en, ar);
    await appendFile(cachePath, `${JSON.stringify({ en, ar, sourceSha256: createHash('sha256').update(en).digest('hex') })}\n`);
  }
  if (index % 50 === 0) console.log(`Drafted ${index + 1}/${unique.length} unique instruction/tip sentences`);
}
const exercises = Object.fromEntries(source.exercises.map(e => [`repdb:${e.id}`, {
  instructions_ar: (e.instructions_en ?? []).map(en => cache.get(en)),
  tips_ar: (e.tips_en ?? []).map(en => cache.get(en)), review_status: 'machine_draft_NOT_REVIEWED',
}]));
await writeFile(`${root}/ar-instructions-draft.json`, JSON.stringify({ exercises }, null, 2));
console.log(`Drafts ready for contextual review: ${Object.keys(exercises).length} exercises. App assets unchanged.`);
