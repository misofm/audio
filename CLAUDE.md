# audio

Move 2024 package. Implementation is in `sources/audio.move`; tests are in
`tests/audio_tests.move`.

## Project Rules

- `Audio<phantom AudioVerifier>` is created only by `new<AudioVerifier: drop>` with the
  verifier's witness. There is no self-attested audio; verification logic lives
  in verifier packages such as `misofm/verified-audio`, never here.
- The blob is an `ori::data::WalrusBlob` pinned at the same ori rev as
  `misofm/cover-art`, and must not be encrypted.
- `format` is validated and emitted in `AudioCreatedEvent<AudioVerifier>`, not stored.
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
