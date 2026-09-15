# Security Audit — `audio`

## Scope

This audit covers the permissionless V1 `audio::new` constructor and the
immutable `Audio` value in this package. Callers provide self-attested metadata
and a bare Walrus blob ID; the package validates metadata shape but does not download,
decode, or verify blob contents or the PCM digest. Nautilus-attested audio is a
separate future package.

## What it does

`audio::new` returns an `Audio` value with `copy`, `drop`, and `store`. `Audio`
has no `key` ability, so it is always embedded in an owning object such as a
recording master. The constructor is permissionless and has no event or
standalone ingestion record: callers decide whether and where to attach the
returned value.

## Checks performed

- **Field validation.** Format is non-empty, at most 16 bytes, and strictly
  lowercase `[a-z0-9]`. The PCM digest is exactly 32 bytes. Channels and
  samples are positive; bit depth is one of 8, 16, 24, or 32; and sample rate
  is one of the supported 44.1/48 kHz family rates.
- **Overflow safety.** `duration_ms` uses `u64::mul_div` with a u128
  intermediate, so the multiplication is checked without the former fixed
  sample-count limit.
- **Blob reference.** The `blob_id: u256` field is a bare storage reference;
  encryption metadata and blob construction are outside this V1 primitive.
- **No mutation surface.** All accessors borrow immutable `Audio` fields.
  `drop` can discard an audio value or copy without affecting any other value.

## Verification

The unit suite covers valid metadata, all validation abort paths, supported
sample rates, duration rounding and maximum sample counts. It also verifies
that one constructor call, a discarded constructor result, and repeated
construction produce zero events.
