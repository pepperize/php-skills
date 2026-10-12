import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { after, before, test } from "node:test";
import CodexCliAuthProvider from "./codex-cli-auth.mjs";

let fixtureDirectory;
let provider;

before(() => {
  fixtureDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "php-skills-token-usage-"));
  const sdkPath = path.join(fixtureDirectory, "codex-sdk.mjs");
  fs.writeFileSync(sdkPath, `
    export class Codex {
      startThread() {
        return {
          id: "token-usage-test",
          async run(prompt) {
            return JSON.parse(prompt);
          },
        };
      }
    }
  `);
  provider = new CodexCliAuthProvider({
    config: { codex_sdk_path: sdkPath, codex_home: fixtureDirectory },
  });
});

after(() => {
  if (fixtureDirectory) {
    fs.rmSync(fixtureDirectory, { recursive: true, force: true });
  }
});

for (const { name, usage, expected } of [
  {
    name: "cached input remains a subset of prompt tokens",
    usage: { input_tokens: 5000, cached_input_tokens: 1500, output_tokens: 900 },
    expected: { prompt: 5000, completion: 900, cached: 1500, total: 5900 },
  },
  {
    name: "fully cached input is counted once",
    usage: { input_tokens: 5000, cached_input_tokens: 5000, output_tokens: 900 },
    expected: { prompt: 5000, completion: 900, cached: 5000, total: 5900 },
  },
  {
    name: "uncached input retains its prompt and completion counts",
    usage: { input_tokens: 5000, cached_input_tokens: 0, output_tokens: 900 },
    expected: { prompt: 5000, completion: 900, cached: 0, total: 5900 },
  },
  {
    name: "missing cache and completion counters default to zero",
    usage: { input_tokens: 5000 },
    expected: { prompt: 5000, completion: 0, cached: 0, total: 5000 },
  },
  {
    name: "absent usage is not reported as zero usage",
    usage: undefined,
    expected: undefined,
  },
  {
    name: "null usage is not reported as zero usage",
    usage: null,
    expected: undefined,
  },
]) {
  test(name, async () => {
    const response = await provider.callApi(JSON.stringify({ finalResponse: "fixture", usage }));

    assert.equal(response.error, undefined);
    assert.equal(response.output, "fixture");
    assert.deepEqual(response.tokenUsage, expected);
  });
}
