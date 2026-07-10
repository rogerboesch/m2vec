# m2vec — write Vectrex games in Modula-2

**m2vec** compiles [Modula-2](https://en.wikipedia.org/wiki/Modula-2) directly to
a **Vectrex cartridge ROM**. You write a `.mod` module, run one command, and get
a `.bin` you can drop into any Vectrex emulator or flash to a cartridge — no C,
no assembly, no build system.

```sh
./m2vec examples/pong.mod -o pong.bin      # a playable Pong ROM
```

It targets the Vectrex's Motorola 6809 directly and produces tight code — on a
standard 6809 kernel benchmark it matches or beats the mature cmoc C compiler on
every test for speed. The point, though, is the language: Modula-2 gives you
records, real procedures, typed arrays and modules on a 1982 vector console.

---

## Requirements

| | |
|---|---|
| **OS** | macOS on Apple Silicon (the bundled `m2vec` binary is `arm64`). **Windows and Linux builds coming soon.** |
| **Anything else** | **Nothing.** m2vec has a built-in 6809 assembler — it produces the `.bin` ROM on its own, with no external assembler or toolchain. |
| **To run the ROM** | any Vectrex emulator (e.g. [ParaJVE](http://vide.malban.de/), VecX) or real hardware. |

## Install

Clone the repo — the `m2vec` binary sits at the root, ready to run:

```sh
git clone https://github.com/rogerboesch/m2vec.git
cd m2vec
./m2vec examples/pong.mod -o pong.bin
```

That's it — `pong.bin` is a complete Vectrex ROM. Optionally put the binary on
your `PATH` (`cp m2vec /usr/local/bin/`) so you can run `m2vec` from any project
directory. When you do, keep a `lib/` folder next to your `.mod` files (or set
`M2VEC_LIB`) so the `Vectrex*` modules are found.

## Compiling

```
m2vec <file.mod> [-o <out.bin>]
```

- Writes `<out>.bin` — the flat Vectrex ROM.
- Writes `<out>.asm` alongside it — the generated 6809 assembly, if you want to
  read what came out.
- Resolves imported library modules (`VectrexGraphics`, …) from `lib/` next to
  your source, or from `$M2VEC_LIB`.

Run the ROM in your Vectrex emulator. With a command-line runner such as
`vec2x`, for example:

```sh
vec2x right romfast.bin pong.bin empty.png
```

---

## Your first game

Here is a complete program — a dot that slides across the screen and bounces off
the edges (`examples/m2.mod`):

```modula2
MODULE M2;

FROM VectrexGraphics IMPORT WaitRecal, IntensityA, MovetoD, DrawLineD;

VAR x, dx: INTEGER;

BEGIN
  x := 0;
  dx := 3;
  LOOP
    WaitRecal;              (* sync to the frame — call once per frame *)
    IntensityA(7FH);        (* beam brightness, 0..$7F *)

    x := x + dx;            (* move, and bounce off the edges *)
    IF x >  100 THEN dx := -3 END;
    IF x < -100 THEN dx :=  3 END;

    MovetoD(0, x);          (* pen up to (y=0, x) *)
    DrawLineD(6, 0)         (* pen down: a short vertical stroke *)
  END
END M2.
```

The shape of every Vectrex program is the same: a `LOOP` that calls `WaitRecal`
once per frame, then draws. Positions are **relative** and given **y first, then
x**; the screen runs roughly −128..127 in both axes.

Compile and run it:

```sh
./m2vec examples/m2.mod -o m2.bin
```

## The Vectrex API

`IMPORT` these modules (they live in `lib/`). Every routine is a thin, zero-cost
binding to a Vectrex BIOS call.

### `VectrexGraphics`

| Procedure | Effect |
|---|---|
| `WaitRecal` | Recalibrate the beam and wait for the next frame. Call once per frame. |
| `ZeroBeam` | Reset the beam to the origin (0, 0). |
| `IntensityA(i)` | Set beam intensity, `0..$7F`. |
| `SetScale(s)` | Set the object scale/size, `0..$7F`. |
| `MovetoD(y, x)` | Move the beam (pen up) by a relative delta. |
| `DrawLineD(y, x)` | Draw one line (pen down) by a relative delta. |
| `DrawVLc(list)` | Draw a whole ROM vector list in one call (see below). |

### `VectrexInput`

| Procedure / variable | Effect |
|---|---|
| `JoyDigital` | Sample the enabled joystick axes into `Joy1X…Joy2Y`. |
| `Joy1X, Joy1Y, Joy2X, Joy2Y` | Axis results (−1 / 0 / +1) after `JoyDigital`. |
| `JoyEnable1X … JoyEnable2Y` | Write non-zero to enable an axis *before* `JoyDigital`. |
| `ReadButtons(): INTEGER` | Pressed-button mask (stick 1 = bits 0..3, stick 2 = bits 4..7). |
| `ReadButtonsMask(m): INTEGER` | Read buttons through a mask. |

### `VectrexAudio`

| Procedure | Effect |
|---|---|
| `ClearSound` | Silence all channels. |
| `DoSound` | Push the pending sound registers to the chip. Call once per frame. |
| `SoundBytes(data)` | Load `(register, value)` pairs (a ROM `CHAR` array) into the sound shadow. |
| `InitMusic(data)` | Start a ROM music table. |

### `VectrexText`

| Procedure / variable | Effect |
|---|---|
| `PrintNum(n, y, x)` | Draw the integer `n` at `(y, x)`. |
| `PrintStr(y, x, s)` | Draw a `$80`-terminated string. |
| `TextHeight, TextWidth` | Character cell size — set these (e.g. −8, 80) before printing. |

### Vector lists and ROM data

Shapes and sound are `CONST` arrays baked into the cartridge ROM. A `Draw_VLc`
vector list is a count byte followed by `count+1` signed `(y, x)` pairs — the
first pair is a relative move, the rest are lines:

```modula2
CONST ballVerts = ARRAY [0..10] OF CHAR { 4, 2,2, 252,252, 2,2, 254,2, 4,252 };
...
MovetoD(ball.y, ball.x);
DrawVLc(ballVerts);        (* draws the whole shape in one BIOS call *)
```

## The language at a glance

m2vec implements a practical subset of Modula-2 (PIM4). What you get:

- `MODULE`s with `PROCEDURE`s, including **`VAR` (by-reference) parameters** and
  **value-returning functions**.
- `INTEGER` (16-bit) and `BYTE`/`SHORTINT` (8-bit); `BOOLEAN`, `CHAR`, enums.
- `ARRAY`, `RECORD`, and **`CONST` ROM tables** (`ARRAY … OF … { … }`).
- `IF`/`ELSIF`/`ELSE`, `WHILE`, `REPEAT`, `LOOP`/`EXIT`, `FOR`, `CASE`.
- Bit builtins `SHL SHR BITAND BITOR BITXOR BITNOT`, and `FIXMUL(a,b)` = Q8.8
  fixed-point multiply for smooth motion.

What is **not** in this version: no heap / dynamic allocation, no `REAL`/floating
point, no file I/O, no 32-bit integers. Programs are a module body plus
procedures operating on module-global data — which is exactly what a Vectrex
game frame loop wants.

## Examples

| File | What it shows |
|---|---|
| [`examples/pong.mod`](examples/pong.mod) | **A full game.** Joystick-controlled paddle, ball-tracking AI opponent, wall/paddle collisions, on-screen score, and sound — using records, `VAR` parameters, a `BOOLEAN` function, ROM vector lists, and joystick input. |
| [`examples/m2.mod`](examples/m2.mod) | The bouncing dot from *Your first game* — the minimal frame loop with globals, arithmetic and relational tests. |
| [`examples/m3.mod`](examples/m3.mod) | Four bars whose positions come from a `CONST` ROM array, drawn with a `FOR` loop — the pattern for level/sprite data. |

Build any of them with `./m2vec examples/<name>.mod -o <name>.bin`.

---

*m2vec is an independent, from-scratch compiler. Vectrex is a trademark of its
respective owners; this project is not affiliated with or endorsed by them.*
