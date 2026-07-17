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

test('(e) .sh / 무확장자 Dockerfile — 같은위치 다른 title → 같은 키', () => {
  const shA = { repo: 'yohan-mcp', title: 'shell timeout', evidence: 'scripts/run.sh:12 missing set -e' }
  const shB = { repo: 'yohan-mcp', title: 'shell quoting', evidence: 'scripts/run.sh:12 bad quote' }
  assert.equal(dedupKey(shA), dedupKey(shB))
  assert.equal(dedupKey(shA), 'yohan-mcp|scripts/run.sh:12')

  const dfA = { repo: 'yohan-mcp', title: 'base image pin', evidence: 'deploy/Dockerfile:3 FROM latest' }
  const dfB = { repo: 'yohan-mcp', title: 'apt cache', evidence: 'deploy/Dockerfile:3 RUN apt' }
  assert.equal(dedupKey(dfA), dedupKey(dfB))
  assert.equal(dedupKey(dfA), 'yohan-mcp|deploy/dockerfile:3')
})

test('(f) 긴 경로 :10 vs :99 → 다른 키 (라인번호 보존)', () => {
  const long = 'a'.repeat(110) + '/deep/file.py'
  const a = { repo: 'r', title: 't', evidence: `${long}:10 oops` }
  const b = { repo: 'r', title: 't', evidence: `${long}:99 oops` }
  assert.notEqual(dedupKey(a), dedupKey(b))
  assert.ok(dedupKey(a).endsWith(':10'), `expected :10 suffix, got ${dedupKey(a)}`)
  assert.ok(dedupKey(b).endsWith(':99'), `expected :99 suffix, got ${dedupKey(b)}`)
})

test('(g) C:\\ vs D:\\ 같은 상대경로 → 다른 키 (드라이브 구분)', () => {
  const c = { repo: 'r', title: 't', evidence: 'C:\\a\\b.py:1 err' }
  const d = { repo: 'r', title: 't', evidence: 'D:\\a\\b.py:1 err' }
  assert.equal(extractEvidenceLoc(c.evidence), 'c:/a/b.py:1')
  assert.equal(extractEvidenceLoc(d.evidence), 'd:/a/b.py:1')
  assert.notEqual(dedupKey(c), dedupKey(d))
})

test('(h) 둘째 줄 경로 추출', () => {
  const d = {
    repo: 'yohan-mcp',
    title: 'buried path',
    evidence: 'stack dump with no path on line 1\nadapters/notion_adapter.py:138 (json=...)',
  }
  assert.equal(extractEvidenceLoc(d.evidence), 'adapters/notion_adapter.py:138')
  assert.equal(dedupKey(d), 'yohan-mcp|adapters/notion_adapter.py:138')
})

test('(i) 산문 read/write 보다 :라인 경로 우선 — 서로 다른 키', () => {
  const a = { repo: 'r', title: 'rw a', evidence: 'read/write failure; src/a.py:10' }
  const b = { repo: 'r', title: 'rw b', evidence: 'read/write failure; src/b.py:20' }
  assert.equal(extractEvidenceLoc(a.evidence), 'src/a.py:10')
  assert.equal(extractEvidenceLoc(b.evidence), 'src/b.py:20')
  assert.notEqual(dedupKey(a), dedupKey(b))
  assert.equal(dedupKey(a), 'r|src/a.py:10')
  assert.equal(dedupKey(b), 'r|src/b.py:20')
})

test('(j) 산문 Node.js 보다 :라인 경로 우선', () => {
  const d = { repo: 'r', title: 'node', evidence: 'Node.js failure; src/a.py:10' }
  assert.equal(extractEvidenceLoc(d.evidence), 'src/a.py:10')
  assert.equal(dedupKey(d), 'r|src/a.py:10')
})

test('(k) 루트 Dockerfile:7 다른 title → 같은 키', () => {
  const a = { repo: 'r', title: 'base image', evidence: 'Dockerfile:7 FROM latest' }
  const b = { repo: 'r', title: 'apt layer', evidence: 'Dockerfile:7 RUN apt-get' }
  assert.equal(extractEvidenceLoc(a.evidence), 'dockerfile:7')
  assert.equal(dedupKey(a), dedupKey(b))
  assert.equal(dedupKey(a), 'r|dockerfile:7')
})
