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
      console.log("----------- Start draw -------------") 
      const degisToken = await DegisToken.deployed()
      const mockUSD = await MockUSD.deployed()
      const lottery = await DegisLottery.deployed()
      const rand = await RandomNumberGenerator.deployed()

      const address = await web3.eth.getAccounts()
      const user0 = address[0]
      const user1 = address[1]
      const user2 = address[2]
      
      const currentLotteryId = await lottery.viewCurrentLotteryId()
      const tx2 = await lottery.drawFinalNumberAndMakeLotteryClaimable(currentLotteryId, 1, {from:user0})
      console.log(tx2.tx)

      // console.log("----------- sleep 10s -------------") 
      // await sleep(10000)
      // console.log("----------- end sleep -------------") 

      const lotteryInfo = await lottery.viewLottery(currentLotteryId)

      const contractMockUSDBalance = await mockUSD.balanceOf(lottery.address)
      const contractDegisBalance = await degisToken.balanceOf(lottery.address)
      console.log('[INFO]:', 'CONTRACT CURRENT LOTTERY ID', currentLotteryId.toString())
      console.log('[INFO]:', 'CONTRACT CURRENT LOTTERY STATUS', lotteryInfo.status)
      console.log('[INFO]:', 'CONTRACT CURRENT LOTTERY FINAL NUMBER', lotteryInfo.finalNumber)
      console.log('[INFO]:', 'CONTRACT DEGIS BALANCE', web3.utils.fromWei(contractDegisBalance.toString()))
      console.log('[INFO]:', 'CONTRACT USD BALANCE', web3.utils.fromWei(contractMockUSDBalance.toString()))
      console.log('[INFO]:', 'CONTRACT PENDING AWARDS', currentLotteryId.toString(), web3.utils.fromWei(lotteryInfo.pendingAwards.toString()))
      const pendingInjectionNextLottery = await lottery.pendingInjectionNextLottery.call()
      console.log('[INFO]:', 'CONTRACT NEXT ROUND OF MONEY', web3.utils.fromWei(pendingInjectionNextLottery.toString()))
      const user1Awadrs = await lottery.viewClaimAllTickets(currentLotteryId,{from:user1})
      const user2Awadrs = await lottery.viewClaimAllTickets(currentLotteryId,{from:user2})

      console.log('[INFO]:', 'USER1 AWADRS', currentLotteryId.toString(), web3.utils.fromWei(user1Awadrs.toString()))
      console.log('[INFO]:', 'USER2 AWADRS', currentLotteryId.toString(), web3.utils.fromWei(user2Awadrs.toString()))

      console.log("----------- End draw -------------") 
      callback(true)
    }
    catch (err) {
      callback(err)
    }
  }