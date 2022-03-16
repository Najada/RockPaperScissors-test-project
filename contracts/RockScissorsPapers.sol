//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "hardhat/console.sol";

error PleaseDepositTheGameFee();
error CanNotPlayAgainstYourself();

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

    struct Game {
        address player1;
        address player2;
        uint32 timeStamp;
        uint8 playerState;
        uint8 gameState;
        uint8 player1Move;
        uint8 player2Move;
    }

    Game[] public games;

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
}
