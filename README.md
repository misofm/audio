# miso-audio

[![License: FSL-1.1-ALv2](https://img.shields.io/badge/license-FSL--1.1--ALv2-blue.svg)](LICENSE.md)
[![Move](https://img.shields.io/badge/Move-2024-black.svg)](https://docs.sui.io/concepts/sui-move-concepts)

> Verified lossless audio as a composable on-chain value for [Sui](https://sui.io).

`Audio<Verifier>` is a set of lossless audio facts vouched for by a `Verifier` type: channels, bit depth, sample rate, samples per channel, a PCM digest and an unencrypted Walrus blob. Only code holding a `Verifier` witness can call `new`, so the type parameter names who measured the audio. There is no self-attested audio.

## Trust

- **Pin the verifier types you trust.** Accept `Audio<SomeVerifier>`, never a generic `Audio<Verifier>` treated as trusted: anyone can publish a package with a witness and vouch for anything.
- **Store audio from several verifiers under type-keyed dynamic fields**, not a fixed field typed to one verifier, so a new verifier can be added later.
- `Audio` has `copy, drop, store` and no `key`. Copying it copies facts and a blob reference, not authority.

```move
public struct Audio<phantom Verifier> has copy, drop, store {
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples_per_channel: u64,
    pcm_digest: vector<u8>,
    blob: WalrusBlob,
}

public fun new<Verifier: drop>(
    _: Verifier,
    format: String,
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples_per_channel: u64,
    pcm_digest: vector<u8>,
    blob: WalrusBlob,
): Audio<Verifier>
```

`new` checks the shape of the facts and emits `AudioCreatedEvent<Verifier>` with all of them, including `format` and `blob_id`. It does not read the blob or check the digest; that is the verifier's job.

| Fact | Rule |
|---|---|
| `format` | 1 to 16 bytes, `a`–`z` and `0`–`9`. Emitted, not stored. |
| `blob` | `ori::data::WalrusBlob`, not encrypted |
| `channels` | at least 1 |
| `bit_depth` | 1 to 32 |
| `sample_rate_hz` | at least 1 |
| `samples_per_channel` | at least 1, and the duration in milliseconds fits in a `u64` |
| `pcm_digest` | exactly 32 bytes |

Views: `channels`, `bit_depth`, `sample_rate_hz`, `samples_per_channel`, `pcm_digest`, `blob`, and `duration_ms`, which rounds down and never aborts, because `new` bounds the duration.

## Formats

`format` names the codec, which implies its standard container.

| Name | Audio |
|---|---|
| `flac` | FLAC, native `.flac` |
| `wav` | PCM in RIFF WAVE |
| `aiff` | PCM in AIFF |
| `alac` | Apple Lossless in M4A |
| `wv` | WavPack |

## PCM digest

`pcm_digest` is BLAKE3, with the default 32-byte output, over the decoded PCM, interleaved by sample frame. Each sample is a signed integer, little-endian, `ceil(bit_depth / 8)` bytes, two's complement, right-aligned (sign-extended within those bytes). It hashes the audio, not the file, so the same PCM gives the same digest in any format.

## Install

Pin a commit:

```toml
[dependencies]
audio = { git = "https://github.com/misofm/audio.git", rev = "<commit>" }
```

The package depends on [ori](https://github.com/unconfirmedlabs/ori) at `367ed5fe92a8b62da02c1116537cf08d111e0789`, so `WalrusBlob` is the same type as in `misofm/cover-art`.

## Build & test

```sh
sui move build
sui move test --coverage
```

## Deployments

This API has not been published. The previous, self-attested API was published at:

- mainnet `0x73a989640258bd5d82e0ae23bcb6f874fae65c78aecc1781b9a702801a043d7e`
- testnet `0x7b143c3408e5fc8964e7ee696c9d4b63b6d0464347797e32bfa43275f09a3b08`

## Contributing

Issues and pull requests are welcome. By contributing you agree that your contributions are licensed under the project's FSL-1.1-ALv2 license.

## License

[Functional Source License 1.1, ALv2 Future License](./LICENSE.md) © Miso Labs, Inc.
