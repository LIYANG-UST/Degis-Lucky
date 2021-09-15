const FUJI_LINK_ADDRESS = '0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846'
const FUJI_JOBID = "1755320a535b4fcd9aa873ca616204d6"
const FUJI_CHAINLINK_ORACLE = '0x7D9398979267a6E050FbFDFff953Fc612A5aD4C9'
const URL = 'http://api.m.taobao.com/rest/api3.do?api=mtop.common.getTimestamp' 
const PATH = "data.path"


const DegisToken = artifacts.require("lib/DegisToken");
const MockUSD = artifacts.require('lib/MockUSD');
const RandomNumber = artifacts.require('lib/RandomNumber');
const DegisBar = artifacts.require('DegisBar');


module.exports = async function(deployer, network) {
    await deployer.deploy(RandomNumber, FUJI_LINK_ADDRESS, FUJI_CHAINLINK_ORACLE, URL, PATH)
    await deployer.deploy(DegisToken)
    await deployer.deploy(MockUSD)
    await deployer.deploy(DegisBar, DegisToken.address, MockUSD.address);
};