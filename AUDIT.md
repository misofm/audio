# Security Audit — `audio`

## Scope

This audit covers `audio::new` and the `Audio<Verifier>` value in this package,
at the source that pins ori `367ed5fe92a8b62da02c1116537cf08d111e0789`. The
package checks the shape of the facts a verifier supplies. It does not download,
decode or verify blob contents or the PCM digest; that is the verifier package's
responsibility (for example `misofm/verified-audio`).

## What it does

`audio::new<Verifier: drop>` takes the verifier's witness and returns an
`Audio<Verifier>` with `copy`, `drop` and `store`. `Audio` has no `key`, so it
is always embedded in an owning object. Each call emits one
`AudioCreatedEvent<Verifier>` carrying every fact, including `format` and the
blob ID. `format` is emitted but not stored.

## Checks performed

- **Verifier gating.** Only code that can construct a `Verifier` value can call
  `new`, so every `Audio` names the type that vouched for it. The phantom
  parameter does not establish that any verification happened: anyone can
  publish a witness. Consumers must pin the verifier types they trust and must
  not treat a generic `Audio<Verifier>` as trusted.
- **Field validation.**
  - Format is 1 to 16 bytes of lowercase `[a-z0-9]`.
  - The blob's confidentiality is `Unencrypted`.
  - Channels are positive.
  - Bit depth is 1 to 32.
  - Sample rate is positive.
  - Samples per channel are positive.
  - The PCM digest is exactly 32 bytes.
- **Duration bound.** `new` rejects facts whose duration in milliseconds does not
  fit in a `u64`, computed with a `u128` intermediate. So `duration_ms`
  (`u64::mul_div`) cannot abort for any `Audio` that exists.
- **Shared blob type.** `WalrusBlob` comes from the same ori deployment as
  `misofm/cover-art`, so references are one type across packages.
- **No mutation surface.** All accessors borrow immutable fields. `drop` can
  discard a value or copy without affecting any other value.

## Verification

The unit suite has 25 tests at 100% line coverage. It covers:
- the stored facts and every field of the emitted event;
- separate types and events per verifier;
- each canonical format name;
- bit depth bounds (1 and 32 accepted, 0 and 33 rejected);
- minimal values;
- duration rounding, the largest sample count at the largest sample rate, and
  the longest duration at 1 Hz;
- every abort path, including an encrypted blob and a duration beyond `u64`.
