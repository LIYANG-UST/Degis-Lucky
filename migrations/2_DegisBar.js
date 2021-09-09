const DegisToken = artifacts.require("lib/DegisToken");
const MockUSD = artifacts.require('lib/MockUSD');
const DegisBar = artifacts.require('DegisBar');


module.exports = async function(deployer, network) {
    await deployer.deploy(DegisToken)
    await deployer.deploy(MockUSD)
    await deployer.deploy(DegisBar,DegisToken.address,MockUSD.address);
};