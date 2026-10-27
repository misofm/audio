// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

#[test_only]
module audio::audio_tests;

use std::string::String;
use std::unit_test::assert_eq;
use sui::event;
use ori::confidentiality;
use ori::data::{Self, WalrusBlob};
use audio::audio::{Self, Audio, AudioCreatedEvent};

// === Test Types ===

public struct TestAudioVerifier() has drop;

public struct OtherAudioVerifier() has drop;

// === Constants ===

const BLOB_ID: u256 = 0xb10b;
const DIGEST: vector<u8> = x"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20";

// === Helpers ===

fun blob(): WalrusBlob {
    data::new_blob(BLOB_ID, confidentiality::new_unencrypted())
}

fun new_audio(
    format: String,
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples_per_channel: u64,
    pcm_digest: vector<u8>,
): Audio<TestAudioVerifier> {
    audio::new(
        TestAudioVerifier(),
        format,
        channels,
        bit_depth,
        sample_rate_hz,
        samples_per_channel,
        pcm_digest,
        blob(),
    )
}

fun with_format(format: vector<u8>): Audio<TestAudioVerifier> {
    new_audio(format.to_string(), 2, 16, 44_100, 441_000, DIGEST)
}

fun with_bit_depth(bit_depth: u8): Audio<TestAudioVerifier> {
    new_audio(b"flac".to_string(), 2, bit_depth, 44_100, 441_000, DIGEST)
}

// === New ===

#[test]
fun new_stores_every_fact() {
    let audio = new_audio(b"flac".to_string(), 2, 24, 48_000, 480_000, DIGEST);
    assert_eq!(audio.channels(), 2);
    assert_eq!(audio.bit_depth(), 24);
    assert_eq!(audio.sample_rate_hz(), 48_000);
    assert_eq!(audio.samples_per_channel(), 480_000);
    assert_eq!(*audio.pcm_digest(), DIGEST);
    assert_eq!(*audio.blob(), blob());
    assert_eq!(audio.blob().blob_id(), BLOB_ID);
    assert_eq!(audio.duration_ms(), 10_000);
}

#[test]
fun new_emits_every_fact_with_the_verifier_type() {
    let _audio = new_audio(b"wv".to_string(), 6, 20, 22_050, 22_050, DIGEST);
    let events = event::events_by_type<AudioCreatedEvent<TestAudioVerifier>>();
    assert_eq!(events.length(), 1);
    assert_eq!(event::events_by_type<AudioCreatedEvent<OtherAudioVerifier>>().length(), 0);
    let (
        format,
        channels,
        bit_depth,
        sample_rate_hz,
        samples_per_channel,
        pcm_digest,
        blob_id,
    ) = audio::audio_created_event_fields(&events[0]);
    assert_eq!(format, b"wv".to_string());
    assert_eq!(channels, 6);
    assert_eq!(bit_depth, 20);
    assert_eq!(sample_rate_hz, 22_050);
    assert_eq!(samples_per_channel, 22_050);
    assert_eq!(pcm_digest, DIGEST);
    assert_eq!(blob_id, BLOB_ID);
}

#[test]
fun each_verifier_gets_its_own_type() {
    let _ours = with_format(b"flac");
    let _theirs: Audio<OtherAudioVerifier> = audio::new(
        OtherAudioVerifier(),
        b"flac".to_string(),
        2,
        16,
        44_100,
        441_000,
        DIGEST,
        blob(),
    );
    assert_eq!(event::events_by_type<AudioCreatedEvent<TestAudioVerifier>>().length(), 1);
    assert_eq!(event::events_by_type<AudioCreatedEvent<OtherAudioVerifier>>().length(), 1);
}

#[test]
fun canonical_format_names_are_accepted() {
    with_format(b"flac");
    with_format(b"wav");
    with_format(b"aiff");
    with_format(b"alac");
    with_format(b"wv");
    with_format(b"0123456789abcdef");
    assert_eq!(event::num_events(), 6);
}

#[test]
fun bit_depth_bounds_are_accepted() {
    assert_eq!(with_bit_depth(1).bit_depth(), 1);
    assert_eq!(with_bit_depth(32).bit_depth(), 32);
}

#[test]
fun minimal_values_are_accepted() {
    let audio = new_audio(b"a".to_string(), 1, 1, 1, 1, DIGEST);
    assert_eq!(audio.duration_ms(), 1_000);
}

#[test]
fun duration_rounds_down() {
    let audio = new_audio(b"flac".to_string(), 2, 16, 44_100, 44_099, DIGEST);
    assert_eq!(audio.duration_ms(), 999);
}

#[test]
fun duration_handles_the_largest_sample_count_without_overflow() {
    let audio = new_audio(
        b"flac".to_string(),
        2,
        16,
        4_294_967_295,
        18_446_744_073_709_551_615,
        DIGEST,
    );
    assert_eq!(audio.duration_ms(), 4_294_967_297_000);
}

// === Aborts ===

#[test, expected_failure(abort_code = audio::EEmptyFormat)]
fun empty_format_is_rejected() {
    with_format(b"");
}

#[test, expected_failure(abort_code = audio::EFormatTooLong)]
fun long_format_is_rejected() {
    with_format(b"0123456789abcdefg");
}

#[test, expected_failure(abort_code = audio::EInvalidFormatChar)]
fun uppercase_format_is_rejected() {
    with_format(b"FLAC");
}

#[test, expected_failure(abort_code = audio::EInvalidFormatChar)]
fun punctuated_format_is_rejected() {
    with_format(b"audio/flac");
}

#[test, expected_failure(abort_code = audio::EInvalidFormatChar)]
fun format_below_digits_is_rejected() {
    with_format(b"/");
}

#[test, expected_failure(abort_code = audio::EInvalidFormatChar)]
fun format_between_digits_and_letters_is_rejected() {
    with_format(b":");
}

#[test, expected_failure(abort_code = audio::EInvalidFormatChar)]
fun format_above_letters_is_rejected() {
    with_format(b"{");
}

#[test, expected_failure(abort_code = audio::EEncryptedBlob)]
fun encrypted_blob_is_rejected() {
    audio::new(
        TestAudioVerifier(),
        b"flac".to_string(),
        2,
        16,
        44_100,
        441_000,
        DIGEST,
        data::new_blob(BLOB_ID, confidentiality::new_encrypted(x"dead")),
    );
}

#[test, expected_failure(abort_code = audio::EInvalidChannels)]
fun zero_channels_are_rejected() {
    new_audio(b"flac".to_string(), 0, 16, 44_100, 441_000, DIGEST);
}

#[test, expected_failure(abort_code = audio::EInvalidBitDepth)]
fun zero_bit_depth_is_rejected() {
    with_bit_depth(0);
}

#[test, expected_failure(abort_code = audio::EInvalidBitDepth)]
fun bit_depth_above_32_is_rejected() {
    with_bit_depth(33);
}

#[test, expected_failure(abort_code = audio::EInvalidSampleRate)]
fun zero_sample_rate_is_rejected() {
    new_audio(b"flac".to_string(), 2, 16, 0, 441_000, DIGEST);
}

#[test, expected_failure(abort_code = audio::EInvalidSamplesPerChannel)]
fun zero_samples_per_channel_are_rejected() {
    new_audio(b"flac".to_string(), 2, 16, 44_100, 0, DIGEST);
}

#[test]
fun longest_duration_at_one_hertz_is_accepted() {
    let audio = new_audio(b"flac".to_string(), 1, 16, 1, 18_446_744_073_709_551, DIGEST);
    assert_eq!(audio.duration_ms(), 18_446_744_073_709_551_000);
}

#[test, expected_failure(abort_code = audio::EInvalidDuration)]
fun duration_beyond_u64_is_rejected() {
    new_audio(b"flac".to_string(), 1, 16, 1, 18_446_744_073_709_552, DIGEST);
}

#[test, expected_failure(abort_code = audio::EInvalidDigestLength)]
fun short_digest_is_rejected() {
    new_audio(b"flac".to_string(), 2, 16, 44_100, 441_000, x"01");
}

#[test, expected_failure(abort_code = audio::EInvalidDigestLength)]
fun long_digest_is_rejected() {
    let mut digest = DIGEST;
    digest.push_back(0);
    new_audio(b"flac".to_string(), 2, 16, 44_100, 441_000, digest);
}
