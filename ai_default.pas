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

  TTwoBridgeConnectionDirection = (CDUnknown, CDTopLeft, CDTop, CDTopRight, CDBottomRight, CDBottom, CDBottomLeft);
  TTwoBridgeConnectionState = (TBCSUnknown, TBCSInvalid, TBCSRealized, TBCSNotRealized, TBCSSafe, TBCSDangerous, TBCSFree);
  TTwoBridgeConnectionCarrier = array [0..1] of TRelativePoint;
  TTwoBridgeConnectionInformation = packed record
    direction:            TTwoBridgeConnectionDirection;
    state:                TTwoBridgeConnectionState;
    point:                TPointRecord;
    PriorityCell:         TCell;
    carrier:              TTwoBridgeConnectionCarrier;
    SideConnection,
    EnemySideConnection:  boolean;
  end;

  TSideConnectionDirection = (CDSUnknown, CDSTop, CDSRight, CDSBottom, CDSLeft);
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

  TBoard = class
    private
      ai: TAIDefault;
      player: TPlayer;
      arr: packed array of packed array of shortint;
      minval: shortint;
      procedure InitArray(ArrSize: shortint);
      procedure DecArrVal(Px, Py: shortint; val: shortint = 1; NoDecRepeatedly: boolean = false);
      procedure UpdateArrBySideConn(Ax, Ay: shortint; var SideInfo: TSideConnectionInformation; NoDecRepeatedly: boolean = false);
      procedure UpdateArrByTwoBridgeConn(Ax, Ay: shortint; var tb: TTwoBridgeConnectionInformation; NoDecRepeatedly: boolean);
      function  AnalyzeSideConnectionsForPoint(Ax, Ay: shortint): TSideConnectionDirection;
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

  Template_TwoBridgeConnectionsPoints: packed array [CDTopLeft..CDBottomLeft] of TRelativePoint = (
                              (X: -1; Y: -1), (X: 1;  Y: -2), (X: 2;  Y: -1),
                              (X: 1;  Y: 1),  (X: -1; Y: 2),  (X: -2; Y: 1)
                            );
  Template_SideConnectionsCarriers: packed array [CDSTop..CDSLeft] of TTwoBridgeConnectionCarrier = (
                              ((X: 0;  Y: -1), (X: 1;  Y: -1)),
                              ((X: 1;  Y: -1), (X: 1;  Y: 0)),
                              ((X: 0;  Y: 1),  (X: -1; Y: 1)),
                              ((X: -1; Y: 1),  (X: -1; Y: 0))
                            );
  Template_ConnectionsCarriers: packed array [CDTopLeft..CDBottomLeft] of TTwoBridgeConnectionCarrier = (
                              ((X: -1; Y: 0),  (X: 0;  Y: -1)),
                              ((X: 0;  Y: -1), (X: 1;  Y: -1)),
                              ((X: 1;  Y: -1), (X: 1;  Y: 0)),
                              ((X: 1;  Y: 0),  (X: 0;  Y: 1)),
                              ((X: 0;  Y: 1),  (X: -1; Y: 1)),
                              ((X: -1; Y: 1),  (X: -1; Y: 0))
                            );

  SideConnAdjacentTwoBridgeConns: packed array [CDSUnknown..CDSLeft] of array [0..1] of TTwoBridgeConnectionDirection = (
                              (* CDSUnknown *) (CDUnknown, CDUnknown),
                              (* CDSTop     *) (CDTopLeft, CDTopRight),
                              (* CDSRight   *) (CDTop, CDBottomRight),
                              (* CDSBottom  *) (CDBottomRight, CDBottomLeft),
                              (* CDSLeft    *) (CDBottom, CDTopLeft)
                            );


(*
 *  TBoard methods
 *)
procedure TBoard.DecArrVal(Px, Py: shortint; val: shortint = 1; NoDecRepeatedly: boolean = false);
var
  arrval: shortint;
begin
  arrval := arr[Px, Py];
  if NoDecRepeatedly and ((arrval < 50) or (arrval = 99)) then
    exit();
  arrval -= val;
  arr[Px, Py] := arrval;
  if arrval < minval then
    minval := arrval;
end;

procedure TBoard.UpdateArrBySideConn(Ax, Ay: shortint; var SideInfo: TSideConnectionInformation; NoDecRepeatedly: boolean = false);
begin
  if SideInfo.state = SCSSafe then
    begin
      Self.DecArrVal(SideInfo.carrier[0].X, SideInfo.carrier[0].Y, 1, NoDecRepeatedly);
      Self.DecArrVal(SideInfo.carrier[1].X, SideInfo.carrier[1].Y, 1, NoDecRepeatedly);
    end;
  if SideInfo.state = SCSFree then
    Self.DecArrVal(Ax, Ay, 2, NoDecRepeatedly);
  if SideInfo.state = SCSDangerous then
    Self.DecArrVal(SideInfo.PriorityCell.X, SideInfo.PriorityCell.Y, 5, NoDecRepeatedly);
end;

procedure TBoard.UpdateArrByTwoBridgeConn(Ax, Ay: shortint; var tb: TTwoBridgeConnectionInformation; NoDecRepeatedly: boolean);
begin
  if tb.state in [TBCSSafe, TBCSFree] then
    begin
      Self.DecArrVal(tb.carrier[0].X, tb.carrier[0].Y, 1, NoDecRepeatedly);
      Self.DecArrVal(tb.carrier[1].X, tb.carrier[1].Y, 1, NoDecRepeatedly);
    end;
  if tb.state = TBCSFree then
    Self.DecArrVal(Ax, Ay, 2, NoDecRepeatedly);
  if tb.state = TBCSNotRealized then
    begin
      if Self.AnalyzeSideConnectionsForPoint(tb.PriorityCell.X, tb.PriorityCell.Y) <> CDSUnknown then
        Self.DecArrVal(tb.PriorityCell.X, tb.PriorityCell.Y, 4{, NoDecRepeatedly})
      else if tb.EnemySideConnection then
        Self.DecArrVal(tb.PriorityCell.X, tb.PriorityCell.Y, 1, NoDecRepeatedly)
      else if not tb.SideConnection then
        Self.DecArrVal(tb.PriorityCell.X, tb.PriorityCell.Y, 3, NoDecRepeatedly)
      else
        Self.DecArrVal(tb.PriorityCell.X, tb.PriorityCell.Y, 4, NoDecRepeatedly);
    end;
  if tb.state = TBCSDangerous then
    Self.DecArrVal(tb.PriorityCell.X, tb.PriorityCell.Y, 5, NoDecRepeatedly);
end;

function  TBoard.AnalyzeSideConnectionsForPoint(Ax, Ay: shortint): TSideConnectionDirection;
var
  dirs:  TSideConnectionDirection;
  sinfo: TSideConnectionInformation;
begin
  result := CDSUnknown;
  for dirs in [CDSTop..CDSLeft] do
    begin
      sinfo := Self.ai.GetSideConnectionInfo(Ax, Ay, dirs, player);
      Self.UpdateArrBySideConn(Ax, Ay, sinfo, true);
      if (sinfo.state = SCSSafe) or (sinfo.state = SCSFree) then
        result := dirs;
    end;
end;

procedure TBoard.InitArray(ArrSize: shortint);
var
  x, y: shortint;
begin
  SetLength(arr, ArrSize, ArrSize);
  for x := 0 to ArrSize - 1 do
    for y := 0 to ArrSize - 1 do
      arr[x, y] := 50;
  minval := 50;
end;


(*
 *  TAIDefault methods
 *)
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
  result.EnemySideConnection := false;

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

      result.EnemySideConnection := PointIsSideConnection(DstCell.X, DstCell.Y, OppositePlayer);
      if not result.EnemySideConnection then
        result.EnemySideConnection := PointIsSideConnection(SrcCell.X, SrcCell.Y, OppositePlayer);
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
var
  carrier: TSideConnectionCarrier;
begin
  carrier := Template_SideConnectionsCarriers[dir];
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



function  TAIDefault.FindMove(const board: TGameBoard; player: TPlayer): TPoint;
var
  brd:       TBoard;
  move:      TMove;
  dir:       TTwoBridgeConnectionDirection;
  tbinfo:    TTwoBridgeConnectionInformation;
  x, y:      shortint;
  neighbor:  TCellNeighbor;
  PointSideConnectionDir: TSideConnectionDirection;
  ExcludeDirs: array [0..1] of TTwoBridgeConnectionDirection;
begin
  result := nil;
  if board.BoardSide > 7 then
    exit();
  if (Length(board.Moves) = 0) and (player = PlayerOne) then
    result := Self.GetFirstMove(board.BoardSide)
  else if (Length(board.Moves) = 1) and (player = PlayerTwo) then
    result := Self.FindMove(board, PlayerOne)
  else
    begin
      brd := TBoard.Create();
      brd.ai := self;
      brd.player := player;
      brd.InitArray(board.BoardSide);

      result := TPoint.Create();
      Self.Fboard := board;

      // Analyze two-bridge connections
      for move in board.Moves do
        begin
        brd.arr[move.Cell.X, move.Cell.Y] := 99;
        if move.Cell.Player = player then
          begin
            PointSideConnectionDir := brd.AnalyzeSideConnectionsForPoint(move.Cell.X, move.Cell.Y); // <<-- Analyze side connections
            for dir in [CDTopLeft..CDBottomLeft] do
              begin
                ExcludeDirs := SideConnAdjacentTwoBridgeConns[PointSideConnectionDir];
                if (dir <> ExcludeDirs[0]) and (dir <> ExcludeDirs[1]) then
                  begin
                    tbinfo := Self.GetTwoBridgeConnectionInfo(move.Cell.X, move.Cell.Y, dir, player);
                    brd.UpdateArrByTwoBridgeConn(move.Cell.X, move.Cell.Y, tbinfo, true);
                    // Analyze side connections
                    if (tbinfo.state <> TBCSUnknown) and (tbinfo.state <> TBCSInvalid) then
                      begin
                        brd.AnalyzeSideConnectionsForPoint(tbinfo.point.X, tbinfo.point.Y);
                        for neighbor in move.Cell.Neighbors do
                          if neighbor.cell.State = FreeCell then
                            brd.AnalyzeSideConnectionsForPoint(neighbor.cell.X, neighbor.cell.Y);
                      end;
                  end;
              end;
          end;
        end;

      // Find best point
      for y := 0 to board.MaxIndex do
        begin
        for x := 0 to board.MaxIndex do
          begin
          Write(brd.arr[x, y], ' ');
          if brd.arr[x, y] = brd.minval then
            result.SetXY(x, y);
          end;
        WriteLn();
        end;
    end;
end;

class constructor TAIDefault.Create();
begin
  Randomize;
end;

end.
