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
		console.log("----------- Start inject funds -------------") 
        const degisToken = await DegisToken.deployed()
        const mockUSD = await MockUSD.deployed()
        const user0 = (await web3.eth.getAccounts())[0]
        const lottery = await DegisLottery.deployed()

        const amount = web3.utils.toWei('100','ether')
		    const currentLotteryId = await lottery.viewCurrentLotteryId()
        await mockUSD.approve(lottery.address, amount, {from: user0})     
        await lottery.injectFunds(currentLotteryId, amount)  

        const lotteryInfo = await lottery.viewLottery(currentLotteryId)
        const contractMockUSDBalance = await mockUSD.balanceOf(lottery.address)
        const contractDegisBalance = await degisToken.balanceOf(lottery.address)
        console.log('[INFO]:', 'CONTRACT CUCCENT LOTTERY ID', currentLotteryId.toString())
        console.log('[INFO]:', 'CONTRACT CURRENT LOTTERY STATUS', lotteryInfo.status)
        console.log('[INFO]:', 'CONTRACT DEGIS BALANCE', web3.utils.fromWei(contractDegisBalance.toString()))
        console.log('[INFO]:', 'CONTRACT USD BALANCE', web3.utils.fromWei(contractMockUSDBalance.toString()))

        console.log("----------- End inject funds -------------") 
        callback(true)
    }
  	catch (err) {
    	callback(err)
  	}
}
