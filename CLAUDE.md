# audio

Move 2024 package. Implementation is in `sources/audio.move`; tests are in
`tests/audio_tests.move`.

## Project Rules

- PCM digests use unkeyed BLAKE3 with the default 32-byte output.
- V1 uses permissionless `new()`. Metadata validation does not verify audio bytes.
- Nautilus-attested audio belongs in a separate future package. Do not add witness
  gating or attestation markers here.
- Pin ori to a verified upstream commit and let Sui generate `Move.lock`.
- Validate with `sui move build --build-env testnet` and
  `sui move test --build-env testnet`.

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
