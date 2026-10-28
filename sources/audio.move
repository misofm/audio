// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

module audio::audio;

use ori::{confidentiality, data::{Self, WalrusBlob}};
use sui::{derived_object, dynamic_field, event::emit};

// === Imports ===

// === Errors ===

const EInvalidChannels: u64 = 0;
const EInvalidBitDepth: u64 = 1;
const EInvalidSampleRate: u64 = 2;
const EInvalidSamplesPerChannel: u64 = 3;
const EInvalidDuration: u64 = 4;
const EInvalidDigestLength: u64 = 5;
const EAudioExists: u64 = 6;
const ENoEncoding: u64 = 7;

// === Constants ===

const MAX_BIT_DEPTH: u8 = 32;
const PCM_DIGEST_LENGTH: u64 = 32;

// === Structs ===

public struct Audio<phantom AudioVerifier> has key {
    id: UID,
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples_per_channel: u64,
    pcm_digest: vector<u8>,
}

public struct AudioRegistry has key {
    id: UID,
}

public struct AudioKey<phantom AudioVerifier> has copy, drop, store {
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples_per_channel: u64,
    pcm_digest: vector<u8>,
}

public struct AudioEncodingKey(u256) has copy, drop, store;

// === Events ===

public struct AudioCreatedEvent<phantom AudioVerifier> has copy, drop {
    audio_id: ID,
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples_per_channel: u64,
    pcm_digest: vector<u8>,
}

public struct AudioEncodingAddedEvent<phantom AudioVerifier> has copy, drop {
    audio_id: ID,
    blob_id: u256,
}

// === Init ===

fun init(ctx: &mut TxContext) {
    transfer::share_object(AudioRegistry { id: object::new(ctx) });
}

// === Public Functions ===

public fun new<AudioVerifier: drop>(
    registry: &mut AudioRegistry,
    _: AudioVerifier,
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples_per_channel: u64,
    pcm_digest: vector<u8>,
): Audio<AudioVerifier> {
    assert!(channels > 0, EInvalidChannels);
    assert!(bit_depth > 0 && bit_depth <= MAX_BIT_DEPTH, EInvalidBitDepth);
    assert!(sample_rate_hz > 0, EInvalidSampleRate);
    assert!(samples_per_channel > 0, EInvalidSamplesPerChannel);
    assert!(
        ((samples_per_channel as u128) * 1_000 / (sample_rate_hz as u128)).try_as_u64().is_some(),
        EInvalidDuration,
    );
    assert!(pcm_digest.length() == PCM_DIGEST_LENGTH, EInvalidDigestLength);
    let key = AudioKey<AudioVerifier> {
        channels,
        bit_depth,
        sample_rate_hz,
        samples_per_channel,
        pcm_digest,
    };
    assert!(!derived_object::exists(&registry.id, key), EAudioExists);
    let id = derived_object::claim(&mut registry.id, key);
    emit(AudioCreatedEvent<AudioVerifier> {
        audio_id: id.to_inner(),
        channels,
        bit_depth,
        sample_rate_hz,
        samples_per_channel,
        pcm_digest,
    });
    Audio { id, channels, bit_depth, sample_rate_hz, samples_per_channel, pcm_digest }
}

public fun add_encoding<AudioVerifier: drop>(
    audio: &mut Audio<AudioVerifier>,
    _: AudioVerifier,
    blob_id: u256,
) {
    let key = AudioEncodingKey(blob_id);
    if (dynamic_field::exists(&audio.id, key)) return;
    dynamic_field::add(&mut audio.id, key, true);
    emit(AudioEncodingAddedEvent<AudioVerifier> { audio_id: audio.id.to_inner(), blob_id });
}

public fun share<AudioVerifier>(audio: Audio<AudioVerifier>) {
    transfer::share_object(audio);
}

// === View Functions ===

public fun channels<AudioVerifier>(audio: &Audio<AudioVerifier>): u8 {
    audio.channels
}

public fun bit_depth<AudioVerifier>(audio: &Audio<AudioVerifier>): u8 {
    audio.bit_depth
}

public fun sample_rate_hz<AudioVerifier>(audio: &Audio<AudioVerifier>): u32 {
    audio.sample_rate_hz
}

public fun samples_per_channel<AudioVerifier>(audio: &Audio<AudioVerifier>): u64 {
    audio.samples_per_channel
}

public fun pcm_digest<AudioVerifier>(audio: &Audio<AudioVerifier>): &vector<u8> {
    &audio.pcm_digest
}

public fun duration_ms<AudioVerifier>(audio: &Audio<AudioVerifier>): u64 {
    audio.samples_per_channel.mul_div(1_000, audio.sample_rate_hz as u64)
}

public fun has_encoding<AudioVerifier>(audio: &Audio<AudioVerifier>, blob_id: u256): bool {
    dynamic_field::exists(&audio.id, AudioEncodingKey(blob_id))
}

public fun encoding<AudioVerifier>(audio: &Audio<AudioVerifier>, blob_id: u256): WalrusBlob {
    assert!(audio.has_encoding(blob_id), ENoEncoding);
    data::new_blob(blob_id, confidentiality::new_unencrypted())
}

public fun derive_address<AudioVerifier>(
    registry_id: ID,
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples_per_channel: u64,
    pcm_digest: vector<u8>,
): address {
    derived_object::derive_address(
        registry_id,
        AudioKey<AudioVerifier> {
            channels,
            bit_depth,
            sample_rate_hz,
            samples_per_channel,
            pcm_digest,
        },
    )
}

// === Test Functions ===

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

#[test_only]
public fun new_registry_for_testing(ctx: &mut TxContext): AudioRegistry {
    AudioRegistry { id: object::new(ctx) }
}

#[test_only]
public fun audio_created_event_fields<AudioVerifier>(
    event: &AudioCreatedEvent<AudioVerifier>,
): (ID, u8, u8, u32, u64, vector<u8>) {
    (
        event.audio_id,
        event.channels,
        event.bit_depth,
        event.sample_rate_hz,
        event.samples_per_channel,
        event.pcm_digest,
    )
}

#[test_only]
public fun audio_encoding_added_event_fields<AudioVerifier>(
    event: &AudioEncodingAddedEvent<AudioVerifier>,
): (ID, u256) {
    (event.audio_id, event.blob_id)
}
