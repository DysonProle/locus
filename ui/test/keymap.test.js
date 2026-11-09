import test from 'node:test'
import assert from 'node:assert/strict'
import { COMMAND_KEYS, CONSEQUENTIAL, HELP, KEYS, LAUNCH, MOTIONS, RESERVED, TOOL_KEYS, VIEW, bound, check, keysOf, lookup, parse, shown, spell } from '../src/keymap.js'

const sorted = (set) => [...set].sort()
const chars = (text) => sorted(new Set(text))

test('the key sets are worked out from the tables', () => {
  assert.deepEqual(sorted(RESERVED), chars('hjklHJKLgGsSaioxcvzZ.npmwedDCM;/? '))
  assert.deepEqual(sorted(CONSEQUENTIAL), chars('AR'))
  assert.deepEqual(sorted(COMMAND_KEYS), chars('tubqyYrXIOVTP<>'))
  assert.equal(TOOL_KEYS.join(''), 'BEFNQUWf0123456789')
})

test('a key means one thing wherever it shows', () => {
  for (const key of Object.keys(LAUNCH)) assert.ok(!Object.hasOwn(KEYS, key), `${key} opens ${LAUNCH[key]}`)
  for (const [command, key] of Object.entries(VIEW)) {
    assert.ok(!Object.hasOwn(KEYS, key) && !Object.hasOwn(LAUNCH, key), `${command} on ${key}`)
  }
})

test('a consequential key is used only by consequential commands', () => {
  for (const [command, key] of Object.entries(VIEW)) {
    assert.equal(CONSEQUENTIAL.has(key), ['approve', 'reject', 'send'].includes(command), command)
  }
})

test('a press is spelled one way, and the spelling reads back', () => {
  const cases = [
    [{ key: 'h' }, 'h'],
    [{ key: 'H', shift: true }, 'H'],
    [{ key: '?', shift: true }, '?'],
    [{ key: ' ' }, 'Space'],
    [{ key: ' ', shift: true }, 'S-Space'],
    [{ key: 'h', alt: true }, 'M-h'],
    [{ key: 'ArrowLeft', alt: true, shift: true }, 'M-S-ArrowLeft'],
    [{ key: '-', alt: true }, 'M--'],
    [{ key: 'S' }, 'S'],
    [{ key: 'M' }, 'M'],
  ]
  for (const [k, spelling] of cases) {
    assert.equal(spell(k), spelling)
    assert.equal(spell(parse(spelling)), spelling)
    assert.equal(parse(spelling).key, k.key)
    assert.equal(parse(spelling).alt, !!k.alt)
  }
})

test('a table with a key written another way is refused', () => {
  for (const key of ['S-h', 'S-?', 'S-M-h', 'M-S-h', ' ', 'C-x', 's-x', 'A-h', 'ab', 'M-', '']) {
    assert.throws(() => check({ [key]: 'left' }), /is not how a key is written/, key)
  }
  assert.throws(() => check({ h: '' }), /needs a command or a table/)
  assert.throws(() => check({ h: null }), /needs a command or a table/)
  assert.throws(() => check({ ',': { 'S-b': 'cut' } }), /", S-b" is not how a key is written/)
  assert.doesNotThrow(() => check({ 'M-S-Enter': 'left', F2: 'left', 'M--': 'left', ',': { b: 'cut', 'M-x': { y: 'copy' } } }))
})

test('lookup follows the modifiers', () => {
  assert.equal(lookup({ key: 'h' }), 'left')
  assert.equal(lookup({ key: 'H', shift: true }), 'bigLeft')
  assert.equal(lookup({ key: ' ' }), 'activate')
  assert.equal(lookup({ key: ' ', shift: true }), 'newTile')
  assert.equal(lookup({ key: 'h', alt: true }), 'tileLeft')
  assert.equal(lookup({ key: 'h', alt: true, shift: true }), 'tileLeft')
  assert.equal(lookup({ key: 'x', alt: true }), null)
  assert.equal(lookup({ key: 'h', ctrl: true }), null)
  assert.equal(lookup({ key: 'ArrowLeft' }), 'left')
  assert.equal(lookup({ key: 'ArrowLeft', shift: true }), 'bigLeft')
  assert.equal(lookup({ key: 'ArrowLeft', alt: true }), 'tileLeft')
  assert.equal(lookup({ key: 'constructor' }), null)
  assert.equal(lookup({ key: 'n' }), null)
})

test('Shift with nothing of its own is the key without it', () => {
  assert.equal(lookup({ key: 'Enter', shift: true }), 'activate')
  assert.equal(lookup({ key: 'Escape', shift: true }), 'back')
  assert.equal(lookup({ key: 'ArrowLeft', alt: true, shift: true }), 'tileLeft')
  assert.equal(bound({ key: 'Enter', shift: true }), 'Enter')
  assert.equal(bound({ key: ' ', shift: true }), 'S-Space')
})

test('a key can lead to a table of the keys that follow', () => {
  const keys = { ',': { b: 'cut', 'S-Space': 'copy', ',': { b: 'paste' } }, b: 'undo' }
  const inner = lookup({ key: ',' }, keys)
  assert.equal(lookup({ key: 'b' }, keys), 'undo')
  assert.equal(lookup({ key: 'b' }, inner), 'cut')
  assert.equal(lookup({ key: ' ', shift: true }, inner), 'copy')
  assert.equal(lookup({ key: 'b' }, lookup({ key: ',' }, inner)), 'paste')
  assert.equal(lookup({ key: 'x' }, inner), null)
})

test('every motion has a key', () => {
  for (const m of MOTIONS) assert.notEqual(keysOf(m), '', m)
  assert.equal(KEYS['S-Space'], 'newTile')
  assert.equal(KEYS['M-q'], 'closeTile')
})

test('keys are shown the way the interface writes them', () => {
  assert.equal(shown('h'), 'h')
  assert.equal(shown('Escape'), 'Esc')
  assert.equal(shown('S-Space'), '⇧ Space')
  assert.equal(shown('M-S-ArrowLeft'), 'Alt ⇧ ArrowLeft')
  assert.equal(keysOf('left', 'down'), 'h j')
  assert.equal(keysOf('tileLeft', 'tileDown'), 'Alt h j')
  assert.equal(keysOf('left', 'tileLeft'), 'h Alt h')
  assert.equal(keysOf('noSuchCommand'), '')
})

test('the ? panel lists these keys', () => {
  assert.deepEqual(HELP, [
    ['Move', [['h j k l', 'left, down, up, right'], ['← ↓ ↑ →', 'the same, with ⇧ and Alt too'], ['H J K L', 'a big step'], ['g G', 'start, end'], ['/', 'find here']]],
    ['In and out', [['Space Enter', 'open, play, tick'], ['Esc', 'back'], ['⇧ Space', 'open in a new tile']]],
    ['Select', [['s', 'mark one'], ['S', 'start a range'], ['a', 'all']]],
    ['Verbs', [['i', 'edit'], ['o', 'new'], ['x', 'cut'], ['c', 'copy'], ['v', 'paste'], ['z Z', 'undo, redo'], ['.', 'repeat']]],
    ['Apps', [['n', 'Notes'], ['p', 'Photos'], ['m', 'Music'], ['w', 'Movies'], ['e', 'People'], ['C', 'Calendar'], ['M', 'Messages'], ['d', 'Inbox'], ['D', 'Tools']]],
    ['Everything else', [[';', 'command, or ask the agent'], ['A R', 'approve, reject'], ['Alt h j k l', 'between tiles'], ['Alt q', 'close a tile']]],
  ])
})
