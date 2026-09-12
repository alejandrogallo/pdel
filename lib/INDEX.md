# pd-lisp standard library index

The standard library is source-first: every reusable definition is a `.pdel`
file and can be called from a sketch through the `@pdel/` namespace.

```elisp
(@pdel/fx/chorus~ signal)
(@pdel/gm/piano/acoustic-grand~ trigger frequency)
(@pdel/poly/saw4~ note-velocity-list)
```

At export time these become flat Pd abstractions such as
`pdel-fx-chorus~`, `pdel-gm-piano-acoustic-grand~`, and `pdel-poly-saw4~`.

## Main namespaces

- `signal/` — gain, mixing, crossfade, clipping, inversion and small signal utilities.
- `osc/` — sine, saw, square, triangle, pulse, supersaw, organ-spectrum and noise sources.
- `lfo/` — sine, saw, triangle and square modulation sources.
- `env/` — percussive, plucked, piano, mallet, brass, string and pad envelopes.
- `filter/` — low/high/band-pass, resonant, notch, DC-blocking and tone-shaping filters.
- `fx/` — drive, distortion, fuzz, clipping/limiting, tremolo, ring modulation, chorus,
  flanger, vibrato, delays, slapback, long echo, reverbs, widening and utility filters.
- `sampler/` — mono and stereo `readsf~` streaming abstractions.
- `drums/` — kick, snare, hats, clap, toms, cymbal, cowbell, rimshot, clave, shaker,
  conga, bongo and timpani-style percussion.
- `voice/` — reusable MIDI note/velocity voices.
- `poly/` — complete four-voice MIDI polyphonic instruments using Pd's `poly` allocator.
- `gm/` — lightweight General MIDI-family synthesis approximations.

See `GENERAL-MIDI.md` for the GM coverage and interface conventions.
