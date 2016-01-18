{$INCLUDE game.inc}
unit testing;

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  game, ai_random, ai_default;

type

  TTestHexGame= class(TTestCase)
  published
    procedure SearchForWinner1();
    procedure SearchForWinner2();
    procedure SearchForWinner3();
    procedure RandomVsRandom();
    procedure AnalyzeCellChains1();
    procedure AnalyzeCellChains2();
    procedure AnalyzeCellChains3();
  end;

implementation

var
  ArrForAnalyzeCellChains1: array [0..17] of array [0..1] of shortint = (
                               (* PlayerOne *)
                               (1, 4), (1, 3), (1, 2),
                               (1, 4), (2, 3), (3, 2), (3, 1),
                               (1, 4), (2, 3), (3, 3), (4, 3),
                               (* PlayerTwo *)
                               (2, 2), (2, 1), (1, 1),
                               (2, 4), (3, 4),
                               (0, 4), (0, 3)
                             );
  ArrForAnalyzeCellChains2: array [0..19] of array [0..1] of shortint = (
                               (* PlayerOne *)
                               (1, 5), (1, 4), (1, 3), (1, 2), (2, 1), (3, 1), (3, 2),
                               (1, 5), (1, 4), (2, 3),
                               (* PlayerTwo *)
                               (0, 5), (0, 4), (0, 3),
                               (2, 5), (2, 4), (3, 3),
                               (2, 5), (3, 4),
                               (2, 5), (3, 5)
                             );
  ArrForAnalyzeCellChains3: array [0..15] of array [0..1] of shortint = (
                               (* PlayerOne *)
                               (1, 5), (1, 4), (1, 3), (1, 2), (2, 1), (3, 1), (3, 2), (2, 3),
                               (* PlayerTwo *)
                               (0, 5), (0, 4), (0, 3),
                               (2, 5), (2, 4), (3, 3), (3, 4), (3, 5)
                             );

procedure TTestHexGame.SearchForWinner1();
var
  board:  TGameBoard;
begin
  board := TGameBoard.Create();
  board.Initialize(4);

  board.MakeMove(0, 0, PlayerOne);
  board.MakeMove(0, 1, PlayerTwo);
  board.MakeMove(1, 0, PlayerOne);
  board.MakeMove(2, 0, PlayerTwo);
  board.MakeMove(1, 1, PlayerOne);
  board.MakeMove(1, 2, PlayerTwo);
  board.MakeMove(0, 2, PlayerOne);
  board.MakeMove(3, 0, PlayerTwo);
  board.MakeMove(2, 1, PlayerOne);
  board.MakeMove(3, 1, PlayerTwo);
  board.MakeMove(2, 2, PlayerOne);
  board.MakeMove(1, 3, PlayerTwo);
  board.MakeMove(3, 2, PlayerOne);
  board.MakeMove(2, 3, PlayerTwo);
  board.MakeMove(3, 3, PlayerOne);

  AssertEquals('Winner on board 1', TPlayer.AsString(PlayerOne), TPlayer.AsString(board.Winner));
end;

procedure TTestHexGame.SearchForWinner2();
var
  board:  TGameBoard;
begin
  board := TGameBoard.Create();
  board.Initialize(5);

  board.MakeMove(0, 0, PlayerOne);
  board.MakeMove(0, 1, PlayerTwo);
  board.MakeMove(1, 0, PlayerOne);
  board.MakeMove(0, 2, PlayerTwo);
  board.MakeMove(4, 4, PlayerOne);
  board.MakeMove(4, 3, PlayerTwo);
  board.MakeMove(3, 4, PlayerOne);
  board.MakeMove(2, 4, PlayerTwo);
  board.MakeMove(0, 4, PlayerOne);
  board.MakeMove(0, 3, PlayerTwo);
  board.MakeMove(1, 1, PlayerOne);
  board.MakeMove(2, 0, PlayerTwo);
  board.MakeMove(1, 2, PlayerOne);
  board.MakeMove(3, 0, PlayerTwo);
  board.MakeMove(2, 1, PlayerOne);
  board.MakeMove(4, 0, PlayerTwo);
  board.MakeMove(3, 1, PlayerOne);
  board.MakeMove(2, 2, PlayerTwo);
  board.MakeMove(3, 2, PlayerOne);
  board.MakeMove(1, 3, PlayerTwo);
  board.MakeMove(2, 3, PlayerOne);
  board.MakeMove(4, 1, PlayerTwo);
  board.MakeMove(3, 3, PlayerOne);

  AssertEquals('Winner on board 2', TPlayer.AsString(PlayerOne), TPlayer.AsString(board.Winner));
end;

procedure TTestHexGame.SearchForWinner3();
var
  board:  TGameBoard;
begin
  board := TGameBoard.Create();
  board.Initialize(4);

  board.MakeMove(0, 0, PlayerOne);
  board.MakeMove(1, 2, PlayerTwo);
  board.MakeMove(0, 1, PlayerOne);
  board.MakeMove(3, 1, PlayerTwo);
  board.MakeMove(0, 2, PlayerOne);
  board.MakeMove(0, 3, PlayerTwo);
  board.MakeMove(2, 1, PlayerOne);
  board.MakeMove(2, 2, PlayerTwo);

  AssertEquals('Winner on board 3', TPlayer.AsString(PlayerTwo), TPlayer.AsString(board.Winner));
end;

procedure TTestHexGame.RandomVsRandom();
var
  board:  TGameBoard;
  ai:     TAIRandom;
  player: TPlayer;
  pt:     TPoint;
  mres:   boolean;
  i:      shortint;
begin
  board := TGameBoard.Create();
  board.Initialize(4);
  ai := TAIRandom.Create();
  player := PlayerOne;
  i := 0;

  repeat
    inc(i);
    if i > 16 then
      break;
    pt := ai.FindMove(board, player);
    if pt <> nil then
      begin
        mres := board.MakeMove(pt.X, pt.Y, player);
        if mres then
          begin
            if player = PlayerOne then
              player := PlayerTwo
            else
              player := PlayerOne;
          end
        else
          Fail('Move failed');
      end
    else
      Fail('Point not found');
  until board.Winner <> PlayerNone;

  if board.Winner = PlayerNone then
    Fail('Game failed');
end;

procedure TTestHexGame.AnalyzeCellChains1();
var
  board:   TGameBoard;
  ai:      TAIDefault;
  pl:      TPlayer;
  pchains: TPlayerChains;
  chain:   TCellChain;
  cell:    TCell;
  i:       shortint;
begin
  board := TGameBoard.Create();
  if board.Initialize(5) then
    begin
      ai := TAIDefault.Create();

      board.MakeMove(1, 4, PlayerOne);
      board.MakeMove(2, 2, PlayerTwo);
      board.MakeMove(1, 3, PlayerOne);
      board.MakeMove(2, 1, PlayerTwo);
      board.MakeMove(1, 2, PlayerOne);
      board.MakeMove(1, 1, PlayerTwo);
      board.MakeMove(2, 3, PlayerOne);
      board.MakeMove(2, 4, PlayerTwo);
      board.MakeMove(3, 3, PlayerOne);
      board.MakeMove(3, 4, PlayerTwo);
      board.MakeMove(3, 2, PlayerOne);
      board.MakeMove(0, 4, PlayerTwo);
      board.MakeMove(3, 3, PlayerOne);
      board.MakeMove(3, 4, PlayerTwo);
      board.MakeMove(3, 1, PlayerOne);
      board.MakeMove(0, 3, PlayerTwo);
      board.MakeMove(4, 3, PlayerOne);

      ai.GameBoard := board;
      ai.FindAllChains(false);

      {$IFDEF _DBG_CELL_CHAINS_SEARCH}
      WriteLn('----- Chains1:');
      for pl in [PlayerOne..PlayerTwo] do
        begin
          pchains := ai.AllCellChains[pl];
          WriteLn('      ', pl, ': ', Length(pchains));
          for chain in pchains do
            begin
              Write('      > ');
              for cell in chain.cells do
                Write('(', cell.X,', ', cell.Y,') ');
              WriteLn();
            end;
          WriteLn('-------------');
        end;
      {$ENDIF}

      i := 0;
      for pl in [PlayerOne..PlayerTwo] do
        begin
          pchains := ai.AllCellChains[pl];
          for chain in pchains do
            for cell in chain.cells do
              begin
                if (cell.X <> ArrForAnalyzeCellChains1[i][0]) or (cell.Y <> ArrForAnalyzeCellChains1[i][1]) then
                  Fail('Something wrong with cell chains building');
                inc(i);
              end;
        end;
      if i <> 18 then
        Fail('Wrong number of cells in chain ');
    end
  else
    Fail('Can''t create board');
end;

procedure TTestHexGame.AnalyzeCellChains2();
var
  board:   TGameBoard;
  ai:      TAIDefault;
  pl:      TPlayer;
  pchains: TPlayerChains;
  chain:   TCellChain;
  cell:    TCell;
  i:       shortint;
begin
  board := TGameBoard.Create();
  if board.Initialize(6) then
    begin
      ai := TAIDefault.Create();

      board.MakeMove(1, 5, PlayerOne);
      board.MakeMove(0, 5, PlayerTwo);
      board.MakeMove(1, 4, PlayerOne);
      board.MakeMove(0, 4, PlayerTwo);
      board.MakeMove(2, 3, PlayerOne);
      board.MakeMove(0, 3, PlayerTwo);
      board.MakeMove(3, 2, PlayerOne);
      board.MakeMove(2, 5, PlayerTwo);
      board.MakeMove(3, 1, PlayerOne);
      board.MakeMove(2, 4, PlayerTwo);
      board.MakeMove(2, 1, PlayerOne);
      board.MakeMove(3, 3, PlayerTwo);
      board.MakeMove(1, 2, PlayerOne);
      board.MakeMove(3, 5, PlayerTwo);
      board.MakeMove(1, 3, PlayerOne);
      board.MakeMove(3, 4, PlayerTwo);

      ai.GameBoard := board;
      ai.FindAllChains(false);

      {$IFDEF _DBG_CELL_CHAINS_SEARCH}
      WriteLn('----- Chains2:');
      for pl in [PlayerOne..PlayerTwo] do
        begin
          pchains := ai.AllCellChains[pl];
          WriteLn('      ', pl, ': ', Length(pchains));
          for chain in pchains do
            begin
              Write('      > ');
              for cell in chain.cells do
                Write('(', cell.X,', ', cell.Y,') ');
              WriteLn();
            end;
          WriteLn('-------------');
        end;
      {$ENDIF}

      i := 0;
      for pl in [PlayerOne..PlayerTwo] do
        begin
          pchains := ai.AllCellChains[pl];
          for chain in pchains do
            for cell in chain.cells do
              begin
                if (cell.X <> ArrForAnalyzeCellChains2[i][0]) or (cell.Y <> ArrForAnalyzeCellChains2[i][1]) then
                  Fail('Something wrong with cell chains building');
                inc(i);
              end;
        end;
      if i <> 20 then
        Fail('Wrong number of cells in chain ');
    end
  else
    Fail('Can''t create board');
end;

procedure TTestHexGame.AnalyzeCellChains3();
var
  board:   TGameBoard;
  ai:      TAIDefault;
  pl:      TPlayer;
  pchains: TPlayerChains;
  chain:   TCellChain;
  cell:    TCell;
  i:       shortint;
begin
  board := TGameBoard.Create();
  if board.Initialize(6) then
    begin
      ai := TAIDefault.Create();

      board.MakeMove(1, 5, PlayerOne);
      board.MakeMove(0, 5, PlayerTwo);
      board.MakeMove(1, 4, PlayerOne);
      board.MakeMove(0, 4, PlayerTwo);
      board.MakeMove(2, 3, PlayerOne);
      board.MakeMove(0, 3, PlayerTwo);
      board.MakeMove(3, 2, PlayerOne);
      board.MakeMove(2, 5, PlayerTwo);
      board.MakeMove(3, 1, PlayerOne);
      board.MakeMove(2, 4, PlayerTwo);
      board.MakeMove(2, 1, PlayerOne);
      board.MakeMove(3, 3, PlayerTwo);
      board.MakeMove(1, 2, PlayerOne);
      board.MakeMove(3, 5, PlayerTwo);
      board.MakeMove(1, 3, PlayerOne);
      board.MakeMove(3, 4, PlayerTwo);

      ai.GameBoard := board;
      ai.FindAllChains(true);

      {$IFDEF _DBG_CELL_CHAINS_SEARCH}
      WriteLn('----- Chains3:');
      for pl in [PlayerOne..PlayerTwo] do
        begin
          pchains := ai.AllCellChains[pl];
          WriteLn('      ', pl, ': ', Length(pchains));
          for chain in pchains do
            begin
              Write('      > ');
              for cell in chain.cells do
                Write('(', cell.X,', ', cell.Y,') ');
              WriteLn();
            end;
          WriteLn('-------------');
        end;
      {$ENDIF}

      i := 0;
      for pl in [PlayerOne..PlayerTwo] do
        begin
          pchains := ai.AllCellChains[pl];
          for chain in pchains do
            for cell in chain.cells do
              begin
                if (cell.X <> ArrForAnalyzeCellChains3[i][0]) or (cell.Y <> ArrForAnalyzeCellChains3[i][1]) then
                  Fail('Something wrong with cell chains building');
                inc(i);
              end;
        end;
      if i <> 16 then
        Fail('Wrong number of cells in chain ');
    end
  else
    Fail('Can''t create board');
end;

initialization
  RegisterTest(TTestHexGame);
end.

