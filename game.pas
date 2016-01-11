{$INCLUDE game.inc}
unit Game;

interface

type
  TPoint = class
    public
      X, Y: shortint;
  end;

  TCellState = (FreeCell, Player1, Player2);
  TCellNeighborType = (CNTNone, CNTTop, CNTTopRight, CNTBottomRight, CNTBottom, CNTBottomLeft, CNTTopLeft);
  TCellNeighborTypeArray = array of TCellNeighborType;
  TCellPosition = (CPNone, CPTopLeft, CPTop, CPTopRight, CPRight, CPBottomRight, CPBottom, CPBottomLeft, CPLeft, CPCenter);

  TCell = class;
  TCellNeighbor = class
    public
      cell:  TCell;
      _type: TCellNeighborType;
  end;
  TCellNeighborsArray = array of TCellNeighbor;

  TCell = class
    strict private
      Fpoint: TPoint;
      Fstate: TCellState;
    private
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

  TGameField = class
    strict private
      Fside:  shortint;
      Fcells: array of array of TCell;
    private
      function  CalculateCellPosition(X, Y: shortint): TCellPosition;
      function  CalculateCellNeighborsCount(CellPos: TCellPosition; out Neighbors: TCellNeighborTypeArray): shortint;
      function  GetCell(X, Y: shortint): TCell;
      function  GetCellNeighbor(CellX, CellY: shortint; NeighborType: TCellNeighborType): TCell;
    public
      function  Initialize(SideLength: shortint): boolean;
  end;

{uses
  Classes, SysUtils;}

implementation

var
  CellNeighborsCount: packed array[CPTopLeft..CPCenter] of shortint = (
                            2,  // CPTopLeft
                            4,  // CPTop
                            3,  // CPTopRight
                            4,  // CPRight
                            2,  // CPBottomRight
                            4,  // CPBottom
                            3,  // CPBottomLeft
                            4,  // CPLeft
                            6); // CPCenter
  CellNeighborsPositions: packed array[CPTopLeft..CPCenter, CNTTop..CNTTopLeft] of TCellNeighborType = (
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


function  TGameField.CalculateCellPosition(X, Y: shortint): TCellPosition;
var
  MaxIndex: shortint;
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

function  TGameField.CalculateCellNeighborsCount(CellPos: TCellPosition; out Neighbors: TCellNeighborTypeArray): shortint;
var
  i: TCellNeighborType;
begin
  result := CellNeighborsCount[CellPos];
  if result > 0 then
    SetLength(Neighbors, result);
    for i := CNTTop to TCellNeighborType(result) do
      Neighbors[shortint(i) - 1] := CellNeighborsPositions[CellPos, i];
end;

function  TGameField.GetCell(X, Y: shortint): TCell;
begin
  result := Self.Fcells[X, Y];
end;

function  TGameField.GetCellNeighbor(CellX, CellY: shortint; NeighborType: TCellNeighborType): TCell;
var
  x, y: shortint;
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
    result := Self.GetCell(x, y)
  else
    result := nil;
end;

function  TGameField.Initialize(SideLength: shortint): boolean;
var
  CellColumn: array of TCell;
  cell: TCell;
  x, y, i: shortint;
  MaxIndex: shortint;
  CellPos: TCellPosition;
  Neighbors: TCellNeighborTypeArray;
  NeighborsCount: shortint;
  neigbor: TCellNeighbor;
begin
  if not SideLength in [4..11] then
    exit(false);
  SetLength(Self.Fcells, SideLength, SideLength);
  Self.Fside := SideLength;
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
        NeighborsCount := Self.CalculateCellNeighborsCount(CellPos, Neighbors);
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

end.

