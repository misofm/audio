// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

module audio::audio;

// === Imports ===

use std::string::String;
use sui::event::emit;
use ori::data::WalrusBlob;

// === Errors ===

const EEmptyFormat: u64 = 0;
const EFormatTooLong: u64 = 1;
const EInvalidFormatChar: u64 = 2;
const EEncryptedBlob: u64 = 3;
const EInvalidChannels: u64 = 4;
const EInvalidBitDepth: u64 = 5;
const EInvalidSampleRate: u64 = 6;
const EInvalidSamplesPerChannel: u64 = 7;
const EInvalidDuration: u64 = 8;
const EInvalidDigestLength: u64 = 9;

// === Constants ===

const MAX_FORMAT_LENGTH: u64 = 16;
const MAX_BIT_DEPTH: u8 = 32;
const PCM_DIGEST_LENGTH: u64 = 32;

// === Structs ===

public struct Audio<phantom Verifier> has copy, drop, store {
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples_per_channel: u64,
    pcm_digest: vector<u8>,
    blob: WalrusBlob,
}

// === Events ===

public struct AudioCreatedEvent<phantom Verifier> has copy, drop {
    format: String,
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples_per_channel: u64,
    pcm_digest: vector<u8>,
    blob_id: u256,
}

// === Public Functions ===

public fun new<Verifier: drop>(
    _: Verifier,
    format: String,
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples_per_channel: u64,
    pcm_digest: vector<u8>,
    blob: WalrusBlob,
): Audio<Verifier> {
    let format_bytes = format.as_bytes();
    assert!(!format_bytes.is_empty(), EEmptyFormat);
    assert!(format_bytes.length() <= MAX_FORMAT_LENGTH, EFormatTooLong);
    assert!(
        format_bytes.all!(|c| (*c >= 0x61 && *c <= 0x7a) || (*c >= 0x30 && *c <= 0x39)),
        EInvalidFormatChar,
    );
    assert!(!blob.blob_confidentiality().is_encrypted(), EEncryptedBlob);
    assert!(channels > 0, EInvalidChannels);
    assert!(bit_depth > 0 && bit_depth <= MAX_BIT_DEPTH, EInvalidBitDepth);
    assert!(sample_rate_hz > 0, EInvalidSampleRate);
    assert!(samples_per_channel > 0, EInvalidSamplesPerChannel);
    assert!(
        ((samples_per_channel as u128) * 1_000 / (sample_rate_hz as u128)).try_as_u64().is_some(),
        EInvalidDuration,
    );
    assert!(pcm_digest.length() == PCM_DIGEST_LENGTH, EInvalidDigestLength);

    emit(AudioCreatedEvent<Verifier> {
        format,
        channels,
        bit_depth,
        sample_rate_hz,
        samples_per_channel,
        pcm_digest,
        blob_id: blob.blob_id(),
    });

    Audio {
        channels,
        bit_depth,
        sample_rate_hz,
        samples_per_channel,
        pcm_digest,
        blob,
    }
}

// === View Functions ===

public fun channels<Verifier>(self: &Audio<Verifier>): u8 {
    self.channels
}

public fun bit_depth<Verifier>(self: &Audio<Verifier>): u8 {
    self.bit_depth
}

public fun sample_rate_hz<Verifier>(self: &Audio<Verifier>): u32 {
    self.sample_rate_hz
}

public fun samples_per_channel<Verifier>(self: &Audio<Verifier>): u64 {
    self.samples_per_channel
}

public fun pcm_digest<Verifier>(self: &Audio<Verifier>): &vector<u8> {
    &self.pcm_digest
}

public fun blob<Verifier>(self: &Audio<Verifier>): &WalrusBlob {
    &self.blob
}

public fun duration_ms<Verifier>(self: &Audio<Verifier>): u64 {
    self.samples_per_channel.mul_div(1_000, self.sample_rate_hz as u64)
}

// === Test Functions ===

#[test_only]
public fun audio_created_event_fields<Verifier>(
    event: &AudioCreatedEvent<Verifier>,
): (String, u8, u8, u32, u64, vector<u8>, u256) {
    (
        event.format,
        event.channels,
        event.bit_depth,
        event.sample_rate_hz,
        event.samples_per_channel,
        event.pcm_digest,
        event.blob_id,
    )
}
