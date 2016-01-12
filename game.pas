{$INCLUDE game.inc}
unit game;

interface

type
  TPoint = class
    public
      X, Y: shortint;
      function  Clone(): TPoint;
      function  IsEqual(pt: TPoint): boolean;
      procedure Assign(pt: TPoint);
      procedure SetXY(Px, Py: shortint);
  end;

  TCellState = (FreeCell, Player1, Player2);
  TPlayer = (PlayerNone, PlayerOne, PlayerTwo);
  TCellNeighborType = (CNTNone, CNTTop, CNTTopRight, CNTBottomRight, CNTBottom, CNTBottomLeft, CNTTopLeft);
  TCellNeighborTypeArray = packed array of TCellNeighborType;
  TCellPosition = (CPNone, CPTopLeft, CPTop, CPTopRight, CPRight, CPBottomRight, CPBottom, CPBottomLeft, CPLeft, CPCenter);

  TCell = class;
  TCellNeighbor = class
    public
      cell:  TCell;
      _type: TCellNeighborType;
  end;
  TCellNeighborsArray = packed array of TCellNeighbor;

  TCell = class
    strict private
      Fpoint: TPoint;
      Fstate: TCellState;
    private
      Fpos:   TCellPosition;
      Fneighbors: TCellNeighborsArray;
      function  GetX(): shortint;
      function  GetY(): shortint;
      function  SetCoordinates(X, Y: shortint): boolean;
    public
      function  Initialize(X, Y: shortint; state: TCellState): boolean;
      property  X: shortint read GetX;
      property  Y: shortint read GetY;
      property  State: TCellState read Fstate write Fstate;
  end;

  TMove = class
    private
      Fcell:  TCell;
      Forder: shortint;
  end;
  TInputMove  = packed array[0..2] of shortint;
  TInputMoves = packed array of TInputMove;

  TGameBoard = class
    strict private
      Fside:   shortint;
      Farea:   shortint;
      Fcells:  packed array of array of TCell;
      Fmoves:  packed array of TMove;
      Finit,
      Fp1Top,
      Fp1Btm,
      Fp2Lft,
      Fp2Rgt:  boolean;
      Fwinner: TPlayer;
    private
      function  CalculateCellPosition(X, Y: shortint): TCellPosition;
      function  CalculateCellNeighborsCount(CellPos: TCellPosition; out Neighbors: TCellNeighborTypeArray): shortint;
      function  GetCellNeighbor(CellX, CellY: shortint; NeighborType: TCellNeighborType): TCell;
      function  CheckBounds(X, Y: shortint): boolean; inline;
    public
      {$IFDEF _DBG}
      procedure PrintMoves();
      {$ENDIF}
      function  Initialize(SideLength: shortint): boolean;
      function  GetCell(X, Y: shortint): TCell;
      function  MakeMove(X, Y: shortint; player: TPlayer): boolean;
      function  FillBoard(const moves: TInputMoves): boolean;
      function  GetWinner(): TPlayer;
      procedure ClearBoard();
      property  BoardSide: shortint read Fside;
      property  BoardArea: shortint read Farea;
      property  Initialized: boolean read Finit;
  end;

  IArtificialIntelligence = interface
    function FindMove(const board: TGameBoard; player: TPlayer): TPoint;
  end;

{uses
  Classes, SysUtils;}

implementation

var
  CellNeighborsCount: packed array [CPTopLeft..CPCenter] of shortint = (
                            2,  // CPTopLeft
                            4,  // CPTop
                            3,  // CPTopRight
                            4,  // CPRight
                            2,  // CPBottomRight
                            4,  // CPBottom
                            3,  // CPBottomLeft
                            4,  // CPLeft
                            6); // CPCenter
  CellNeighborsPositions: packed array [CPTopLeft..CPCenter, CNTTop..CNTTopLeft] of TCellNeighborType = (
                            // CPTopLeft
                            (CNTBottomRight, CNTBottom, CNTNone, CNTNone, CNTNone, CNTNone),
                            // CPTop
                            (CNTBottomRight, CNTBottom, CNTBottomLeft, CNTTopLeft, CNTNone, CNTNone),
                            // CPTopRight
                            (CNTBottom, CNTBottomLeft, CNTTopLeft, CNTNone, CNTNone, CNTNone),
                            // CPRight
                            (CNTBottom, CNTBottomLeft, CNTTopLeft, CNTTop, CNTNone, CNTNone),
                            // CPBottomRight
                            (CNTTopLeft, CNTTop, CNTNone, CNTNone, CNTNone, CNTNone),
                            // CPBottom
                            (CNTTop, CNTTopRight, CNTBottomRight, CNTTopLeft, CNTNone, CNTNone),
                            // CPBottomLeft
                            (CNTTop, CNTTopRight, CNTBottomRight, CNTNone, CNTNone, CNTNone),
                            // CPLeft
                            (CNTTop, CNTTopRight, CNTBottomRight, CNTBottom, CNTNone, CNTNone),
                            // CPCenter
                            (CNTTop, CNTTopRight, CNTBottomRight, CNTBottom, CNTBottomLeft, CNTTopLeft));


(*
 *  TGameBoard methods
 *)
function  TGameBoard.GetWinner(): TPlayer;
begin
  result := PlayerNone;
  if Self.Finit then
    begin
      if Self.Fwinner = PlayerNone then
        if (Self.Fp1Top and Self.Fp1Btm) then
          // Check for PlayerOne
          //begin end;
          Self.Fwinner := PlayerOne;
        if (Self.Fp2Lft and Self.Fp2Rgt) then
          // Check for PlayerTwo
          //begin end;
          Self.Fwinner := PlayerTwo;
      result := Self.Fwinner;
    end;
end;

function  TGameBoard.FillBoard(const moves: TInputMoves): boolean;
var
  move:   TInputMove;
  player: TPlayer;
begin
  result := false;
  if Self.Finit then
    begin
      Self.ClearBoard();
      for move in moves do
        begin
          result := false;
          player := TPlayer(move[0]);
          if (Length(move) = 3) and (player in [PlayerOne, PlayerTwo]) then
            result := Self.MakeMove(move[1], move[2], player);
          if not result then
            break;
        end;
      if not result then
        Self.ClearBoard();
    end;
end;

procedure TGameBoard.ClearBoard();
var
  move: TMove;
begin
  if Self.Finit then
    begin
      for move in Self.Fmoves do
        begin
          move.Fcell.State := FreeCell;
          move.Free;
        end;
      move := nil;
      SetLength(Self.Fmoves, 0);
      Self.Fp1Top := false;
      Self.Fp1Btm := false;
      Self.Fp2Lft := false;
      Self.Fp2Rgt := false;
    end;
end;

function  TGameBoard.CheckBounds(X, Y: shortint): boolean; inline;
begin
  result := (X >= 0) and (Y >= 0) and (X <= Self.Fside) and (Y <= Self.Fside);
end;

function  TGameBoard.MakeMove(X, Y: shortint; player: TPlayer): boolean;
var
  cell:          TCell;
  move,
  PreviousMove:  TMove;
  MovesCount,
  NewMovesCount: shortint;
  AllowMove:     boolean;
begin
  result := false;
  if Self.Finit and (Self.GetWinner() = PlayerNone) and Self.CheckBounds(X, Y) and (player <> PlayerNone) then
    begin
      cell := Self.GetCell(X, Y);
      if cell.State = FreeCell then
        begin
          MovesCount := Length(Self.Fmoves);

          AllowMove := true;
          if MovesCount > 0 then
            begin
              PreviousMove := Self.Fmoves[MovesCount - 1];
              if PreviousMove.Fcell.State = TCellState(player) then
                AllowMove := false;
            end;

          if AllowMove then
            begin
              NewMovesCount := MovesCount + 1;
              move := TMove.Create();
              move.Forder := NewMovesCount;
              move.Fcell := cell;
              move.Fcell.State := TCellState(player);

              if player = PlayerOne then
                begin
                  if cell.Fpos in [CPTopLeft, CPTop, CPTopRight] then
                    Self.Fp1Top := true
                  else if cell.Fpos in [CPBottomLeft, CPBottom, CPBottomRight] then
                    Self.Fp1Btm := true;
                end
              else if player = PlayerTwo then
                begin
                  if cell.Fpos in [CPTopLeft, CPLeft, CPBottomLeft] then
                    Self.Fp2Lft := true
                  else if cell.Fpos in [CPTopRight, CPRight, CPBottomRight] then
                    Self.Fp2Rgt := true;
                end;

              SetLength(Self.Fmoves, NewMovesCount);
              Self.Fmoves[MovesCount] := move;
              Self.GetWinner();
              result := true;
            end;
        end;
    end;
end;

function  TGameBoard.CalculateCellPosition(X, Y: shortint): TCellPosition;
var
  MaxIndex: shortint;
begin
  result := CPNone;
  if Self.CheckBounds(X, Y) then
    begin
      MaxIndex := Self.Fside - 1;
      if X = 0 then
        if Y = 0 then
          result := CPTopLeft
        else if Y = MaxIndex then
          result := CPBottomLeft
        else
          result := CPLeft
      else if X = MaxIndex then
        if Y = 0 then
          result := CPTopRight
        else if Y = MaxIndex then
          result := CPBottomRight
        else
          result := CPRight
      else
        if Y = 0 then
          result := CPTop
        else if Y = MaxIndex then
          result := CPBottom
        else
          result := CPCenter;
    end;
end;

function  TGameBoard.CalculateCellNeighborsCount(CellPos: TCellPosition; out Neighbors: TCellNeighborTypeArray): shortint;
var
  i: TCellNeighborType;
begin
  result := CellNeighborsCount[CellPos];
  if result > 0 then
    begin
      SetLength(Neighbors, result);
      for i := CNTTop to TCellNeighborType(result) do
        Neighbors[shortint(i) - 1] := CellNeighborsPositions[CellPos, i];
    end;
end;

function  TGameBoard.GetCell(X, Y: shortint): TCell;
begin
  if Self.Finit and Self.CheckBounds(X, Y) then
    result := Self.Fcells[X, Y]
  else
    result := nil;
end;

function  TGameBoard.GetCellNeighbor(CellX, CellY: shortint; NeighborType: TCellNeighborType): TCell;
var
  x, y: shortint;
begin
  result := nil;
  if Self.CheckBounds(CellX, CellY) then
    begin
      x := CellX;
      y := CellY;

      if NeighborType in [CNTBottomLeft, CNTTopLeft] then
        x -= 1
      else if NeighborType in [CNTBottomRight, CNTTopRight] then
        x += 1;
      if NeighborType in [CNTTop, CNTTopRight] then
        y -= 1
      else if NeighborType in [CNTBottom, CNTBottomLeft] then
        y += 1;

      if (x <> CellX) or (y <> CellY) then
        result := Self.GetCell(x, y);
    end;
end;

function  TGameBoard.Initialize(SideLength: shortint): boolean;
var
  CellColumn:     packed array of TCell;
  cell:           TCell;
  x, y, i:        shortint;
  MaxIndex:       shortint;
  CellPos:        TCellPosition;
  Neighbors:      TCellNeighborTypeArray;
  NeighborsCount: shortint;
  neigbor:        TCellNeighbor;
begin
  result := false;
  if SideLength in [4..11] then
    begin
      SetLength(Self.Fcells, SideLength, SideLength);
      Self.Fside := SideLength;
      Self.Farea := SideLength * SideLength;
      MaxIndex := SideLength - 1;

      for x := 0 to MaxIndex do
        for y := 0 to MaxIndex do
          begin
            cell := TCell.Create();
            cell.Initialize(x, y, FreeCell);
            Self.Fcells[x, y] := cell;
          end;

      for CellColumn in Self.Fcells do
        for cell in CellColumn do
          begin
            CellPos := Self.CalculateCellPosition(cell.X, cell.Y);
            cell.Fpos := CellPos;
            NeighborsCount := Self.CalculateCellNeighborsCount(CellPos, Neighbors);
            if NeighborsCount > 0 then
              begin
                SetLength(cell.Fneighbors, NeighborsCount);
                for i := 0 to NeighborsCount - 1 do
                  begin
                    neigbor := TCellNeighbor.Create();
                    neigbor._type := Neighbors[i];
                    neigbor.cell := Self.GetCellNeighbor(cell.X, cell.Y, neigbor._type);
                    cell.Fneighbors[i] := neigbor;
                  end;
              end;
          end;

      Self.Finit := true;
      result := true;
    end;
end;

{$IFDEF _DBG}
procedure TGameBoard.PrintMoves();
var
  move: TMove;
begin
  if Self.Finit then
    begin
      WriteLn('------------------------------');
      for move in Self.Fmoves do
        WriteLn(move.Forder, ') pos: (', move.Fcell.X, ', ', move.Fcell.Y, '); player: ', TPlayer(move.Fcell.State));
    end;
end;
{$ENDIF}


(*
 *  TCell methods
 *)
function  TCell.SetCoordinates(X, Y: shortint): boolean;
begin
  if not assigned(Self.Fpoint) then
    begin
      Self.Fpoint := TPoint.Create;
      Self.Fpoint.X := X;
      Self.Fpoint.Y := Y;
      exit(true);
    end
  else
    exit(false);
end;

function  TCell.GetX(): shortint;
begin
  if not assigned(Self.Fpoint) then
    exit(-1)
  else
    exit(Self.Fpoint.X);
end;

function  TCell.GetY(): shortint;
begin
  if not assigned(Self.Fpoint) then
    exit(-1)
  else
    exit(Self.Fpoint.Y);
end;

function  TCell.Initialize(X, Y: shortint; state: TCellState): boolean;
begin
  Self.State := state;
  exit(Self.SetCoordinates(X, Y));
end;


(*
 *  TPoint methods
 *)
function TPoint.Clone(): TPoint;
begin
  result := TPoint.Create;
  result.Assign(Self);
end;

function TPoint.IsEqual(pt: TPoint): boolean;
begin
  result := (pt.X = Self.X) and (pt.Y = Self.Y);
end;

procedure TPoint.SetXY(Px, Py: shortint);
begin
  Self.X := Px;
  Self.Y := Py;
end;

procedure TPoint.Assign(pt: TPoint);
begin
  Self.SetXY(pt.X, pt.Y);
end;

end.

