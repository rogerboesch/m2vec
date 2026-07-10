(* pong.mod -- Vectrex Pong, ported to Modula-2 from vectrec/examples/pong.c.

   A one-player game: the left paddle is controlled with joystick 1 (up/down),
   the right paddle is a ball-tracking AI, and the ball bounces off the walls
   and paddles. It exercises the features a real game needs under m2vec: records,
   VAR (by-reference) parameters, procedures with return values, ROM constant-
   array vector lists, joystick input via RAM-variable bindings, and the BIOS
   draw loop.

   Simplifications vs the C original: no sprintf score text and no sound. *)

MODULE Pong;

FROM VectrexGraphics IMPORT WaitRecal, IntensityA, MovetoD, DrawVLc, ZeroBeam, SetScale;
FROM VectrexInput IMPORT JoyDigital, Joy1Y, JoyEnable1X, JoyEnable1Y;
FROM VectrexAudio IMPORT ClearSound, DoSound, SoundBytes;
FROM VectrexText IMPORT PrintNum, TextHeight, TextWidth;

CONST
  ScreenMaxY = 120;
  ScreenMinY = -120;
  PaddleSpeed = 4;
  (* A paddle is drawn from p.y downward by its height (20), so clamp its top
     so the whole paddle stays inside the border (-127..127). *)
  PaddleMaxY = 127;
  PaddleMinY = -107;

TYPE
  GameObject = RECORD
    x, y: INTEGER;   (* centre position *)
    hw, hh: INTEGER  (* half width / half height *)
  END;

(* Vector lists baked into ROM. Draw_VLc format: a count, then count+1 signed
   (y,x) byte pairs -- the first pair is a relative move, the rest are lines.
   Values match the working pong.c (negatives written as their byte value). *)
CONST
  paddleVerts = ARRAY [0..8]  OF CHAR { 3, 0,5, 236,0, 0,251, 20,0 };
  ballVerts   = ARRAY [0..10] OF CHAR { 4, 2,2, 252,252, 2,2, 254,2, 4,252 };
  borderVerts = ARRAY [0..16] OF CHAR { 7, 127,0, 127,0, 0,127, 0,127, 128,0, 128,0, 0,128, 0,128 };

(* A short "hit" blip: PSG (register, value) pairs, terminated by $FF. Loaded
   into the sound shadow by SoundBytes; Do_Sound plays it. From pong.c. *)
CONST
  hitSound = ARRAY [0..28] OF CHAR
    { 0,0, 1,0, 2,192, 3,0, 4,0, 5,0, 6,0, 7,61, 8,0, 9,31, 10,0, 11,255, 12,12, 13,0, 255 };

VAR
  paddle: ARRAY [0..1] OF GameObject;
  ball, border: GameObject;
  ballDX, ballDY: INTEGER;
  score1, score2: INTEGER;

(* --- helpers ------------------------------------------------------------- *)

(* Move a paddle toward a target y, without leaving the screen. Modula-2 has no
   short-circuit AND here, so the compound conditions are nested IFs. *)
PROCEDURE TrackPaddle(VAR p: GameObject; targetY: INTEGER);
BEGIN
  IF p.y < targetY THEN
    IF p.y < PaddleMaxY THEN p.y := p.y + PaddleSpeed END
  END;
  IF p.y > targetY THEN
    IF p.y > PaddleMinY THEN p.y := p.y - PaddleSpeed END
  END
END TrackPaddle;

(* Move a paddle from a joystick direction: dir > 0 is up, dir < 0 is down.
   Stays within the border, like TrackPaddle. *)
PROCEDURE ControlPaddle(VAR p: GameObject; dir: INTEGER);
BEGIN
  IF dir > 0 THEN
    IF p.y < PaddleMaxY THEN p.y := p.y + PaddleSpeed END
  END;
  IF dir < 0 THEN
    IF p.y > PaddleMinY THEN p.y := p.y - PaddleSpeed END
  END
END ControlPaddle;

(* Axis-aligned bounding-box overlap of two objects. No short-circuit && in
   Modula-2, so the four conditions are nested IFs. *)
PROCEDURE Colliding(VAR a: GameObject; VAR b: GameObject): BOOLEAN;
  VAR dx, dy: INTEGER;
BEGIN
  dx := a.x - b.x;
  IF dx < 0 THEN dx := -dx END;
  dy := a.y - b.y;
  IF dy < 0 THEN dy := -dy END;
  IF dx < a.hw + b.hw THEN
    IF dy < a.hh + b.hh THEN
      RETURN 1
    END
  END;
  RETURN 0
END Colliding;

(* --- game ---------------------------------------------------------------- *)

PROCEDURE GameInit;
BEGIN
  paddle[0].x := -100; paddle[0].y := 0; paddle[0].hw := 5; paddle[0].hh := 20;
  paddle[1].x :=  100; paddle[1].y := 0; paddle[1].hw := 5; paddle[1].hh := 20;
  ball.x := 0; ball.y := 50; ball.hw := 4; ball.hh := 4;
  border.x := -127; border.y := -127; border.hw := 127; border.hh := 127;
  ballDX := 2; ballDY := 1;
  score1 := 0; score2 := 0;
  (* enable joystick 1 X and Y so JoyDigital fills Joy1X/Joy1Y *)
  JoyEnable1X := 1; JoyEnable1Y := 3;
  (* readable text size (fast BIOS leaves these at 0 = invisible) *)
  TextHeight := 248;   (* -8 *)
  TextWidth := 80;
  ClearSound
END GameInit;

PROCEDURE GameUpdate;
BEGIN
  ball.x := ball.x + ballDX;
  ball.y := ball.y + ballDY;

  (* bounce off top / bottom *)
  IF ball.y > ScreenMaxY THEN ballDY := -ballDY END;
  IF ball.y < ScreenMinY THEN ballDY := -ballDY END;

  (* ball past a far wall scores a point and recentres the ball *)
  IF ball.x > 120 THEN score1 := score1 + 1; ball.x := 0; ball.y := 0 END;
  IF ball.x < -120 THEN score2 := score2 + 1; ball.x := 0; ball.y := 0 END;

  (* bounce off the paddles: only when moving toward the paddle, then reverse
     once, push the ball clear of the paddle (so it cannot re-trigger next
     frame), and blip. This makes each hit a single clean event. *)
  IF Colliding(ball, paddle[0]) = 1 THEN
    IF ballDX < 0 THEN
      ballDX := -ballDX;
      ball.x := paddle[0].x + paddle[0].hw + ball.hw + 1;
      SoundBytes(hitSound)
    END
  END;
  IF Colliding(ball, paddle[1]) = 1 THEN
    IF ballDX > 0 THEN
      ballDX := -ballDX;
      ball.x := paddle[1].x - paddle[1].hw - ball.hw - 1;
      SoundBytes(hitSound)
    END
  END;

  (* left paddle: player (joystick 1); right paddle: AI tracking the ball *)
  JoyDigital;
  ControlPaddle(paddle[0], Joy1Y);
  TrackPaddle(paddle[1], ball.y)
END GameUpdate;

PROCEDURE GameDraw;
BEGIN
  SetScale(7FH);
  ZeroBeam; MovetoD(border.y, border.x); DrawVLc(borderVerts);
  ZeroBeam; MovetoD(paddle[0].y, paddle[0].x); DrawVLc(paddleVerts);
  ZeroBeam; MovetoD(paddle[1].y, paddle[1].x); DrawVLc(paddleVerts);
  ZeroBeam; MovetoD(ball.y, ball.x); DrawVLc(ballVerts);
  (* scores near the top: player 1 left, player 2 right *)
  PrintNum(score1, 110, -90);
  PrintNum(score2, 110, 70)
END GameDraw;

BEGIN
  GameInit;
  LOOP
    WaitRecal;
    DoSound;      (* clear last frame's sound AFTER it played for a full frame *)
    IntensityA(7FH);
    GameUpdate;   (* a bounce here sets the sound ON; it plays through the next
                     WaitRecal (~20ms) before the next DoSound clears it *)
    GameDraw
  END
END Pong.
