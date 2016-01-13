{$INCLUDE game.inc}
unit testing;

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  game, ai_random;

type

  TTestHexGame= class(TTestCase)
  published
    procedure SearchForWinner1();
    procedure SearchForWinner2();
    procedure SearchForWinner3();
    procedure RandomVsRandom();
  end;

implementation

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

initialization
  RegisterTest(TTestHexGame);
end.

