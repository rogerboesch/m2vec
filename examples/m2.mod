(* m2.mod -- m2vec milestone M2.
   A dot that slides left and right across the screen and bounces off the
   edges. Exercises globals, integer arithmetic, IF with relational tests, and
   BIOS calls whose arguments are computed at run time. *)

MODULE M2;

FROM Vectrex IMPORT WaitRecal, IntensityA, MovetoD, DrawLineD;

VAR
  x, dx: INTEGER;

BEGIN
  x := 0;
  dx := 3;
  LOOP
    WaitRecal;
    IntensityA(7FH);

    (* advance and bounce *)
    x := x + dx;
    IF x > 100 THEN dx := -3; END;
    IF x < -100 THEN dx := 3; END;

    (* draw a short vertical stroke as the "dot" at horizontal position x *)
    MovetoD(0, x);
    DrawLineD(6, 0)
  END
END M2.
