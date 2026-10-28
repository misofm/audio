# audio

Move 2024 package. Implementation is in `sources/audio.move`; tests are in
`tests/audio_tests.move`.

## Project Rules

- `Audio<phantom AudioVerifier>` is a `key`-only shared object, derived from the
  shared `AudioRegistry` by `AudioKey<AudioVerifier>` over the five facts, and
  created only by `new<AudioVerifier: drop>` with the verifier's witness. Its
  facts never change. Verification logic lives in verifier packages such as
  `misofm/audio-verifier`, never here.
- Field order everywhere is `channels, bit_depth, sample_rate_hz,
  samples_per_channel, pcm_digest`: frame shape, then time, then content, as in
  the verifier's signed payload. It is part of the key's BCS, so it fixes every
  derived address; don't change it.
- Encodings are `AudioEncodingKey(blob_id) → true` on the Audio, write-once,
  never removed. Formats are not stored. ori (`WalrusBlob`) is pinned at the
  same rev as `misofm/cover-art`.
- Audio means integer linear PCM. Float PCM or DSD would be separate types.
- PCM digests are unkeyed BLAKE3 with the default 32-byte output, over the spec
  in the README.
- Follow the misofm brain MOVE-STANDARDS: no comments except the license header
  and section banners, plain numeric error codes, prefer macros.
- Validate with `sui move build --build-env mainnet` and `sui move test --coverage`.

## Sui Development Skills

Install community-maintained skills for Sui development:

```sh
npx skills https://github.com/MystenLabs/skills
```

## Official Resources

When unsure about Move patterns or Sui APIs, consult these sources:

- Move Book: https://move-book.com (https://move-book.com/llms.txt)
- Sui Docs: https://docs.sui.io (https://docs.sui.io/llms.txt)
- Sui Move examples: https://github.com/MystenLabs/sui/tree/main/examples/move

Use the Sui documentation MCP server at https://sui.mcp.kapa.ai when available.
