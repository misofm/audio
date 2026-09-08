# Security Audit — `audio`

**Revision:** not a git repository (working tree as of audit date) · **Date:** 2026-08-23 ·
**Toolchain:** sui 1.77.2

Audit of `audio`, the witness-gated `Audio` value primitive (verified
format/PCM metadata + Walrus blob reference). Verdict: **safe — no findings.**

## What it does

`audio::new<Ingester: drop>` (`audio.move:95`) is the only constructor. It
validates every embedded field, stamps the ingester's TypeName
(`with_defining_ids<Ingester>()`, `:145`), emits `AudioIngestedEvent`, and
returns an `Audio` — a `drop + store` value (not `key`), so it is an
embeddable primitive, not a standalone object; there is no ownership surface
to attack at this layer.

Threat model: a caller minting an `Audio` that misrepresents the underlying
data (wrong format, bogus digest, overflowed duration); a package
impersonating a trusted ingester.

## Checks performed (all hold)

- **Witness gate.** Creation requires a value of the caller's `Ingester:
  drop` type (`:103`) — constructible only in the ingester's own module
  (e.g. `audio_ingester::witness::new` is `public(package)`). The ingester
  identity is recorded as data (`ingester: TypeName`, `:28`), so consumers
  can distinguish trusted attesters from arbitrary ones — the module doc is
  explicit that multiple ingesters may coexist and trust is the consumer's
  call (`:12-14`).
- **Overflow safety.** `samples <= MAX_SAMPLES = u64::MAX / 1_000` (`:64`,
  `:124`) makes both `duration_ms` computations (`:131`, `:186`)
  overflow-proof: `18_446_744_073_709_551 * 1_000 = 18_446_744_073_709_551_000
  <= u64::MAX`. Checked arithmetically, not assumed.
- **Field validation.** Format: non-empty, ≤ 16 bytes, strictly lowercase
  `[a-z0-9]` (`:107-112`) — no separator/whitespace tricks for downstream
  parsers. Digest: exactly 32 bytes (`:114`). Channels > 0 (`:116`), bit
  depth ∈ {8,16,24,32} (`:118`), sample rate > 0 (`:120` — also prevents the
  division-by-zero in `duration_ms`), samples > 0 (`:122`).
- **Blob discipline.** `data.assert_is_blob()` (`:129`) rejects quilt/patch
  storage references, keeping blobs directly addressable.
- **No mutation surface.** All other functions are `&self` views
  (`:158-201`); `Audio` is immutable once constructed. `drop` on the struct
  lets holders destroy an `Audio` — harmless: it is an attestation value,
  and destruction can only discard one's own copy.

## Findings

None.

## Edge cases (verified)

- `samples * 1_000` overflow — guarded (see above); boundary value
  `MAX_SAMPLES` itself multiplies safely.
- Zero sample rate division — rejected at `:120`.
- Format charset bypass (uppercase, `-`, `_`, unicode) — rejected by the
  byte-range check at `:110`.
- Digest ≠ 32 bytes — rejected at `:114`.
- Impersonation of an ingester — requires constructing that package's
  witness; module-private construction prevents it.

## Verification

5 unit tests (`tests/audio_tests.move`) including validation abort paths.
Consumed by `audio_ingester` (attested path) and downstream recording
packages; both re-read for this audit.
