# miso-audio

[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Move](https://img.shields.io/badge/Move-2024-black.svg)](https://docs.sui.io/concepts/sui-move-concepts)

> Self-attested audio as a composable on-chain primitive for [Sui](https://sui.io).

`audio` defines an `Audio` value that carries an audio file's technical metadata and a Walrus blob ID. Any protocol can embed it as a recording's master, a podcast episode, or a video's audio track. V1 uses permissionless **self-attestation**: callers supply the metadata directly, without a Nautilus enclave, attestation document, or custom ingester witness.

## Design

- **Self-attested metadata.** Anyone can call `new()`. The package validates metadata shape and numeric bounds, but does not download the blob, decode audio, or verify that the digest or metadata matches its contents. The transaction sender identifies the submitter.
- **Always wrapped.** `Audio` has `store` but **not** `key` — it cannot exist as a standalone object. It is always a field of some larger object (e.g. a recording), never an asset in its own right.
- **Composable value.** `new()` returns an `Audio` for callers to embed in their own objects.
- **Copyable metadata.** `Audio` has `copy`, `drop`, and `store`. Copying it duplicates metadata and a blob ID, without duplicating the stored audio bytes or granting authority.

```move
public struct Audio has copy, drop, store {
    format: String,
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples: u64,
    pcm_digest: vector<u8>,
    blob_id: u256,        // standalone Walrus blob ID
}
```

## Install

Add to your `Move.toml`:

```toml
[dependencies]
audio = { git = "https://github.com/misofm/audio.git", rev = "main" }
```

## Usage

Supported integer PCM bit depths are 8, 16, 24, and 32 bits. Supported sample
rates are 44.1, 48, 88.2, 96, 176.4, 192, 352.8, and 384 kHz. Other sample
rates are rejected, including values between these supported rates.
Sample counts may use the full positive `u64` range. `duration_ms()` rounds down
to whole milliseconds using `u64::mul_div` to avoid intermediate overflow.

Create V1 audio directly from caller-supplied metadata:

```move
use audio::audio;

public fun ingest(
    blob_id: u256,
    pcm_digest: vector<u8>,
): audio::Audio {
    audio::new(
        "flac",
        2,       // channels
        24,      // bit depth
        48000,   // sample rate in Hz
        480000,  // sample count (10 seconds)
        pcm_digest,
        blob_id,
    )
}
```

Consumers read the metadata:

```move
let rate = master.sample_rate_hz();
let duration = master.duration_ms();
```

`pcm_digest` is the unkeyed BLAKE3 hash of the canonical decoded PCM, using
the default 32-byte output. Hash the decoded PCM, not the encoded file or its
container headers. The constructor checks the digest length; it does not compute
or verify the hash.

The blob ID is a bare `u256`; this V1 value has no confidentiality metadata or
encrypted-audio path. The constructor returns the value for its caller to
attach to an owning object; it does not emit an event or create a standalone
ingestion record.

## Future Nautilus support

Nautilus-attested audio will be implemented in a separate package. This package
contains only self-attested audio, with no witness or attestation marker.

## Build & test

```sh
sui move build --build-env testnet
sui move test --build-env testnet
```

## Dependencies

The package has no external Move dependencies. It uses only Sui's standard
library packages supplied by the toolchain.

## Contributing

Issues and pull requests are welcome. By contributing you agree that your contributions are licensed under the project's Apache 2.0 license.

## License

[Apache 2.0](LICENSE) © Miso Labs, Inc.
