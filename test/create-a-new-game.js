const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("RockScissorsPapers", function () {
    it("Should create a game with the correct payment", async function () {
        const [owner, playAgainst] = await hre.ethers.getSigners();

        const RockScissorsPapers = await ethers.getContractFactory("RockScissorsPapers");
        const rockScissorsPapers = await RockScissorsPapers.deploy();
        await rockScissorsPapers.deployed();
        var txn = await rockScissorsPapers.connect(owner).enroll(playAgainst.address, {
            value: ethers.utils.parseUnits("1", 1)
        });
        await txn.wait();

        const games = await rockScissorsPapers.connect(owner).callStatic.myGames();

        expect(games.length).to.equal(1);
        expect(games[0].player1).to.equal(owner.address);
        expect(games[0].gameState).to.equal(0);
    });

    it("Should revert because of wrong payment", async function () {
        const [owner, playAgainst] = await hre.ethers.getSigners();

        const RockScissorsPapers = await ethers.getContractFactory("RockScissorsPapers");
        const rockScissorsPapers = await RockScissorsPapers.deploy();
        await rockScissorsPapers.deployed();

        // transaction reverts because its not the correct amount
        await expect(rockScissorsPapers.connect(owner).callStatic.enroll(playAgainst.address, {
            value: ethers.utils.parseEther("0.000000001")
        })).to.be.reverted;
    });

    it("Should create a game, another player joins a game", async function () {
        const [owner, playAgainst] = await hre.ethers.getSigners();

        const RockScissorsPapers = await ethers.getContractFactory("RockScissorsPapers");
        const rockScissorsPapers = await RockScissorsPapers.deploy();
        await rockScissorsPapers.deployed();
        var txn = await rockScissorsPapers.connect(owner).enroll(playAgainst.address, {
            value: ethers.utils.parseUnits("1", 1)
        });
        await txn.wait();

        var games = await rockScissorsPapers.connect(owner).callStatic.myGames();

        // Try to join an existing game but reverts because of lack of funds
        await expect(rockScissorsPapers.connect(playAgainst).joinGame(games[0].id, {
            value: ethers.utils.parseUnits("0.1", 1)
        })).to.be.reverted;

        // Join an existing game
        await expect(rockScissorsPapers.connect(playAgainst).joinGame(games[0].id, {
            value: ethers.utils.parseUnits("1", 1)
        })).to.emit(rockScissorsPapers, 'PlayerJoinedGame')
            .withArgs(games[0].id, games[0].player2);

        games = await rockScissorsPapers.connect(owner).callStatic.myGames();
        expect(games[0].gameState).to.equal(1);
    });

    it("Set move and calculate winnder", async function () {
        const [owner, playAgainst] = await hre.ethers.getSigners();
        console.log(ethers.utils.formatUnits(await owner.getBalance()));
        console.log(ethers.utils.formatUnits(await playAgainst.getBalance()));

        const RockScissorsPapers = await ethers.getContractFactory("RockScissorsPapers");
        const rockScissorsPapers = await RockScissorsPapers.deploy();
        await rockScissorsPapers.deployed();
        var txn = await rockScissorsPapers.connect(owner).enroll(playAgainst.address, {
            value: ethers.utils.parseUnits("1", 1)
        });
        await txn.wait();

        var games = await rockScissorsPapers.connect(owner).callStatic.myGames();

        // Join an existing game
        await expect(rockScissorsPapers.connect(playAgainst).joinGame(games[0].id, {
            value: ethers.utils.parseUnits("1", 1)
        })).to.emit(rockScissorsPapers, 'PlayerJoinedGame')
            .withArgs(games[0].id, games[0].player2);

        await rockScissorsPapers.connect(owner).setMove(games[0].id, 1);
        await rockScissorsPapers.connect(playAgainst).setMove(games[0].id, 2);

        games = await rockScissorsPapers.connect(owner).callStatic.myGames();
        // Player 1 win's
        expect(games[0].gameState, 3);
    });
});
