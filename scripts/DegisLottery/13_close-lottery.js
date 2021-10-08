const DegisToken = artifacts.require("./lib/DegisToken");
const MockUSD = artifacts.require('./lib/MockUSD');
const DegisLottery = artifacts.require('DegisLottery')
const RandomNumberGenerator = artifacts.require('RandomNumberGenerator')
const LinkTokenInterface = artifacts.require('LinkTokenInterface')

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
  
module.exports = async callback => {
    try {
      console.log("----------- Start close lottery -------------") 
      const degisToken = await DegisToken.deployed()
      const mockUSD = await MockUSD.deployed()
      const lottery = await DegisLottery.deployed()
      const rand = await RandomNumberGenerator.deployed()      
      rand.setLotteryAddress(lottery.address)
      let address = (await web3.eth.getAccounts())[0]
      const currentLotteryId = await lottery.viewCurrentLotteryId()      
      const tx1 = await lottery.closeLottery(currentLotteryId, {from:address})
      console.log(tx1.tx)

      const lotteryInfo = await lottery.viewLottery(currentLotteryId)
      const contractMockUSDBalance = await mockUSD.balanceOf(lottery.address)
      const contractDegisBalance = await degisToken.balanceOf(lottery.address)
      console.log('[INFO]:', 'CONTRACT CURRENT LOTTERY ID', currentLotteryId.toString())
      console.log('[INFO]:', 'CONTRACT CURRENT LOTTERY STATUS', lotteryInfo.status)
      console.log('[INFO]:', 'CONTRACT DEGIS BALANCE', web3.utils.fromWei(contractDegisBalance.toString()))
      console.log('[INFO]:', 'CONTRACT USD BALANCE', web3.utils.fromWei(contractMockUSDBalance.toString()))

      console.log("----------- End close lottery -------------") 
  
      callback(true)
    }
    catch (err) {
      callback(err)
    }
  }