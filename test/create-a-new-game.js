const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("RockScissorsPapers", function () {
    it("Should create a game with the correct payment", async function () {
        const [owner, playAgainst] = await hre.ethers.getSigners();

        const RockScissorsPapers = await ethers.getContractFactory("RockScissorsPapers");
        const rockScissorsPapers = await RockScissorsPapers.deploy();
        await rockScissorsPapers.deployed();

        // game succesfullyy created with the correct amount
        expect(await rockScissorsPapers.connect(owner).callStatic.enroll(playAgainst.address, {
            value: ethers.utils.parseUnits("1", 1)
        })).to.equal(0);
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
});
