# Instrument examples

These are small synthesis studies in the user-facing `pd-lisp!` syntax.  They
prefer **function application / nesting** for feed-forward signal flow and use
explicit `(-> ...)` connections only where graph topology genuinely needs it
(for example, the feedback edge in Karplus-Strong).  Outlet selection uses
`(@ N FORM)`.

Current examples:

- `kick.pdel` — pitch-swept sine kick.
- `snare.pdel` — filtered noise plus pitched body.
- `hihat.pdel` — high-passed/band-passed noise.
- `tom.pdel` — pitch-swept electronic tom.
- `clap.pdel` — multi-burst filtered-noise clap.
- `cowbell.pdel` — two hard-edged metallic partials.
- `cymbal.pdel` — inharmonic metallic oscillator bank.
- `fm-bell.pdel` — two-operator FM bell.
- `subtractive-bass.pdel` — bipolar saw, filter, envelope.
- `acid-bass.pdel` — resonant/clipped 303-inspired study.
- `detuned-lead.pdel` — beating oscillator lead.
- `additive-organ.pdel` — weighted harmonic partials.
- `rhodes.pdel` — FM electric-piano/tine study.
- `karplus-string.pdel` — plucked-string feedback delay.

## Style

Prefer this:

```elisp
(pd-lisp!
 (dsp-1)
 (let* ((env (@vline~ (@msg ["1 1, 0 100 1"]
                              (bng! nil :label hit))))
        (voice (@*~ (@osc~ [220]) env)))
   (@dac~ voice (@ 1 voice))))
```

over creating one variable per Pd object and connecting every pair with `->`.
Names are still useful for reused values, semantic stages, and cycles.

## Design references

The examples are independent compact implementations, not line-by-line source
translations.  Useful Pd references include:

- Derek Kwan's `pdksynth`: drum synths, FM/gong, Karplus-Strong, brass, detuned
  saw/pad, organ, piano, Rhodes and strings:
  https://github.com/derekxkwan/pdksynth
- DIY-perk: a collection of mostly-Vanilla percussion patches including kick,
  hi-hat, snare, clap, cowbell, toms, bell and crash cymbal:
  https://forum.puredata.info/topic/1821/diy-library-part-i-diy-perk
- Pure Data's bundled audio examples for canonical delay/filter/DSP idioms:
  https://github.com/pure-data/pure-data/tree/master/doc/3.audio.examples

The Karplus example keeps its feedback edge explicit because a cyclic signal
graph is not naturally representable as ordinary nested function application.
Pd delay feedback can also be sensitive to DSP scheduling/block order.
