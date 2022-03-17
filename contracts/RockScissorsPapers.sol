//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "hardhat/console.sol";

error PleaseDepositTheGameFee();
error CanNotPlayAgainstYourself();
error YouCanNotJoinThisGame();
error ThisGameHasAlreadyStarted();
error YouHaveAlreadySetYourMove();
error InvalidMove();

contract RockScissorsPapers is Ownable {
    // constants to represent the moves
    uint8 public constant ROCK = 1;
    uint8 public constant SCISSORS = 2;
    uint8 public constant PAPER = 3;

    // constants to represent player status
    uint8 public constant WAITING_PLAYER_2 = 0;
    uint8 public constant PLAYER_2_JOINED = 1;

    // constants to represent game status
    uint8 public constant PENDING = 0;
    uint8 public constant PLAYER_ONE_WON = 1;
    uint8 public constant PLAYER_TWO_WON = 2;
    uint8 public constant DRAW = 3;

    // counter to return the game id
    using Counters for Counters.Counter;
    Counters.Counter private _gameIds;

    // game fee
    uint256 private _gameFee = 1e1;

    event PlayerJoinedGame(uint256 _gameId, address player);
    event GameIsFinished(uint256 _gameId, address winner, address loser);

    struct Game {
        address player1;
        address player2;
        uint32 timeStamp;
        uint8 playerState;
        uint8 gameState;
        uint8 player1Move;
        uint8 player2Move;
    }

    Game[] private games;

    // setter to update the game fee if needed
    function setGameFee(uint256 _newGameFee) external onlyOwner {
        _gameFee = _newGameFee;
    }

    modifier hasDepositedCorrectAmount() {
        if (msg.value != _gameFee) {
            revert PleaseDepositTheGameFee();
        }
        _;
    }

    // player one creates the game and decides the player he will play against
    function enroll(address playerTwo)
        external
        payable
        hasDepositedCorrectAmount
        returns (uint256)
    {
        if (msg.sender == playerTwo) {
            revert CanNotPlayAgainstYourself();
        }

        uint256 currentIndex = _gameIds.current();
        games.push(
            Game(
                msg.sender,
                playerTwo,
                uint32(block.timestamp),
                uint8(WAITING_PLAYER_2),
                uint8(PENDING),
                uint8(0),
                uint8(0)
            )
        );
        _gameIds.increment();

        return currentIndex;
    }

    modifier joinOnlyIfYouAreTheSecondPlayer(uint256 _gameId) {
        if (
            _gameId > _gameIds.current() || games[_gameId].player2 != msg.sender
        ) {
            revert YouCanNotJoinThisGame();
        }
        _;
    }

    modifier gameHasNotStarted(uint256 _gameId) {
        if (
            games[_gameId].playerState == PLAYER_2_JOINED ||
            games[_gameId].gameState == DRAW ||
            games[_gameId].gameState == PLAYER_ONE_WON ||
            games[_gameId].gameState == PLAYER_TWO_WON
        ) {
            revert YouCanNotJoinThisGame();
        }
        _;
    }

    modifier canSetMove(uint256 _gameId) {
        address _currentPlayer = msg.sender;
        if (
            games[_gameId].player1 == msg.sender &&
            games[_gameId].player1Move != 0
        ) {
            revert YouHaveAlreadySetYourMove();
        }
        if (
            games[_gameId].player2 == msg.sender &&
            games[_gameId].player2Move != 0
        ) {
            revert YouHaveAlreadySetYourMove();
        }
        _;
    }

    modifier setOnlyValidMove(uint256 _move) {
        if (_move < 1 && _move > 3) {
            revert InvalidMove();
        }
        _;
    }

    // to join a game the user should have the right id from the person inviting him
    function joinGame(uint256 _gameId)
        external
        payable
        joinOnlyIfYouAreTheSecondPlayer(_gameId)
        gameHasNotStarted(_gameId)
        hasDepositedCorrectAmount
    {
        Game storage myGame = games[_gameId];
        myGame.playerState = PLAYER_2_JOINED;
        emit PlayerJoinedGame(_gameId, myGame.player2);
    }

    function setMove(uint256 _gameId, uint256 _move)
        external
        setOnlyValidMove(_move)
        canSetMove(_gameId)
    {
        Game storage myGame = games[_gameId];

        if (myGame.player1 == msg.sender) {
            myGame.player1Move = uint8(_move);
        } else if (myGame.player2 == msg.sender) {
            myGame.player2Move = uint8(_move);
        }

        if (myGame.player1Move != 0 && myGame.player2Move != 0) {
            _calculateWinner(_gameId);
        }
    }

    function _calculateWinner(uint256 _gameId) internal {
        Game storage myGame = games[_gameId];
        if (myGame.player1Move == ROCK && myGame.player2Move == PAPER) {
            myGame.gameState = PLAYER_ONE_WON;
        } else if (myGame.player1Move == PAPER && myGame.player2Move == ROCK) {
            myGame.gameState = PLAYER_TWO_WON;
        } else if (
            myGame.player1Move == PAPER && myGame.player2Move == SCISSORS
        ) {
            myGame.gameState = PLAYER_TWO_WON;
        } else if (
            myGame.player1Move == SCISSORS && myGame.player2Move == PAPER
        ) {
            myGame.gameState = PLAYER_ONE_WON;
        } else if (
            myGame.player1Move == ROCK && myGame.player2Move == SCISSORS
        ) {
            myGame.gameState = PLAYER_ONE_WON;
        } else if (
            myGame.player1Move == SCISSORS && myGame.player2Move == ROCK
        ) {
            myGame.gameState = PLAYER_TWO_WON;
        } else if (myGame.player1Move == myGame.player2Move) {
            myGame.gameState = DRAW;
        }
    }
}
