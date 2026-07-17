/**
 * overnight-autoloop dedupKey / extractEvidenceLoc 단위테스트.
 * Workflow 스크립트는 async 래퍼+top-level return 이라 직접 import 불가 —
 * @@HELPERS_BEGIN@@…@@HELPERS_END@@ 블록을 추출해 vm 에서 실행한다.
 *
 * 실행: node --test plugins/workflow/skills/overnight-autoloop/autoloop.workflow.test.js
 */
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import test from 'node:test'
import vm from 'node:vm'

const dir = dirname(fileURLToPath(import.meta.url))
const src = readFileSync(join(dir, 'autoloop.workflow.js'), 'utf8')
const begin = src.indexOf('// @@HELPERS_BEGIN@@')
const end = src.indexOf('// @@HELPERS_END@@')
assert.ok(begin >= 0 && end > begin, 'HELPERS markers missing in autoloop.workflow.js')
const block = src
  .slice(begin, end)
  .replace(/^\/\/ @@HELPERS_BEGIN@@\s*/m, '')
  .replace(/\/\*\*[\s\S]*?\*\/\s*/g, '') // strip JSDoc
const sandbox = { exports: {} }
vm.runInNewContext(
  `${block}\nexports.extractEvidenceLoc = extractEvidenceLoc\nexports.dedupKey = dedupKey\n`,
  sandbox,
)
const { extractEvidenceLoc, dedupKey } = sandbox.exports
assert.equal(typeof extractEvidenceLoc, 'function')
assert.equal(typeof dedupKey, 'function')

test('(a) 같은 파일:라인 + 다른 title → 같은 키', () => {
  const a = {
    repo: 'yohan-mcp',
    title: 'timeout missing on notion call',
    evidence: 'adapters/notion_adapter.py:138 (json=timeout=None)',
  }
  const b = {
    repo: 'yohan-mcp',
    title: 'encoding bug in notion adapter',
    evidence: 'adapters/notion_adapter.py:138 — UnicodeDecodeError',
  }
  assert.equal(dedupKey(a), dedupKey(b))
  assert.equal(dedupKey(a), 'yohan-mcp|adapters/notion_adapter.py:138')
})

test('(b) 같은 파일 다른 라인 → 다른 키', () => {
  const a = {
    repo: 'yohan-mcp',
    title: 'bug A',
    evidence: 'adapters/notion_adapter.py:138 (x)',
  }
  const b = {
    repo: 'yohan-mcp',
    title: 'bug A',
    evidence: 'adapters/notion_adapter.py:200 (y)',
  }
  assert.notEqual(dedupKey(a), dedupKey(b))
  assert.equal(dedupKey(a), 'yohan-mcp|adapters/notion_adapter.py:138')
  assert.equal(dedupKey(b), 'yohan-mcp|adapters/notion_adapter.py:200')
})

test('(c) evidence 없음 → title 폴백', () => {
  const d = { repo: 'control-tower', title: '  Flaky Auth Redirect  ', evidence: '' }
  assert.equal(dedupKey(d), 'control-tower|title:flaky auth redirect')
  const d2 = { repo: 'control-tower', title: 'No Loc', evidence: 'no file path here, just a stack dump' }
  assert.equal(dedupKey(d2), 'control-tower|title:no loc')
})

test('(d) 백슬래시 정규화', () => {
  const d = {
    repo: 'yohan-mcp',
    title: 'win path',
    evidence: 'adapters\\notion_adapter.py:138 (json=...)',
  }
  assert.equal(extractEvidenceLoc(d.evidence), 'adapters/notion_adapter.py:138')
  assert.equal(dedupKey(d), 'yohan-mcp|adapters/notion_adapter.py:138')
})
