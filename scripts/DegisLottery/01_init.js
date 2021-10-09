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
      const degisToken = await DegisToken.deployed()
      const mockUSD = await MockUSD.deployed()
      const lottery = await DegisLottery.deployed()
      const rand = await RandomNumberGenerator.deployed()
      const address = await web3.eth.getAccounts()
      const user0 = address[0]
      const user1 = address[1]
      const user2 = address[2]

      console.log("----------- Start mint USD -------------") 
      amount = web3.utils.toWei('1000','ether')
      await mockUSD.mint(user0, amount)
      user0MockUSDBalance = await mockUSD.balanceOf(user0)
      console.log('[INFO]:','USER0 USD BALANCE', web3.utils.fromWei(user0MockUSDBalance.toString()))
      console.log("----------- End mint USD -------------") 


      console.log("----------- Start mint DEGIS -------------") 
      amount = web3.utils.toWei('1000','ether')
      await degisToken.mint(user1, amount)
      await degisToken.mint(user2, amount)
      user1DegisTokenBalance = await degisToken.balanceOf(user1)
      user2DegisTokenBalance = await degisToken.balanceOf(user2)
      console.log('[INFO]:', 'USER1 DEGIS BALANCE', web3.utils.fromWei(user1DegisTokenBalance.toString()))
      console.log('[INFO]:', 'USER2 DEGIS BALANCE', web3.utils.fromWei(user2DegisTokenBalance.toString()))
      console.log("----------- End mint DEGIS -------------") 

      console.log("----------- Start support ETH -------------") 
      amount = web3.utils.toWei('0.001','ether')
      await web3.eth.sendTransaction({"from": user0, "to": user1, "value": amount})
      await web3.eth.sendTransaction({"from": user0, "to": user2, "value": amount})
      user0ETHBalence = await web3.eth.getBalance(user0)
      user1ETHBalence = await web3.eth.getBalance(user1)
      user2ETHBalence = await web3.eth.getBalance(user2)
      console.log('[INFO]:', 'USER0 ETH BALANCE', web3.utils.fromWei(user0ETHBalence.toString()))
      console.log('[INFO]:', 'USER1 ETH BALANCE', web3.utils.fromWei(user1ETHBalence.toString()))
      console.log('[INFO]:', 'USER2 ETH BALANCE', web3.utils.fromWei(user2ETHBalence.toString()))
      console.log("----------- Start end ETH -------------") 

      console.log("----------- Start support LINK -------------") 
      const linkAddress = "0x01BE23585060835E02B77ef475b0Cc51aA1e0709"
      const linkToken = await LinkTokenInterface.at(linkAddress)
      amount = web3.utils.toWei('5','ether')
      await linkToken.transfer(rand.address, amount, {from: user0})
      contractLinkBalance = await linkToken.balanceOf(rand.address)
      console.log('[INFO]:', 'CONTRACT(RANDOM) LINK BALANCE', web3.utils.fromWei(contractLinkBalance.toString()))
      console.log("----------- Start end LINK -------------") 
      callback(true)
    }
  	catch (err) {
    	callback(err)
  	}
}
