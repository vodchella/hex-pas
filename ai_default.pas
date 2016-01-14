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

  TTwoBridgeConnectionDirection = (CDTopLeft, CDTop, CDTopRight, CDBottomRight, CDBottom, CDBottomLeft);
  TTwoBridgeConnectionState = (TBCSUnknown, TBCSInvalid, TBCSRealized, TBCSNotRealized, TBCSSafe, TBCSDangerous, TBCSFree);
  TTwoBridgeConnectionCarrier = array [0..1] of TRelativePoint;
  TTwoBridgeConnectionInformation = packed record
    direction:       TTwoBridgeConnectionDirection;
    state:           TTwoBridgeConnectionState;
    point:           TPointRecord;
    PriorityCell:    TCell;
    carrier:         TTwoBridgeConnectionCarrier;
    SideConnection:  boolean;
  end;

  TSideConnectionDirection = TTwoBridgeConnectionDirection;
  TSideConnectionCarrier = TTwoBridgeConnectionCarrier;
  TSideConnectionState = (SCSUnknown, SCSInvalid, SCSRealized, SCSSafe, SCSDangerous, SCSFree);
  TSideConnectionInformation = packed record
    direction:       TSideConnectionDirection;
    state:           TSideConnectionState;
    PriorityCell:    TCell;
    carrier:         TSideConnectionCarrier;
  end;

  TAIDefault = class(TInterfacedObject, IArtificialIntelligence)
    strict private
      Fboard: TGameBoard;
    private
      function  GetOppositePlayer(player: TPlayer): TPlayer;
      function  GetFirstMove(BoardSide: shortint): TPoint;
      function  GetPointByRelative(X, Y: shortint; var pt: TRelativePoint): TPointRecord;
      function  GetTwoBridgeConnectionPoint(X, Y: shortint; dir: TTwoBridgeConnectionDirection): TPointRecord;
      function  GetTwoBridgeConnectionCarrier(X, Y: shortint; dir: TTwoBridgeConnectionDirection): TTwoBridgeConnectionCarrier;
      function  GetTwoBridgeConnectionInfo(X, Y: shortint; dir: TTwoBridgeConnectionDirection; player: TPlayer): TTwoBridgeConnectionInformation;
      function  PointIsSideConnection(X, Y: shortint; player: TPlayer): boolean;
      function  GetSideConnectionCarrier(X, Y: shortint; dir: TSideConnectionDirection): TSideConnectionCarrier;
      function  GetSideConnectionInfo(X, Y: shortint; dir: TSideConnectionDirection; player: TPlayer): TSideConnectionInformation;
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

  Template_TwoBridgeConnectionsPoints: packed array [CDTopLeft..CDBottomLeft] of TRelativePoint = (
                              (X: -1; Y: -1), (X: 1;  Y: -2), (X: 2;  Y: -1),
                              (X: 1;  Y: 1),  (X: -1; Y: 2),  (X: -2; Y: 1)
                            );
  Template_ConnectionsCarriers: packed array [CDTopLeft..CDBottomLeft] of TTwoBridgeConnectionCarrier = (
                              ((X: -1; Y: 0),  (X: 0;  Y: -1)),
                              ((X: 0;  Y: -1), (X: 1;  Y: -1)),
                              ((X: 1;  Y: -1), (X: 1;  Y: 0)),
                              ((X: 1;  Y: 0),  (X: 0;  Y: 1)),
                              ((X: 0;  Y: 1),  (X: -1; Y: 1)),
                              ((X: -1; Y: 1),  (X: -1; Y: 0))
                            );



function  TAIDefault.GetSideConnectionInfo(X, Y: shortint; dir: TSideConnectionDirection; player: TPlayer): TSideConnectionInformation;
var
  SrcCell:        TCell;
  CarrierCells:   array [0..1] of TCell;
  carrier:        TSideConnectionCarrier;
  OppositePlayer: TPlayer;
begin
  carrier := Self.GetSideConnectionCarrier(X, Y, dir);

  result.direction := dir;
  result.carrier := carrier;

  if player = PlayerNone then
    begin
      result.state := SCSUnknown;
      exit();
    end;
  result.state := SCSInvalid;

  if Self.Fboard.CheckBounds(carrier[0].X, carrier[0].Y) and
     Self.Fboard.CheckBounds(carrier[1].X, carrier[1].Y) then
    begin
      if not (Self.PointIsSideConnection(carrier[0].X, carrier[0].Y, player) and
              Self.PointIsSideConnection(carrier[1].X, carrier[1].Y, player)) then
        exit();

      SrcCell := Self.Fboard.GetCell(X, Y);
      CarrierCells[0] := Self.Fboard.GetCell(carrier[0].X, carrier[0].Y);
      CarrierCells[1] := Self.Fboard.GetCell(carrier[1].X, carrier[1].Y);

      OppositePlayer := Self.GetOppositePlayer(player);

      if SrcCell.Player = player then
        begin
          if (CarrierCells[0].Player = player) or (CarrierCells[1].Player = player) then
            result.state := SCSRealized
          else if (CarrierCells[0].Player = OppositePlayer) and (CarrierCells[1].Player = PlayerNone) then
            begin
              result.state := SCSDangerous;
              result.PriorityCell := CarrierCells[1];
            end
          else if (CarrierCells[1].Player = OppositePlayer) and (CarrierCells[0].Player = PlayerNone) then
            begin
              result.state := SCSDangerous;
              result.PriorityCell := CarrierCells[0];
            end
          else if (CarrierCells[0].Player = PlayerNone) and (CarrierCells[1].Player = PlayerNone) then
            result.state := SCSSafe;
        end
      else if SrcCell.Player = PlayerNone then
        if (CarrierCells[0].Player = PlayerNone) and (CarrierCells[1].Player = PlayerNone) then
          result.state := SCSFree
        else if (CarrierCells[0].Player = player) and (CarrierCells[1].Player = PlayerNone) then
          result.state := SCSSafe
        else if (CarrierCells[1].Player = player) and (CarrierCells[0].Player = PlayerNone) then
          result.state := SCSSafe;
    end;
end;

function  TAIDefault.GetTwoBridgeConnectionInfo(X, Y: shortint; dir: TTwoBridgeConnectionDirection; player: TPlayer): TTwoBridgeConnectionInformation;
var
  point:   TPointRecord;
  DstCell, SrcCell: TCell;
  CarrierCells: array [0..1] of TCell;
  carrier: TTwoBridgeConnectionCarrier;
  CarrierIsFree: boolean;
  OppositePlayer: TPlayer;
begin
  point   := Self.GetTwoBridgeConnectionPoint(X, Y, dir);
  carrier := Self.GetTwoBridgeConnectionCarrier(X, Y, dir);

  result.direction := dir;
  result.point := point;
  result.carrier := carrier;
  result.state := TBCSInvalid;
  result.SideConnection := false;

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

      OppositePlayer := Self.GetOppositePlayer(player);

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

      result.SideConnection := PointIsSideConnection(DstCell.X, DstCell.Y, player);
      if not result.SideConnection then
        result.SideConnection := PointIsSideConnection(SrcCell.X, SrcCell.Y, player);
    end;
end;

function  TAIDefault.PointIsSideConnection(X, Y: shortint; player: TPlayer): boolean;
begin
  result := false;
  if player = PlayerOne then
    begin
      if Y in [0, Self.Fboard.MaxIndex] then
        result := true;
    end
  else if player = PlayerTwo then
    if X in [0, Self.Fboard.MaxIndex] then
      result := true;
end;

function  TAIDefault.GetOppositePlayer(player: TPlayer): TPlayer;
begin
  if player = PlayerOne then
    result := PlayerTwo
  else if player = PlayerTwo then
    result := PlayerOne
  else
    result := PlayerNone;
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
  carrier := Template_ConnectionsCarriers[dir];
  result[0] := Self.GetPointByRelative(X, Y, carrier[0]);
  result[1] := Self.GetPointByRelative(X, Y, carrier[1]);
end;

function  TAIDefault.GetSideConnectionCarrier(X, Y: shortint; dir: TSideConnectionDirection): TSideConnectionCarrier;
begin
  result := Self.GetTwoBridgeConnectionCarrier(X, Y, dir);
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
  sinfo:  TSideConnectionInformation;
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
          begin
            WriteLn('--------- TwoBridge:');
            for dir in [CDTopLeft..CDBottomLeft] do
              begin
              tbinfo := Self.GetTwoBridgeConnectionInfo(move.Cell.X, move.Cell.Y, dir, player);
              Write(tbinfo.direction, '; ', tbinfo.state);
              if (tbinfo.state = TBCSNotRealized) or (tbinfo.state = TBCSDangerous) then
                Write('; priority: (', tbinfo.PriorityCell.X, ', ', tbinfo.PriorityCell.Y, ')');
              if tbinfo.SideConnection then
                Write('; side_conn');
              WriteLn();
              end;
            WriteLn('--------- Side:');
            for dir in [CDTopLeft..CDBottomLeft] do
              begin
              sinfo := Self.GetSideConnectionInfo(move.Cell.X, move.Cell.Y, dir, player);
              Write(sinfo.direction, '; ', sinfo.state);
              if sinfo.state = SCSDangerous then
                Write('; priority: (', sinfo.PriorityCell.X, ', ', sinfo.PriorityCell.Y, ')');
              WriteLn();
              end;
          end;
        end;
    end;
end;

class constructor TAIDefault.Create();
begin
  Randomize;
end;

end.
