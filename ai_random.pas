{$INCLUDE game.inc}
unit ai_random;

interface

uses
  game;

type
  TAIRandom = class(TInterfacedObject, IArtificialIntelligence)
    public
      function FindMove(const board: TGameBoard; player: TPlayer): TPoint;
      class constructor Create();
  end;

implementation

function TAIRandom.FindMove(const board: TGameBoard; player: TPlayer): TPoint;
var
  TempPoints:    packed array of TPoint = nil;
  cell:          TCell;
  p, pt:         TPoint;
  accept, found: boolean;
  l, newl:       shortint;
begin
  result := nil;
  if (board.Initialized) and (board.GetWinner() = PlayerNone) then
    begin
      accept := false;
      pt := TPoint.Create();
      p := TPoint.Create();
      p.SetXY(-1, -1);

      repeat
        pt.SetXY(Random(board.BoardSide), Random(board.BoardSide));

        found := false;
        l := Length(TempPoints);
        if l > 0 then
          for p in TempPoints do
            if p.IsEqual(pt) then
              begin
                found := true;
                break;
              end;

        if not found then
          begin
            cell := board.GetCell(pt.X, pt.Y);
            if (cell <> nil) and (cell.State <> FreeCell) then
              begin
                newl := l + 1;
                if newl = board.BoardArea then
                  break;
                p := pt.Clone();
                SetLength(TempPoints, newl);
                TempPoints[l] := p;
                continue;
              end;
          end;

        if not found then
          accept := true;
      until accept = true;

      if accept then
        begin
          result := TPoint.Create();
          result.Assign(pt)
        end;
    end;
end;

class constructor TAIRandom.Create();
begin
  Randomize;
end;

end.
