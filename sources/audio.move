// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// An audio file with self-attested technical metadata — a standalone, wrapped
/// primitive that any protocol can embed (e.g. as a recording's master).
///
/// ### Key Features:
///
/// - Format (codec/container, e.g. `flac`) and PCM parameters (channels, bit
///   depth, sample rate, samples)
/// - Walrus blob ID for storage reference
/// - Permissionless creation from caller-supplied metadata via `new`.
/// Metadata is structurally validated; blob contents and PCM digests are not verified.
module audio::audio;

use std::string::String;
use sui::event::emit;
use ori::data::WalrusBlob;

// === Structs ===

/// An audio file with caller-supplied technical metadata.
/// Copying duplicates metadata and a blob reference, not the underlying audio bytes.
public struct Audio has copy, drop, store {
    /// Codec/container of the stored blob, as a bare lowercase short name
    /// (e.g. `flac`, `wav`, `opus`). No `audio/` prefix — the type is already audio.
    format: String,
    /// Number of audio channels (1 = mono, 2 = stereo).
    channels: u8,
    /// Bits per sample (8, 16, 24, or 32).
    bit_depth: u8,
    /// Supported integer PCM sample rate in hertz (44.1/48 kHz families through 384 kHz).
    sample_rate_hz: u32,
    /// Total number of PCM samples in the audio.
    samples: u64,
    /// Unkeyed BLAKE3 digest of the canonical decoded PCM (codec-independent
    /// content fingerprint), using the default 32-byte output.
    pcm_digest: vector<u8>,
    /// Standalone Walrus blob reference for the audio.
    data: WalrusBlob,
}

// === Events ===

/// Emitted when an audio file is ingested.
public struct AudioIngestedEvent has copy, drop {
    blob_id: u256,
    format: String,
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples: u64,
    duration_ms: u64,
    pcm_digest: vector<u8>,
}

// === Constants ===

/// Maximum length of a format short name in bytes (generous; real names are <=8).
const MAX_FORMAT_LENGTH: u64 = 16;
/// Required length of the PCM digest in bytes (BLAKE3).
const PCM_DIGEST_LENGTH: u64 = 32;
/// Supported sample rates in hertz: 44.1/48 kHz and their successive doublings.
const SUPPORTED_SAMPLE_RATES: vector<u32> = vector[
    44_100, 48_000, 88_200, 96_000, 176_400, 192_000, 352_800, 384_000,
];

// === Errors ===

// Validation errors (20-29)
/// Audio must have at least one channel.
const EInvalidChannels: u64 = 21;
/// Bit depth must be 8, 16, 24, or 32.
const EInvalidBitDepth: u64 = 22;
/// Sample rate must be one of the supported 44.1/48 kHz family rates.
const EInvalidSampleRate: u64 = 23;
/// Audio must have at least one sample.
const EInvalidSamples: u64 = 24;
/// Format must not be empty.
const EEmptyFormat: u64 = 26;
/// Format exceeds maximum length.
const EFormatTooLong: u64 = 27;
/// Format contains an invalid character (must be lowercase `a`-`z` or `0`-`9`).
const EInvalidFormatChar: u64 = 28;
/// PCM digest must be exactly 32 bytes (BLAKE3).
const EInvalidDigestLength: u64 = 29;
// === Public Functions ===

/// Creates audio from the caller's self-attested metadata.
/// Validates metadata shape and numeric bounds, without verifying the underlying bytes.
public fun new(
    format: String,
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples: u64,
    pcm_digest: vector<u8>,
    data: WalrusBlob,
): Audio {
    // Format must be a non-empty, lowercase alphanumeric short name (e.g. `flac`).
    let format_bytes = format.as_bytes();
    assert!(!format_bytes.is_empty(), EEmptyFormat);
    assert!(format_bytes.length() <= MAX_FORMAT_LENGTH, EFormatTooLong);
    assert!(
        format_bytes.all!(|c| (*c >= 0x61 && *c <= 0x7a) || (*c >= 0x30 && *c <= 0x39)),
        EInvalidFormatChar,
    );
    // PCM digest must be a 32-byte BLAKE3 hash.
    assert!(pcm_digest.length() == PCM_DIGEST_LENGTH, EInvalidDigestLength);
    // Assert the channels are greater than 0.
    assert!(channels > 0, EInvalidChannels);
    // Assert the bit depth is 8, 16, 24, or 32.
    assert!(vector[8, 16, 24, 32].contains(&bit_depth), EInvalidBitDepth);
    let supported_sample_rates = SUPPORTED_SAMPLE_RATES;
    assert!(supported_sample_rates.contains(&sample_rate_hz), EInvalidSampleRate);
    // Assert the samples are greater than 0.
    assert!(samples > 0, EInvalidSamples);

    let duration_ms = samples.mul_div(1_000, sample_rate_hz as u64);

    emit(AudioIngestedEvent {
        blob_id: data.blob_id(),
        format,
        channels,
        bit_depth,
        sample_rate_hz,
        samples,
        duration_ms,
        pcm_digest,
    });

    Audio {
        format,
        channels,
        bit_depth,
        sample_rate_hz,
        samples,
        pcm_digest,
        data,
    }
}

// === Audio View Functions ===

/// Returns the number of audio channels (1 = mono, 2 = stereo).
public fun channels(self: &Audio): u8 {
    self.channels
}

/// Returns the bit depth of the audio (8, 16, 24, or 32 bits).
public fun bit_depth(self: &Audio): u8 {
    self.bit_depth
}

/// Returns the sample rate in Hz.
public fun sample_rate_hz(self: &Audio): u32 {
    self.sample_rate_hz
}

/// Returns the total number of samples in the audio.
public fun samples(self: &Audio): u64 {
    self.samples
}

/// Returns a reference to the standalone Walrus blob.
public fun data(self: &Audio): &WalrusBlob {
    &self.data
}

/// Returns the duration of the audio in milliseconds (truncated).
/// Uses a u128 intermediate product to avoid overflow, rounding down.
/// All supported sample rates keep the result within u64 for any sample count.
public fun duration_ms(self: &Audio): u64 {
    self.samples.mul_div(1_000, self.sample_rate_hz as u64)
}

/// Returns the codec/container format of the stored blob (e.g. `flac`).
public fun format(self: &Audio): &String {
    &self.format
}

/// Returns the `BLAKE3` digest of the canonical decoded PCM (32 bytes).
public fun pcm_digest(self: &Audio): &vector<u8> {
    &self.pcm_digest
}

#[test_only]
public fun ingested_event_duration_ms(event: &AudioIngestedEvent): u64 {
    event.duration_ms
}
