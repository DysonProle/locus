// Every key the interface binds outside typing, as data. The engine looks a key
// up here and runs the command it names. The key sets and the ? panel below are
// worked out from this table, so they can't disagree with what the keys do.
// Typing, the command bar and find take text, and read their few keys directly.
//
// A key is written the way Emacs writes one: the key, with M- in front for Alt
// and S- for Shift, in that order. A character is its own key (h, H, ?), so S-
// only goes on keys that have a name: S-Space, M-S-ArrowLeft. Names are the
// browser's, with Space for the space bar. Ctrl and the system key are left to
// the browser, so nothing here can bind them.
//
// A key leads to a command, or to another table of the keys that can follow it.

// Motions are named for their role, and each view decides what one means: a big
// step left is the start of a row on a grid, a word in text, a week in the calendar.
export const MOTIONS = new Set(['left', 'down', 'up', 'right', 'bigLeft', 'bigDown', 'bigUp', 'bigRight', 'start', 'end'])

export const KEYS = {
  h: 'left', j: 'down', k: 'up', l: 'right',
  H: 'bigLeft', J: 'bigDown', K: 'bigUp', L: 'bigRight',
  g: 'start', G: 'end',
  Space: 'activate', Escape: 'back',
  s: 'mark', S: 'range', a: 'all',
  i: 'edit', o: 'create',
  x: 'cut', c: 'copy', v: 'paste', z: 'undo', Z: 'redo', '.': 'repeat',
  ';': 'bar', '?': 'help', '/': 'find',
  ArrowLeft: 'left', ArrowDown: 'down', ArrowUp: 'up', ArrowRight: 'right',
  Enter: 'activate',
  'S-Space': 'newTile',
  'S-ArrowLeft': 'bigLeft', 'S-ArrowDown': 'bigDown', 'S-ArrowUp': 'bigUp', 'S-ArrowRight': 'bigRight',
  'M-h': 'tileLeft', 'M-j': 'tileDown', 'M-k': 'tileUp', 'M-l': 'tileRight', 'M-q': 'closeTile',
  'M-ArrowLeft': 'tileLeft', 'M-ArrowDown': 'tileDown', 'M-ArrowUp': 'tileUp', 'M-ArrowRight': 'tileRight',
}

// Each opens the Home item whose launch field is that key.
export const LAUNCH = {
  n: 'Notes', p: 'Photos', m: 'Music', w: 'Movies', e: 'People',
  C: 'Calendar', M: 'Messages', d: 'Inbox', D: 'Tools',
}

// The key for each view's own commands. Views that never show together can share
// one: t is Today in the calendar and To-do in a note.
export const VIEW = {
  today: 't', endLess: '<', endMore: '>', repeat: 'y',
  rotate: 'r', crop: 'X', uncrop: 'u',
  kindT: 't', kindH: 'b', kindP: 'q',
  sortName: 'y', sortReverse: 'Y',
  approve: 'A', reject: 'R', send: 'A', setPeer: 'P',
  revert: 'u', restore: 'u',
  keepTheirs: 'O', keepMine: 'V',
  info: 'I', newTile: 'T',
}

// ---------- Spelling ----------

// How a press is written: 'h', 'S-Space', 'M-ArrowLeft'.
export function spell(k) {
  const name = k.key === ' ' ? 'Space' : k.key
  return (k.alt ? 'M-' : '') + (k.shift && name.length > 1 ? 'S-' : '') + name
}

// The press a spelling stands for.
export function parse(spelling) {
  let key = spelling
  const cut = (mark) => {
    if (key.length < 3 || !key.startsWith(mark)) return false
    key = key.slice(2)
    return true
  }
  const alt = cut('M-')
  const shift = cut('S-')
  return { key: key === 'Space' ? ' ' : key, alt, shift }
}

// Every key has one spelling, and a table that uses another would hold a
// binding that never fires. This refuses such a table.
const NAMED = /^[A-Z][A-Za-z0-9]+$/
export function check(table, before = []) {
  for (const [spelling, to] of Object.entries(table)) {
    const at = [...before, spelling]
    const k = parse(spelling)
    if (spell(k) !== spelling || !(k.key.length === 1 || NAMED.test(k.key))) throw new Error(`Key table: "${at.join(' ')}" is not how a key is written.`)
    if (typeof to === 'string' ? !to : !to || typeof to !== 'object') throw new Error(`Key table: "${at.join(' ')}" needs a command or a table.`)
    if (typeof to !== 'string') check(to, at)
  }
  return table
}
check(KEYS)

// How this table spells a press, or null when it has nothing for it. Shift with
// nothing of its own falls back to the key without it, so Shift+Enter is Enter.
export function bound(k, table = KEYS) {
  if (k.ctrl) return null
  const spelling = spell(k)
  if (Object.hasOwn(table, spelling)) return spelling
  const plain = spell({ ...k, shift: false })
  return k.shift && Object.hasOwn(table, plain) ? plain : null
}

// What a press leads to in this table: a command, a table of the keys that can
// follow, or null.
export function lookup(k, table = KEYS) {
  const spelling = bound(k, table)
  return spelling ? table[spelling] : null
}

export const isLaunch = (key) => Object.hasOwn(LAUNCH, key)

// ---------- Key sets ----------

const plainKeys = Object.keys(KEYS).map(parse).filter((k) => !k.alt && !k.shift).map((k) => k.key)
export const RESERVED = new Set([...plainKeys, ...Object.keys(LAUNCH)].filter((c) => c.length === 1))

// These commit something that can't be taken back with a keystroke. They are
// never reused for anything else, so muscle memory can't fire one by accident.
export const CONSEQUENTIAL = new Set(['approve', 'reject', 'send'].map((c) => VIEW[c]))

// Keys the interface's own commands use in some view. A learned tool never takes
// one of these or a reserved key, so a key means one thing wherever it shows.
export const COMMAND_KEYS = new Set(Object.values(VIEW).filter((c) => !CONSEQUENTIAL.has(c)))

export const TOOL_KEYS = [...'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789']
  .filter((c) => !RESERVED.has(c) && !COMMAND_KEYS.has(c) && !CONSEQUENTIAL.has(c))

// ---------- Showing keys ----------

const NAMES = { ' ': 'Space', Escape: 'Esc' }
const held = (k) => (k.alt ? 'Alt ' : '') + (k.shift ? '⇧ ' : '')
const name = (k) => NAMES[k.key] ?? k.key

// A key as the interface writes it: 'Alt h', '⇧ Space', 'Esc'.
export const shown = (spelling) => held(parse(spelling)) + name(parse(spelling))

// The keys for these commands, as the interface writes them: 'h j k l'. Keys
// held the same way say so once: 'Alt h j k l'.
export function keysOf(...commands) {
  const keys = commands.map((c) => Object.keys(KEYS).find((spelling) => KEYS[spelling] === c)).filter(Boolean).map(parse)
  const same = keys.every((k) => held(k) === held(keys[0]))
  return same && keys.length ? held(keys[0]) + keys.map(name).join(' ') : keys.map((k) => held(k) + name(k)).join(' ')
}

const row = (commands, what) => [keysOf(...commands.split(' ')), what]

// The grammar at a glance, for the ? panel.
export const HELP = [
  ['Move', [
    row('left down up right', 'left, down, up, right'),
    ['← ↓ ↑ →', 'the same, with ⇧ and Alt too'],
    row('bigLeft bigDown bigUp bigRight', 'a big step'),
    row('start end', 'start, end'),
    row('find', 'find here'),
  ]],
  ['In and out', [
    [`${keysOf('activate')} Enter`, 'open, play, tick'],
    row('back', 'back'),
    row('newTile', 'open in a new tile'),
  ]],
  ['Select', [row('mark', 'mark one'), row('range', 'start a range'), row('all', 'all')]],
  ['Verbs', [
    row('edit', 'edit'), row('create', 'new'), row('cut', 'cut'), row('copy', 'copy'),
    row('paste', 'paste'), row('undo redo', 'undo, redo'), row('repeat', 'repeat'),
  ]],
  ['Apps', Object.entries(LAUNCH)],
  ['Everything else', [
    row('bar', 'command, or ask the agent'),
    [`${VIEW.approve} ${VIEW.reject}`, 'approve, reject'],
    row('tileLeft tileDown tileUp tileRight', 'between tiles'),
    row('closeTile', 'close a tile'),
  ]],
]
