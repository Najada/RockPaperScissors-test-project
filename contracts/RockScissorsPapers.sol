//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "hardhat/console.sol";

error CanNotPerformThisAction(string _reason);


contract RockScissorsPapers is Ownable {
    // constants to represent the moves
    uint8 public constant ROCK = 1;
    uint8 public constant SCISSORS = 2;
    uint8 public constant PAPER = 3;

    // constants to represent game status
    uint8 public constant PENDING = 0;
    uint8 public constant ACTIVE = 1;
    uint8 public constant DROPPED = 2;
    uint8 public constant PLAYER_ONE_WON = 3;
    uint8 public constant PLAYER_TWO_WON = 4;
    uint8 public constant TIE = 5;

    // counter to return the game id
    using Counters for Counters.Counter;
    Counters.Counter private _gameIds;

    // game fee
    uint256 private _gameFee = 1e1;
    uint256 private _timeout = 120 seconds;

    event PlayerJoinedGame(uint256 _gameId, address player);
    event GameIsFinished(uint256 _gameId, address winner, address loser);

    struct Game {
        uint256 id;
        address player1;
        address player2;
        uint32 timeStamp;
        uint8 gameState;
        uint8 player1Move;
        uint8 player2Move;
    }

    Game[] internal games;
    mapping(address => uint256) private _usersGames;

    // setter to update the game fee if needed
    function setGameFee(uint256 _newGameFee) external onlyOwner {
        _gameFee = _newGameFee;
    }

    function setTimeout(uint256 _newTimeout) external onlyOwner {
        _timeout = _newTimeout;
    }

    modifier hasDepositedCorrectAmount() {
        if (msg.value != _gameFee) {
            revert CanNotPerformThisAction(
                "Please deposit the right fee to be able to start a game"
            );
        }
        _;
    }

    // player one creates the game and decides the player he will play against
    function enroll(address payable playerTwo)
        external
        payable
        hasDepositedCorrectAmount
        returns (uint256)
    {
        if (msg.sender == playerTwo) {
            revert CanNotPerformThisAction("You can not play against yourself");
        }

        uint256 currentIndex = _gameIds.current();
        games.push(
            Game(
                currentIndex,
                msg.sender,
                playerTwo,
                uint32(block.timestamp),
                uint8(PENDING),
                uint8(0),
                uint8(0)
            )
        );
        _gameIds.increment();

        _usersGames[msg.sender]++;
        _usersGames[playerTwo]++;
        return currentIndex;
    }

    modifier joinOnlyIfYouAreTheSecondPlayer(uint256 _gameId) {
        if (
            _gameId > _gameIds.current() || games[_gameId].player2 != msg.sender
        ) {
            revert CanNotPerformThisAction("You can not join this game");
        }
        _;
    }

    modifier canSetMove(uint256 _gameId) {
        address _currentPlayer = msg.sender;
        if (
            games[_gameId].player1 == msg.sender &&
            games[_gameId].player1Move != 0
        ) {
            revert CanNotPerformThisAction("You have already set your move");
        }
        if (
            games[_gameId].player2 == msg.sender &&
            games[_gameId].player2Move != 0
        ) {
            revert CanNotPerformThisAction("You have already set your move");
        }
        _;
    }

    modifier setOnlyValidMove(uint256 _move) {
        if (_move < 1 && _move > 3) {
            revert CanNotPerformThisAction("Please set a valid move");
        }
        _;
    }

    // to join a game the user should have the right id from the person inviting him
    function joinGame(uint256 _gameId)
        external
        payable
        joinOnlyIfYouAreTheSecondPlayer(_gameId)
        hasDepositedCorrectAmount
    {
        Game storage myGame = games[_gameId];
        myGame.gameState = ACTIVE;
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
        uint8 whoOne;
        if (myGame.player1Move == ROCK && myGame.player2Move == PAPER) {
            whoOne = PLAYER_ONE_WON;
        } else if (myGame.player1Move == PAPER && myGame.player2Move == ROCK) {
            whoOne = PLAYER_TWO_WON;
        } else if (
            myGame.player1Move == PAPER && myGame.player2Move == SCISSORS
        ) {
            whoOne = PLAYER_TWO_WON;
        } else if (
            myGame.player1Move == SCISSORS && myGame.player2Move == PAPER
        ) {
            whoOne = PLAYER_ONE_WON;
        } else if (
            myGame.player1Move == ROCK && myGame.player2Move == SCISSORS
        ) {
            whoOne = PLAYER_ONE_WON;
        } else if (
            myGame.player1Move == SCISSORS && myGame.player2Move == ROCK
        ) {
            whoOne = PLAYER_TWO_WON;
        } else if (myGame.player1Move == myGame.player2Move) {
            whoOne = TIE;
        }

        myGame.gameState = whoOne;

        if (whoOne == PLAYER_ONE_WON) {
            payable(myGame.player1).transfer(_gameFee * 2);
        } else if (whoOne == PLAYER_TWO_WON) {
            payable(myGame.player2).transfer(_gameFee * 2);
        } else if (whoOne == TIE) {
            payable(myGame.player1).transfer(_gameFee);
            payable(myGame.player2).transfer(_gameFee);
        }
    }

    function myGames() external view returns (Game[] memory) {
        Game[] memory allGames = new Game[](_usersGames[msg.sender]);
        uint256 _index = 0;
        for (uint256 i = 0; i < games.length; i++) {
            if (
                games[i].player1 == msg.sender || games[i].player2 == msg.sender
            ) {
                allGames[_index] = games[i];
                _index++;
            }
        }
        return allGames;
    }

    modifier canClaimRefund(uint256 _gameId) {
        if (games[_gameId].player1 == msg.sender) {
            if (block.timestamp - games[_gameId].timeStamp >= _timeout) {
                revert CanNotPerformThisAction(
                    "Cannot claim reward before 2 minutes of inacticity"
                );
            }
            if (ACTIVE == games[_gameId].gameState) {
                revert CanNotPerformThisAction(
                    "Player 2 has joined. Please make your move"
                );
            }
        } else {
            revert CanNotPerformThisAction("This is not your game");
        }
        _;
    }

    // function to retireve funds in case the game didint go forward for whatever reason
    function claimRefund(uint256 _gameId) external canClaimRefund(_gameId) {
        payable(msg.sender).transfer(_gameFee);
        games[_gameId].gameState = DROPPED;
    }
}
