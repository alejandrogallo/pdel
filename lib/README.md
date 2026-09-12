# pd-lisp standard library

This directory is the source library for reusable Pure Data abstractions written
in `.pdel`.  Library patches are abstractions, not demos: they expose
`inlet`/`inlet~` and `outlet`/`outlet~` boundaries and do not own `dac~` or the
global DSP switch.

The library currently contains more than 170 definitions spanning synthesis,
MIDI/polyphony, effects, samplers and General MIDI-style instruments.

## Naming and calls

The source identity follows the path:

```text
lib/osc/saw~.pdel                 -> osc/saw~
lib/fx/chorus~.pdel               -> fx/chorus~
lib/gm/piano/acoustic-grand~.pdel -> gm/piano/acoustic-grand~
```

Use the `@pdel/` namespace from `pd-lisp`:

```elisp
(pd-lisp!
 (let* ((osc (@pdel/osc/supersaw~ 220))
        (filtered (@pdel/filter/lop~ osc 1800))
        (wet (@pdel/fx/chorus~ filtered)))
   (@dac~ wet wet)))
```

The `.pdel` source remains the definition used for source navigation.  For Pd
runtime lookup the compiler creates a flat abstraction name:

```text
@pdel/filter/lop~
  source:    lib/filter/lop~.pdel
  generated: .pd-pdel/pdel-filter-lop~.pd
  Pd object: [pdel-filter-lop~]
```

The exported parent patch contains a real Pd declaration record:

```pd
#X declare -path /absolute/path/to/.pd-pdel;
```

not an ordinary `[declare ...]` object.

## Source lookup

`.pdel` definitions are resolved through `pd-pdel-effective-lib-path`.
By default the stable roots are:

1. the `lib/` directory shipped with pd-lisp;
2. `~/.pd/`;
3. the current sketch directory, appended dynamically.

Additional roots can be added to `pd-pdel-lib-path`.

## Library families

See `INDEX.md` for the high-level namespace map and `GENERAL-MIDI.md` for GM
coverage.  Important namespaces include:

```text
signal/   osc/      lfo/      env/      filter/
fx/       sampler/  drums/    midi/     voice/
poly/     synth/    gm/
```

## Interface conventions

Where possible, related patches use predictable boundaries:

- effects: signal in -> signal out;
- oscillators/LFOs: frequency or rate -> signal out;
- GM voices: trigger + frequency -> signal out;
- `voice/`: `[note velocity]` list -> one voice;
- `poly/`: `[note velocity]` list -> mixed polyphonic signal;
- samplers: `readsf~`-style control messages -> signal output(s).

Fixed-name effects such as `fx/chorus~`, `fx/delay~`, `fx/reverb-room~` and
`fx/slapback~` intentionally have conservative defaults so they work as
one-argument building blocks.  Parameterized siblings such as
`fx/chorus-param~`, `fx/delay-param~`, and `fx/tremolo-param~` expose the most
useful controls.

## File metadata

Every `.pdel` starts with machine-readable comments:

```elisp
;;; pd-lib-name: osc/saw~
;;; pd-lib-category: oscillator
;;; pd-lib-inlets: ((0 signal frequency-hz))
;;; pd-lib-outlets: ((0 signal audio))
```

The `pd-lib-name == relative path without .pdel` invariant is deliberate.  It
lets the same resolver support compilation, completion, documentation and
future xref / `M-.` definition jumping.

## Style

Feed-forward signal flow should prefer nested functional application.  Explicit
`->` connections are reserved for graph structures that do not read naturally
as application, especially feedback loops in delay/flanger-style effects.
