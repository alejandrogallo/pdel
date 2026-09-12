# General MIDI-style synthesis library

These patches use General MIDI names as a familiar taxonomy.  They are small,
Pd-Vanilla-oriented synthesis approximations rather than attempts to reproduce a
particular GM ROM, SoundFont, or hardware module.

## Interface

Most GM voices have two inlets and one signal outlet:

```text
inlet 0: control trigger
inlet 1: signal/control frequency in Hz
outlet 0: audio
```

Example:

```elisp
(@pdel/gm/brass/trumpet~ trigger frequency)
```

The `poly/` abstractions instead take a `[note velocity]` MIDI-style list and
perform four-voice allocation with Pd's `poly` object:

```elisp
(@pdel/poly/piano4~ midi-event)
(@pdel/poly/saw4~ midi-event)
```

Velocity zero acts as note-off for the sustained `voice/` instruments.

## Covered families

- Piano: acoustic grand, bright acoustic, electric grand, honky-tonk,
  electric piano 1/2, harpsichord, clavinet.
- Chromatic percussion: celesta, glockenspiel, music box, vibraphone,
  marimba, xylophone, tubular bells.
- Organ: drawbar, percussive, rock and church organ.
- Guitar: nylon, steel, clean electric, muted electric, overdriven and distorted.
- Bass: acoustic, finger, pick, fretless and two synth basses.
- Strings/ensemble: violin, viola, cello, contrabass, pizzicato, ensemble strings,
  synth strings and choir-like pad.
- Brass: trumpet, trombone, French horn, brass section and synth brass.
- Reed/pipe: alto sax, tenor sax, oboe, clarinet, flute, recorder and pan flute.
- Leads: square, saw, fifths and calliope-like lead.
- Pads: warm, polysynth, choir, sweep and atmosphere.
- Ethnic/plucked approximations: sitar, banjo and koto.

These are intentionally composable primitives.  Richer instruments can be built
by stacking them with `fx/`, `filter/`, `env/`, or additional `@pdel/...`
abstractions rather than making each patch monolithic.
