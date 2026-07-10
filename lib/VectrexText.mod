(* VectrexText -- reusable text helpers on top of the BIOS string printer.

   This is a library module: it is not run on its own but IMPORTed by a program,
   whose compiler pulls these declarations into the same ROM. Its own body is
   empty. Names (PrintNum, numBuf) must be unique across the whole program. *)

MODULE VectrexText;

FROM VectrexGraphics IMPORT ZeroBeam;
FROM VectrexText IMPORT PrintStr;   (* the BIOS binding from VectrexText.def *)

VAR
  numBuf: ARRAY [0..2] OF CHAR;   (* two digits + $80 terminator *)

(* Print a two-digit number (00..99) at (y, x). Builds the digit string in
   numBuf and hands it to the BIOS string printer. Assigning an INTEGER to a
   CHAR element stores its low byte, and ASCII '0' is 48. Print_Str_d positions
   relative to the beam origin, so reset it first (ZeroBeam) or the text drifts
   with whatever was drawn last. *)
PROCEDURE PrintNum(n, y, x: INTEGER);
BEGIN
  numBuf[0] := 48 + (n DIV 10);
  numBuf[1] := 48 + (n MOD 10);
  numBuf[2] := 128;
  ZeroBeam;
  PrintStr(y, x, numBuf)
END PrintNum;

BEGIN
END VectrexText.
