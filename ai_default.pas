{$INCLUDE game.inc}
unit ai_default;

interface

uses
  game;

type
  TPointRecord = packed record
    X, Y: shortint;
  end;
  TRelativePoint = TPointRecord;

  TTwoBridgeConnectionDirection = (TBCDTopLeft, TBCDTop, TBCDTopRight, TBCDBottomRight, TBCDBottom, TBCDBottomLeft);
  TTwoBridgeConnectionState = (TBCSUnknown, TBCSInvalid, TBCSRealized, TBCSNotRealized, TBCSSafe, TBCSDangerous, TBCSFree);
  TTwoBridgeConnectionCarrier = array [0..1] of TRelativePoint;
  TTwoBridgeConnectionInformation = packed record
    direction:       TTwoBridgeConnectionDirection;
    state:           TTwoBridgeConnectionState;
    point:           TPointRecord;
    PriorityCell:    TCell;
    carrier:         TTwoBridgeConnectionCarrier;
    BoardConnection: boolean;
  end;

  TAIDefault = class(TInterfacedObject, IArtificialIntelligence)
    strict private
      Fboard: TGameBoard;
    private
      function  GetFirstMove(BoardSide: shortint): TPoint;
      function  GetPointByRelative(X, Y: shortint; var pt: TRelativePoint): TPointRecord;
      function  GetTwoBridgeConnectionPoint(X, Y: shortint; dir: TTwoBridgeConnectionDirection): TPointRecord;
      function  GetTwoBridgeConnectionCarrier(X, Y: shortint; dir: TTwoBridgeConnectionDirection): TTwoBridgeConnectionCarrier;
      function  GetTwoBridgeConnectionInfo(X, Y: shortint; dir: TTwoBridgeConnectionDirection; player: TPlayer): TTwoBridgeConnectionInformation;
    public
      function  FindMove(const board: TGameBoard; player: TPlayer): TPoint;
      class constructor Create();
  end;

implementation

type
  TPointRecordArray = packed array [0..0] of TPointRecord;
  PPointRecordArray = ^TPointRecordArray;

  TFirstMoves = packed record
    count: shortint;
    arr: PPointRecordArray;
  end;

  TBoard = packed array of packed array of shortint;

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

  Template_TwoBridgeConnectionsPoints: packed array [TBCDTopLeft..TBCDBottomLeft] of TRelativePoint = (
                              (X: -1; Y: -1), (X: 1;  Y: -2), (X: 2;  Y: -1),
                              (X: 1;  Y: 1),  (X: -1; Y: 2),  (X: -2; Y: 1)
                            );
  Template_TwoBridgeConnectionsCarriers: packed array [TBCDTopLeft..TBCDBottomLeft] of TTwoBridgeConnectionCarrier = (
                              ((X: -1; Y: 0),  (X: 0;  Y: -1)),
                              ((X: 0;  Y: -1), (X: 1;  Y: -1)),
                              ((X: 1;  Y: -1), (X: 1;  Y: 0)),
                              ((X: 1;  Y: 0),  (X: 0;  Y: 1)),
                              ((X: 0;  Y: 1),  (X: -1; Y: 1)),
                              ((X: -1; Y: 1),  (X: -1; Y: 0))
                            );

function  TAIDefault.GetTwoBridgeConnectionInfo(X, Y: shortint; dir: TTwoBridgeConnectionDirection; player: TPlayer): TTwoBridgeConnectionInformation;
var
  point:   TPointRecord;
  DstCell, SrcCell: TCell;
  carrier: TTwoBridgeConnectionCarrier;
  CarrierCells: array [0..1] of TCell;
  CarrierIsFree: boolean;
  OppositePlayer: TPlayer;
begin
  point   := Self.GetTwoBridgeConnectionPoint(X, Y, dir);
  carrier := Self.GetTwoBridgeConnectionCarrier(X, Y, dir);

  result.direction := dir;
  result.point := point;
  result.carrier := carrier;
  result.state := TBCSInvalid;
  result.BoardConnection := false;

  if player = PlayerNone then
    begin
      result.state := TBCSUnknown;
      exit();
    end;

  if Self.Fboard.CheckBounds(carrier[0].X, carrier[0].Y) and
     Self.Fboard.CheckBounds(carrier[1].X, carrier[1].Y) and
     Self.Fboard.CheckBounds(point.X, point.Y) then
    begin
      SrcCell := Self.Fboard.GetCell(X, Y);
      DstCell := Self.Fboard.GetCell(point.X, point.Y);
      CarrierCells[0] := Self.Fboard.GetCell(carrier[0].X, carrier[0].Y);
      CarrierCells[1] := Self.Fboard.GetCell(carrier[1].X, carrier[1].Y);

      if player = PlayerOne then
        OppositePlayer := PlayerTwo
      else
        OppositePlayer := PlayerOne;

      CarrierIsFree := false;
      if (CarrierCells[0].Player = PlayerNone) and (CarrierCells[1].Player = PlayerNone) then
        CarrierIsFree := true;

      if (SrcCell.Player = player) and (DstCell.Player = Player) then
        begin
          if CarrierIsFree then
            result.state := TBCSSafe
          else if (CarrierCells[0].Player = player) or (CarrierCells[1].Player = player) then
            result.state := TBCSRealized
          else if (CarrierCells[0].Player = OppositePlayer) and (CarrierCells[1].Player = PlayerNone) then
            begin
              result.state := TBCSDangerous;
              result.PriorityCell := CarrierCells[1];
            end
          else if (CarrierCells[1].Player = OppositePlayer) and (CarrierCells[0].Player = PlayerNone) then
            begin
              result.state := TBCSDangerous;
              result.PriorityCell := CarrierCells[0];
            end;
        end
      else if (SrcCell.Player = player) and (DstCell.Player = PlayerNone) and CarrierIsFree then
        begin
          result.state := TBCSNotRealized;
          result.PriorityCell := DstCell;
        end
      else if (DstCell.Player = player) and (SrcCell.Player = PlayerNone) and CarrierIsFree then
        begin
          result.state := TBCSNotRealized;
          result.PriorityCell := SrcCell;
        end
      else if (DstCell.Player = PlayerNone) and (SrcCell.Player = PlayerNone) and CarrierIsFree then
        result.state := TBCSFree;

      if player = PlayerOne then
        begin
          if (SrcCell.Y in [0, Self.Fboard.MaxIndex]) or (DstCell.Y in [0, Self.Fboard.MaxIndex]) then
            result.BoardConnection := true;
        end
      else if player = PlayerTwo then
        if (SrcCell.X in [0, Self.Fboard.MaxIndex]) or (DstCell.X in [0, Self.Fboard.MaxIndex]) then
          result.BoardConnection := true;
    end;
end;

function  TAIDefault.GetPointByRelative(X, Y: shortint; var pt: TRelativePoint): TPointRecord;
begin
  result.X := X + pt.X;
  result.Y := Y + pt.Y;
end;

function  TAIDefault.GetTwoBridgeConnectionPoint(X, Y: shortint; dir: TTwoBridgeConnectionDirection): TPointRecord;
begin
  result := Self.GetPointByRelative(X, Y, Template_TwoBridgeConnectionsPoints[dir]);
end;

function  TAIDefault.GetTwoBridgeConnectionCarrier(X, Y: shortint; dir: TTwoBridgeConnectionDirection): TTwoBridgeConnectionCarrier;
var
  carrier: TTwoBridgeConnectionCarrier;
begin
  carrier := Template_TwoBridgeConnectionsCarriers[dir];
  result[0] := Self.GetPointByRelative(X, Y, carrier[0]);
  result[1] := Self.GetPointByRelative(X, Y, carrier[1]);
end;

function  TAIDefault.GetFirstMove(BoardSide: shortint): TPoint;
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
var
  arr:    TBoard;
  move:   TMove;
  dir:    TTwoBridgeConnectionDirection;
  tbinfo: TTwoBridgeConnectionInformation;
begin
  result := nil;
  if board.BoardSide > 7 then
    exit();
  if (Length(board.Moves) = 0) and (player = PlayerOne) then
    result := Self.GetFirstMove(board.BoardSide)
  else
    begin
      Self.Fboard := board;
      SetLength(arr, board.BoardSide, board.BoardSide);
      for move in board.Moves do
        begin
        arr[move.Cell.X, move.Cell.Y] := 100;
        if move.Cell.Player = player then
          for dir in [TBCDTopLeft..TBCDBottomLeft] do
            begin
            tbinfo := Self.GetTwoBridgeConnectionInfo(move.Cell.X, move.Cell.Y, dir, player);
            Write(tbinfo.direction, '; ', tbinfo.state);
            if (tbinfo.state = TBCSNotRealized) or (tbinfo.state = TBCSDangerous) then
              Write('; priority: (', tbinfo.PriorityCell.X, ', ', tbinfo.PriorityCell.Y, ')');
            if tbinfo.BoardConnection then
              Write('; board_conn');
            WriteLn();
            end;
        end;
    end;
end;

class constructor TAIDefault.Create();
begin
  Randomize;
end;

end.
