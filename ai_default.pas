{$INCLUDE game.inc}
unit ai_default;

interface

uses
  game;

type
  TAIDefault = class(TInterfacedObject, IArtificialIntelligence)
    private
      function GetFirstMove(BoardSide: shortint): TPoint;
    public
      function FindMove(const board: TGameBoard; player: TPlayer): TPoint;
      class constructor Create();
  end;

implementation

type
  TPointRecord = packed record
    X, Y: shortint;
  end;
  TPointRecordArray = packed array [0..0] of TPointRecord;
  PPointRecordArray = ^TPointRecordArray;

  TFirstMoves = packed record
    count: shortint;
    arr: PPointRecordArray;
  end;

var
  FirstMoves4:  packed array [1..2] of TPointRecord = (
                  (X: 1; Y: 2), (X: 2; Y: 1)
                );
  FirstMoves5:  packed array [1..1] of TPointRecord = (
                  (X: 2; Y: 2)
                );
  FirstMoves6:  packed array [1..2] of TPointRecord = (
                  (X: 2; Y: 3), (X: 3; Y: 2)
                );
  FirstMoves7:  packed array [1..2] of TPointRecord = (
                  (X: 2; Y: 4), (X: 4; Y: 2)
                );
  FirstMoves:   packed array [4..7] of TFirstMoves = (
                  (count: 2; arr: @FirstMoves4),
                  (count: 1; arr: @FirstMoves5),
                  (count: 2; arr: @FirstMoves6),
                  (count: 2; arr: @FirstMoves7)
                );

function TAIDefault.GetFirstMove(BoardSide: shortint): TPoint;
var
  moves: TFirstMoves;
  p: TPointRecord;
  i: shortint;
begin
  result := TPoint.Create();
  moves := FirstMoves[BoardSide];
  if moves.count > 1 then
    i := Random(moves.count)
  else
    i := 0;
  p := moves.arr^[i];
  result.SetXY(p.X, p.Y);
end;

function TAIDefault.FindMove(const board: TGameBoard; player: TPlayer): TPoint;
begin
  result := nil;
  if board.BoardSide > 7 then
    exit();
  if (Length(board.Moves) = 0) and (player = PlayerOne) then
    result := Self.GetFirstMove(board.BoardSide)
  else
    begin
    end;
end;

class constructor TAIDefault.Create();
begin
  Randomize;
end;

end.
