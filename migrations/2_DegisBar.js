const FUJI_LINK_ADDRESS = '0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846'
const FUJI_JOBID = "1755320a535b4fcd9aa873ca616204d6"
const FUJI_CHAINLINK_ORACLE = '0x7D9398979267a6E050FbFDFff953Fc612A5aD4C9'
const URL = "http://47.98.184.198:6689/RandomNumber"
const PATH = "RandomNumber"
//const URL = 'http://api.m.taobao.com/rest/api3.do?api=mtop.common.getTimestamp' 
//const PATH = "data.t"

const RINKEBY_VRF_COORDINATOR = '0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B'
const RINKEBY_LINKTOKEN = '0x01be23585060835e02b77ef475b0cc51aa1e0709'
const RINKEBY_KEYHASH = '0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311'

const DegisToken = artifacts.require("lib/DegisToken");
const MockUSD = artifacts.require('lib/MockUSD');

const RandomNumberGenerator = artifacts.require('RandomNumberGenerator');
const DegisLottery = artifacts.require('DegisLottery');

module.exports = async function(deployer, network) {
    await deployer.deploy(RandomNumberGenerator, RINKEBY_VRF_COORDINATOR, RINKEBY_LINKTOKEN, RINKEBY_KEYHASH);
    await deployer.deploy(DegisToken);
    await deployer.deploy(MockUSD);
    await deployer.deploy(DegisLottery, DegisToken.address, MockUSD.address, RandomNumberGenerator.address);
};