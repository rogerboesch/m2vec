(* m3.mod -- m2vec milestone M3 (arrays + ROM data tables).
   Four vertical bars whose horizontal positions come from a constant array
   baked into ROM, drawn with a FOR loop that indexes it. Exercises the
   array-constant extension (ROM tables), indexed reads, and array iteration --
   the shape VecAtac's room/sprite data will take. *)

MODULE M3;

FROM Vectrex IMPORT WaitRecal, IntensityA, MovetoD, DrawLineD;

(* a read-only table living in the cartridge ROM *)
CONST
  bars = ARRAY [0..3] OF INTEGER { -60, -20, 20, 60 };

VAR
  i, k: INTEGER;

BEGIN
  LOOP
    WaitRecal;
    IntensityA(7FH);
    FOR i := 0 TO 3 DO
      k := bars[i];
      MovetoD(0, k);
      DrawLineD(40, 0)
    END
  END
END M3.
