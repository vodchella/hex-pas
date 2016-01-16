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
  TPoints = array of TPoint;

  TCellState = (FreeCell, Player1, Player2);
  TPlayer = (PlayerNone, PlayerOne, PlayerTwo);
  TCellNeighborType = (CNTNone, CNTTop, CNTTopRight, CNTBottomRight, CNTBottom, CNTBottomLeft, CNTTopLeft);
  TCellNeighborTypeArray = packed array of TCellNeighborType;
  TCellPosition = (CPNone, CPTopLeft, CPTop, CPTopRight, CPRight, CPBottomRight, CPBottom, CPBottomLeft, CPLeft, CPCenter);

  TPlayerHelper = type helper for TPlayer
    function AsString(player: TPlayer): string;
  end;

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
      function  PlayerFromState(): TPlayer; inline;
    private
      Fstate: TCellState;
      Fpos:   TCellPosition;
      Fneighbors: TCellNeighborsArray;
      FAllyNeighborsCount: shortint;
      function  GetX(): shortint;
      function  GetY(): shortint;
      function  SetCoordinates(X, Y: shortint): boolean;
    public
      function  Initialize(X, Y: shortint; state: TCellState): boolean;
      function  IsEqual(cell: TCell): boolean;
      property  X: shortint read GetX;
      property  Y: shortint read GetY;
      property  State: TCellState read Fstate;
      property  Player: TPlayer read PlayerFromState;
      property  AllyNeighborsCount: shortint read FAllyNeighborsCount;
      property  Neighbors: TCellNeighborsArray read Fneighbors;
  end;
  TCellArray = packed array of TCell;

  TMove = class
    private
      Fcell:  TCell;
      Forder: shortint;
    public
      property Cell: TCell read Fcell;
  end;
  TMoves = packed array of TMove;
  TInputMove  = packed array[0..2] of shortint;
  TInputMoves = packed array of TInputMove;

  TGameBoard = class
    strict private
      Fside:   shortint;
      Fmaxind: shortint;
      Farea:   shortint;
      Fcells:  packed array of array of TCell;
      Fmoves:  TMoves;
      Finit:   boolean;
      FpCnt:   array [PlayerOne..PlayerTwo] of shortint;
      Fp1Top,
      Fp1Btm,
      Fp2Lft,
      Fp2Rgt:  shortint;
      Fwinner: TPlayer;
    private
      function  RecursiveAnalyze(CurrentCell: TCell; var VisitedCells: TCellArray): boolean;
      function  CalculateCellPosition(X, Y: shortint): TCellPosition;
      function  CalculateCellNeighborsCount(CellPos: TCellPosition; out Neighbors: TCellNeighborTypeArray): shortint;
      function  GetCellNeighbor(CellX, CellY: shortint; NeighborType: TCellNeighborType): TCell;
      function  UpdateWinner(): TPlayer;
      procedure UpdateCellAllyNeighborsCount(cell: TCell);
    public
      {$IFDEF _DBG}
      procedure PrintMoves();
      {$ENDIF}
      function  Initialize(SideLength: shortint): boolean;
      function  GetCell(X, Y: shortint): TCell;
      function  MakeMove(X, Y: shortint; player: TPlayer): boolean;
      function  FillBoard(const moves: TInputMoves): boolean;
      function  CheckBounds(X, Y: shortint): boolean;
      procedure ClearBoard();
      property  BoardSide: shortint read Fside;
      property  BoardArea: shortint read Farea;
      property  Initialized: boolean read Finit;
      property  Winner: TPlayer read Fwinner;
      property  Moves: TMoves read Fmoves;
      property  MaxIndex: shortint read Fmaxind;
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
function  TGameBoard.RecursiveAnalyze(CurrentCell: TCell; var VisitedCells: TCellArray): boolean;
var
  neighbor: TCellNeighbor;
  cell: TCell;
  l, newl, CheckLine: shortint;

  function CellInArray(): boolean; inline;
  var
    c: TCell;
  begin
    result := false;
    for c in VisitedCells do
      if c = cell then
        exit(true);
  end;

  procedure PreExit(); inline;
  begin
    VisitedCells[l] := nil;
    SetLength(VisitedCells, l);
  end;

begin
  {$IFDEF _DBG_RECURSIVE_SEARCH} WriteLn('  cell: (', CurrentCell.X, ', ', CurrentCell.Y, ')'); {$ENDIF}
  result := false;
  if CurrentCell.AllyNeighborsCount <> 0 then
    begin
      l := Length(VisitedCells);
      newl := l + 1;
      SetLength(VisitedCells, newl);
      VisitedCells[l] := CurrentCell;

      for neighbor in CurrentCell.Fneighbors do
        begin
          cell := neighbor.cell;
          if cell.Fstate = CurrentCell.Fstate then
            if not CellInArray() then
              begin
                if cell.Fstate = Player1 then
                  CheckLine := cell.Y
                else if cell.Fstate = Player2 then
                  CheckLine := cell.X;
                if CheckLine = Self.Fmaxind then
                  begin
                    {$IFDEF _DBG_RECURSIVE_SEARCH} WriteLn('  fin:  (', cell.X, ', ', cell.Y, ')'); {$ENDIF}
                    PreExit();
                    exit(true);
                  end
                else
                  begin
                    result := Self.RecursiveAnalyze(cell, VisitedCells);
                    if result then
                      break;
                  end;
              end;
        end;

      PreExit();
    end;
end;

function  TGameBoard.UpdateWinner(): TPlayer;
var
  SearchResult, DoAnalyze: boolean;
  i: shortint;
  pl: TPlayer;
  cell: TCell;
  VisitedCells: TCellArray;
begin
  result := PlayerNone;
  if Self.Finit then
    begin
      SetLength(VisitedCells, 0);
      if Self.Fwinner = PlayerNone then
        for pl := PlayerOne to PlayerTwo do
          begin
            DoAnalyze := false;
            if Self.FpCnt[pl] >= Self.Fside then
              if pl = PlayerOne then
                begin
                  if (Self.Fp1Top > 0) and (Self.Fp1Btm > 0) then
                    DoAnalyze := true;
                end
              else if pl = PlayerTwo then
                if (Self.Fp2Lft > 0) and (Self.Fp2Rgt > 0) then
                  DoAnalyze := true;
            if DoAnalyze then
              begin
                for i := 0 to Self.Fmaxind do
                  begin
                    if pl = PlayerOne then
                      cell := Self.Fcells[i, 0]
                    else if pl = PlayerTwo then
                      cell := Self.Fcells[0, i];
                    if cell.Fstate = TCellState(pl) then
                      begin
                        {$IFDEF _DBG_RECURSIVE_SEARCH} WriteLn('--->> Start recursive search for ', pl); {$ENDIF}
                        SearchResult := Self.RecursiveAnalyze(cell, VisitedCells);
                        {$IFDEF _DBG_RECURSIVE_SEARCH} WriteLn('---<< Stop  recursive search for ', pl); {$ENDIF}
                        if SearchResult then
                          begin
                            Self.Fwinner := pl;
                            exit(pl);
                          end;
                      end;
                  end;
              end;
          end;
      result := Self.Fwinner;
    end;
end;

procedure TGameBoard.UpdateCellAllyNeighborsCount(cell: TCell);
var
  neighbor: TCellNeighbor;
begin
  if (cell.Fstate <> FreeCell) and (cell.FAllyNeighborsCount = 0) then
    for neighbor in cell.Fneighbors do
      if neighbor.cell.Fstate = cell.Fstate then
        begin
          inc(cell.FAllyNeighborsCount);
          inc(neighbor.cell.FAllyNeighborsCount);
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
          move.Fcell.Fstate := FreeCell;
          move.Fcell.FAllyNeighborsCount := 0;
          move.Free;
        end;
      move := nil;
      SetLength(Self.Fmoves, 0);
      Self.Fp1Top := 0;
      Self.Fp1Btm := 0;
      Self.Fp2Lft := 0;
      Self.Fp2Rgt := 0;
      Self.FpCnt[PlayerOne] := 0;
      Self.FpCnt[PlayerTwo] := 0;
      Self.Fwinner := PlayerNone;
    end;
end;

function  TGameBoard.CheckBounds(X, Y: shortint): boolean;
begin
  result := (X >= 0) and (Y >= 0) and (X <= Self.Fmaxind) and (Y <= Self.Fmaxind);
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
  if Self.Finit and (Self.Fwinner = PlayerNone) and Self.CheckBounds(X, Y) and (player <> PlayerNone) then
    begin
      cell := Self.GetCell(X, Y);
      if cell.Fstate = FreeCell then
        begin
          MovesCount := Length(Self.Fmoves);

          AllowMove := true;
          if MovesCount > 0 then
            begin
              PreviousMove := Self.Fmoves[MovesCount - 1];
              if PreviousMove.Fcell.Fstate = TCellState(player) then
                AllowMove := false;
            end
          else if player <> PlayerOne then
            AllowMove := false;

          if AllowMove then
            begin
              NewMovesCount := MovesCount + 1;
              move := TMove.Create();
              move.Forder := NewMovesCount;
              move.Fcell := cell;
              move.Fcell.Fstate := TCellState(player);
              Self.UpdateCellAllyNeighborsCount(move.Fcell);

              if player = PlayerOne then
                begin
                  if cell.Fpos in [CPTopLeft, CPTop, CPTopRight] then
                    inc(Self.Fp1Top)
                  else if cell.Fpos in [CPBottomLeft, CPBottom, CPBottomRight] then
                    inc(Self.Fp1Btm);
                end
              else if player = PlayerTwo then
                begin
                  if cell.Fpos in [CPTopLeft, CPLeft, CPBottomLeft] then
                    inc(Self.Fp2Lft)
                  else if cell.Fpos in [CPTopRight, CPRight, CPBottomRight] then
                    inc(Self.Fp2Rgt);
                end;

              SetLength(Self.Fmoves, NewMovesCount);
              Self.Fmoves[MovesCount] := move;
              inc(Self.FpCnt[player]);
              Self.UpdateWinner();
              result := true;
            end;
        end;
    end;
end;

function  TGameBoard.CalculateCellPosition(X, Y: shortint): TCellPosition;
var
  MaxInd: shortint;
begin
  result := CPNone;
  if Self.CheckBounds(X, Y) then
    begin
      MaxInd := Self.Fside - 1;
      if X = 0 then
        if Y = 0 then
          result := CPTopLeft
        else if Y = MaxInd then
          result := CPBottomLeft
        else
          result := CPLeft
      else if X = MaxInd then
        if Y = 0 then
          result := CPTopRight
        else if Y = MaxInd then
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
        // Self.GetCell() can't be used at this moment,
        // because of Self.Finit doesn't set yet
        result := Self.Fcells[X, Y];
    end;
end;

function  TGameBoard.Initialize(SideLength: shortint): boolean;
var
  CellColumn:     packed array of TCell;
  cell:           TCell;
  x, y, i:        shortint;
  CellPos:        TCellPosition;
  Neighbors:      TCellNeighborTypeArray;
  NeighborsCount: shortint;
  neigbor:        TCellNeighbor;
begin
  result := false;
  if (not Self.Finit) and (SideLength in [4..11]) then
    begin
      SetLength(Self.Fcells, SideLength, SideLength);
      Self.Fside := SideLength;
      Self.Farea := SideLength * SideLength;
      Self.Fmaxind := SideLength - 1;

      for x := 0 to Self.Fmaxind do
        for y := 0 to Self.Fmaxind do
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
        WriteLn(move.Forder, ') pos: (', move.Fcell.X, ', ', move.Fcell.Y, '); allycnt: ', move.Fcell.AllyNeighborsCount, '; player: ', TPlayer(move.Fcell.Fstate));
    end;
end;
{$ENDIF}


(*
 *  TCell methods
 *)
function  TCell.PlayerFromState(): TPlayer;
begin
  result := TPlayer(Self.State);
end;

function  TCell.SetCoordinates(X, Y: shortint): boolean;
begin
  result := false;
  if not assigned(Self.Fpoint) then
    begin
      Self.Fpoint := TPoint.Create;
      Self.Fpoint.X := X;
      Self.Fpoint.Y := Y;
      result := true;
    end;
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
  result := false;
  if Self.Fstate = FreeCell then
    if Self.SetCoordinates(X, Y) then
      begin
        Self.Fstate := state;
        result := true;
      end;
end;

function  TCell.IsEqual(cell: TCell): boolean;
begin
  result := Self.Fpoint.IsEqual(cell.Fpoint);
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


(*
 *  TPlayerHelper methods
 *)
function TPlayerHelper.AsString(player: TPlayer): string;
begin
  case player of
    PlayerNone: result := 'PlayerNone';
    PlayerOne:  result := 'PlayerOne';
    PlayerTwo:  result := 'PlayerTwo';
  end;
end;

end.
