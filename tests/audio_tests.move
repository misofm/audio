#[test_only]
module audio::audio_tests;

use audio::audio as af;
use std::unit_test::assert_eq;
use std::u64;
use ori::{confidentiality, data};

// Error codes from audio.move
const EInvalidChannels: u64 = 21;
const EInvalidBitDepth: u64 = 22;
const EInvalidSampleRate: u64 = 23;
const EInvalidSamples: u64 = 24;
const EEmptyFormat: u64 = 26;
const EFormatTooLong: u64 = 27;
const EInvalidFormatChar: u64 = 28;
const EInvalidDigestLength: u64 = 29;

const MAX_SAMPLES: u64 = 18_446_744_073_709_551; // Former multiplication limit.

/// Synthetic 32-byte digest fixture; these tests validate storage and length, not hashing.
fun test_digest(): vector<u8> {
    x"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20"
}

// === Happy Path ===

#[test]
fun test_new() {
    let audio = af::new(b"flac".to_string(),
        2, 16, 44100, 441000,
        test_digest(),
        data::new_blob(1, confidentiality::new_unencrypted()),
    );
    assert_eq!(audio.channels(), 2);
    assert_eq!(audio.bit_depth(), 16);
    assert_eq!(audio.sample_rate_hz(), 44100);
    assert_eq!(audio.samples(), 441000);
    assert_eq!(audio.data().blob_id(), 1);
    assert_eq!(*audio.format(), b"flac".to_string());
    assert_eq!(*audio.pcm_digest(), test_digest());
    assert_eq!(sui::event::num_events(), 1);
    assert_eq!(sui::event::events_by_type<af::AudioIngestedEvent>().length(), 1);
}

#[test]
fun test_new_mono_audio() {
    let audio = af::new(b"flac".to_string(), 1, 16, 44100, 1000, test_digest(), data::new_blob(1, confidentiality::new_unencrypted()));
    assert_eq!(audio.channels(), 1);
}

#[test]
fun test_new_encrypted_audio() {
    let audio = af::new(
        b"flac".to_string(),
        2,
        24,
        48000,
        48000,
        test_digest(),
        data::new_blob(7, confidentiality::new_encrypted(b"sealed-dek")),
    );
    let confidentiality = audio.data().blob_confidentiality();

    assert!(confidentiality.is_encrypted());
    assert_eq!(*confidentiality.sealed_dek(), b"sealed-dek");
}

#[test]
fun test_new_all_valid_bit_depths() {
    let audio_8 = af::new(b"flac".to_string(), 1, 8, 44100, 1000, test_digest(), data::new_blob(1, confidentiality::new_unencrypted()));
    assert_eq!(audio_8.bit_depth(), 8);

    let audio_16 = af::new(b"flac".to_string(), 1, 16, 44100, 1000, test_digest(), data::new_blob(1, confidentiality::new_unencrypted()));
    assert_eq!(audio_16.bit_depth(), 16);

    let audio_24 = af::new(b"flac".to_string(), 1, 24, 44100, 1000, test_digest(), data::new_blob(1, confidentiality::new_unencrypted()));
    assert_eq!(audio_24.bit_depth(), 24);

    let audio_32 = af::new(b"flac".to_string(), 1, 32, 44100, 1000, test_digest(), data::new_blob(1, confidentiality::new_unencrypted()));
    assert_eq!(audio_32.bit_depth(), 32);
}

#[test]
fun maximum_sample_count_is_supported() {
    let audio = af::new(b"flac".to_string(), 1, 16, 44100, u64::max_value!(), test_digest(), data::new_blob(1, confidentiality::new_unencrypted()));
    assert_eq!(audio.samples(), u64::max_value!());
    assert_eq!(audio.duration_ms(), 418_293_516_410_647_428);
    let events = sui::event::events_by_type<af::AudioIngestedEvent>();
    assert_eq!(af::ingested_event_duration_ms(&events[0]), audio.duration_ms());
}

#[test]
fun test_duration_ms() {
    // 44100 samples at 44100 Hz = exactly 1000 ms
    let audio = af::new(b"flac".to_string(), 2, 16, 44100, 44100, test_digest(), data::new_blob(1, confidentiality::new_unencrypted()));
    assert_eq!(audio.duration_ms(), 1000);

    // 88200 samples at 44100 Hz = exactly 2000 ms
    let audio2 = af::new(b"flac".to_string(), 2, 16, 44100, 88200, test_digest(), data::new_blob(1, confidentiality::new_unencrypted()));
    assert_eq!(audio2.duration_ms(), 2000);

    // 48000 samples at 48000 Hz = exactly 1000 ms
    let audio3 = af::new(b"flac".to_string(), 1, 24, 48000, 48000, test_digest(), data::new_blob(1, confidentiality::new_unencrypted()));
    assert_eq!(audio3.duration_ms(), 1000);
}

// === Error Conditions ===

#[test, expected_failure(abort_code = EInvalidChannels, location = audio::audio)]
fun test_new_zero_channels() {
    af::new(b"flac".to_string(), 0, 16, 44100, 1000, test_digest(), data::new_blob(1, confidentiality::new_unencrypted()));
}

#[test, expected_failure(abort_code = EInvalidBitDepth, location = audio::audio)]
fun test_new_invalid_bit_depth_12() {
    af::new(b"flac".to_string(), 2, 12, 44100, 1000, test_digest(), data::new_blob(1, confidentiality::new_unencrypted()));
}

#[test, expected_failure(abort_code = EInvalidBitDepth, location = audio::audio)]
fun test_new_invalid_bit_depth_0() {
    af::new(b"flac".to_string(), 2, 0, 44100, 1000, test_digest(), data::new_blob(1, confidentiality::new_unencrypted()));
}

#[test, expected_failure(abort_code = EInvalidSampleRate, location = audio::audio)]
fun test_new_zero_sample_rate() {
    af::new(b"flac".to_string(), 2, 16, 0, 1000, test_digest(), data::new_blob(1, confidentiality::new_unencrypted()));
}

#[test]
fun supported_sample_rates_preserve_metadata_and_duration() {
    let rates = vector[44_100u32, 48_000, 88_200, 96_000, 176_400, 192_000, 352_800, 384_000];
    let samples = vector[44_100u64, 48_000, 88_200, 96_000, 176_400, 192_000, 352_800, 384_000];
    rates.length().do!(|i| {
        let rate = rates[i];
        let audio = af::new(
            "flac", 2, 24, rate, samples[i], test_digest(),
            data::new_blob(1, confidentiality::new_unencrypted()),
        );
        assert_eq!(audio.sample_rate_hz(), rate);
        assert_eq!(audio.duration_ms(), 1000);
    });
}

#[test, expected_failure(abort_code = EInvalidSampleRate, location = audio::audio)]
fun sample_rate_below_supported_range_is_rejected() {
    af::new("flac", 2, 16, 32_000, 32_000, test_digest(), data::new_blob(1, confidentiality::new_unencrypted()));
}

#[test, expected_failure(abort_code = EInvalidSampleRate, location = audio::audio)]
fun sample_rate_between_supported_rates_is_rejected() {
    af::new("flac", 2, 16, 64_000, 64_000, test_digest(), data::new_blob(1, confidentiality::new_unencrypted()));
}

#[test, expected_failure(abort_code = EInvalidSampleRate, location = audio::audio)]
fun sample_rate_above_supported_range_is_rejected() {
    af::new("flac", 2, 16, 384_001, 384_001, test_digest(), data::new_blob(1, confidentiality::new_unencrypted()));
}

#[test, expected_failure(abort_code = EInvalidSamples, location = audio::audio)]
fun test_new_zero_samples() {
    af::new(b"flac".to_string(), 2, 16, 44100, 0, test_digest(), data::new_blob(1, confidentiality::new_unencrypted()));
}

#[test]
fun samples_above_former_limit_are_supported() {
    let audio = af::new(b"flac".to_string(), 2, 16, 44100, MAX_SAMPLES + 1, test_digest(), data::new_blob(1, confidentiality::new_unencrypted()));
    assert_eq!(audio.duration_ms(), 418_293_516_410_647);
}

#[test, expected_failure(abort_code = EEmptyFormat, location = audio::audio)]
fun test_new_empty_format() {
    af::new(b"".to_string(), 2, 16, 44100, 1000, test_digest(), data::new_blob(1, confidentiality::new_unencrypted()));
}

#[test, expected_failure(abort_code = EFormatTooLong, location = audio::audio)]
fun test_new_format_too_long() {
    // 17 chars > MAX_FORMAT_LENGTH (16)
    af::new(b"aaaaaaaaaaaaaaaaa".to_string(), 2, 16, 44100, 1000, test_digest(), data::new_blob(1, confidentiality::new_unencrypted()));
}

#[test, expected_failure(abort_code = EInvalidFormatChar, location = audio::audio)]
fun test_new_format_uppercase() {
    af::new(b"FLAC".to_string(), 2, 16, 44100, 1000, test_digest(), data::new_blob(1, confidentiality::new_unencrypted()));
}

#[test, expected_failure(abort_code = EInvalidFormatChar, location = audio::audio)]
fun test_new_format_with_slash() {
    af::new(b"audio/flac".to_string(), 2, 16, 44100, 1000, test_digest(), data::new_blob(1, confidentiality::new_unencrypted()));
}

#[test, expected_failure(abort_code = EInvalidDigestLength, location = audio::audio)]
fun test_new_wrong_digest_length() {
    // 1-byte digest != 32
    af::new(b"flac".to_string(), 2, 16, 44100, 1000, x"00", data::new_blob(1, confidentiality::new_unencrypted()));
}

#[test]
fun duration_rounds_down_without_losing_precision_before_division() {
    vector[1u64, 44, 45, 1000].do!(|samples| {
        let audio = af::new("flac", 2, 16, 44100, samples, test_digest(), data::new_blob(1, confidentiality::new_unencrypted()));
        let expected = if (samples == 1 || samples == 44) 0 else if (samples == 45) 1 else 22;
        assert_eq!(audio.duration_ms(), expected);
        let events = sui::event::events_by_type<af::AudioIngestedEvent>();
        assert_eq!(af::ingested_event_duration_ms(&events[events.length() - 1]), expected);
    });
}
