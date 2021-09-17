const DegisToken = artifacts.require("./lib/DegisToken");
const MockUSD = artifacts.require('./lib/MockUSD');
const DegisBar = artifacts.require('DegisBar')
const RandomNumber = artifacts.require('./lib/RandomNumber')
const LinkTokenInterface = artifacts.require('ERC20')

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

module.exports = async callback => {
  	try {

// init
		console.log("Init -------------") 
  		const degisToken = await DegisToken.deployed()
    	const usdcToken = await MockUSD.deployed()
    	const degisBar = await DegisBar.deployed()
    	const randomNumber = await RandomNumber.deployed()

    	var address = (await web3.eth.getAccounts())[0]

    	// Set randomNumber operator
    	await randomNumber.changeOperator(degisBar.address)
    	
    	await degisBar.init()

    	console.log('owner address:', address)
    	console.log('degisBar address:', degisBar.address)


    	var degisAdress= await degisBar.getDegisTokenAddress()
    	var usdcAdress= await degisBar.getUsdcTokenAddress()
    	console.log(degisAdress)
    	console.log(degisToken.address)
    	console.log(usdcAdress)
    	console.log(usdcToken.address)

    	var degisTokenBalance;
    	var usdcTokenBalance;
    	
// Get token
    	console.log("Get token-------------") 
    	console.log("100 USDC From Mint -> Owner , 100 DEGIS From Mint -> Owner") 
    	var amount = web3.utils.toWei('100','ether')
    	
    	
    	const cmd1 = await degisToken.mint(address, amount)
    	const cmd2 = await usdcToken.mint(address, amount)

		degisTokenBalance = await degisToken.balanceOf(address)
		console.log('USER DEGIS BALANCE:', web3.utils.fromWei(degisTokenBalance.toString()))
		degisTokenBalance = await degisToken.balanceOf(degisBar.address)
		console.log('BAR  DEGIS BALANCE', web3.utils.fromWei(degisTokenBalance.toString()))
		usdcTokenBalance = await usdcToken.balanceOf(address)
		console.log('USER USDC  BALANCE', web3.utils.fromWei(usdcTokenBalance.toString()))
		usdcTokenBalance = await usdcToken.balanceOf(degisBar.address)
		console.log('BAR  USDC  BALANCE', web3.utils.fromWei(usdcTokenBalance.toString()))


//Buy code
		console.log("Buy code-------------")
		console.log("10+20+30+40=100 DEGIS From Owner -> DegisBar") 
		let approveResult = await degisToken.approve(degisBar.address, web3.utils.toWei('100','ether'), {from: address});
		await degisBar.buy([9,99,999,9999],[web3.utils.toWei('10','ether'),web3.utils.toWei('20','ether'),web3.utils.toWei('30','ether'),web3.utils.toWei('40','ether')])

		degisTokenBalance = await degisToken.balanceOf(address)
		console.log('USER DEGIS BALANCE:', web3.utils.fromWei(degisTokenBalance.toString()))
		degisTokenBalance = await degisToken.balanceOf(degisBar.address)
		console.log('BAR  DEGIS BALANCE', web3.utils.fromWei(degisTokenBalance.toString()))
		usdcTokenBalance = await usdcToken.balanceOf(address)
		console.log('USER USDC  BALANCE', web3.utils.fromWei(usdcTokenBalance.toString()))
		usdcTokenBalance = await usdcToken.balanceOf(degisBar.address)
		console.log('BAR  USDC  BALANCE', web3.utils.fromWei(usdcTokenBalance.toString()))


// Redeem code
		console.log("Redeem code-------------")
		console.log("10+20=30 DEGIS From DegisBar -> Owner") 

    	await degisBar.redeem([9,99])
    	
		degisTokenBalance = await degisToken.balanceOf(address)
		console.log('USER DEGIS BALANCE:', web3.utils.fromWei(degisTokenBalance.toString()))
		degisTokenBalance = await degisToken.balanceOf(degisBar.address)
		console.log('BAR  DEGIS BALANCE', web3.utils.fromWei(degisTokenBalance.toString()))
		usdcTokenBalance = await usdcToken.balanceOf(address)
		console.log('USER USDC  BALANCE', web3.utils.fromWei(usdcTokenBalance.toString()))
		usdcTokenBalance = await usdcToken.balanceOf(degisBar.address)
		console.log('BAR  USDC  BALANCE', web3.utils.fromWei(usdcTokenBalance.toString()))

//Prize income
		console.log("Prize income-------------")
		console.log("100 USDC From Owner -> DegisBar") 

		let approveResult2 = await usdcToken.approve(degisBar.address, web3.utils.toWei('100','ether'), {from: address});		
		var prize = web3.utils.toWei('100','ether')
		await degisBar.prizeIncome(prize)

		degisTokenBalance = await degisToken.balanceOf(address)
		console.log('USER DEGIS BALANCE:', web3.utils.fromWei(degisTokenBalance.toString()))
		degisTokenBalance = await degisToken.balanceOf(degisBar.address)
		console.log('BAR  DEGIS BALANCE', web3.utils.fromWei(degisTokenBalance.toString()))
		usdcTokenBalance = await usdcToken.balanceOf(address)
		console.log('USER USDC  BALANCE', web3.utils.fromWei(usdcTokenBalance.toString()))
		usdcTokenBalance = await usdcToken.balanceOf(degisBar.address)
		console.log('BAR  USDC  BALANCE', web3.utils.fromWei(usdcTokenBalance.toString()))


//Before draw 
		console.log("Before draw -------------")
		var usePrize = await degisBar.getUserPrize.call(address)
		console.log("USER Prize",web3.utils.fromWei(usePrize.toString()))


// Prepare
		console.log("Generate RandomNumber -------------")

	    // Send 1 link to the contract
	   	const linkAddress = await randomNumber.getChainlinkToken()
    	const linkToken = await LinkTokenInterface.at(linkAddress)
	    const payment = web3.utils.toWei('1','ether')
	    const tx1 = await linkToken.transfer(randomNumber.address, payment)
	

	    // Generate RandomNumber
		await degisBar.preSettlement()
		await sleep(60000) 


		// epochId = await degisBar.getEpochId.call()
	 // 	   console.log("epochId",epochId.toString())
		// random = await randomNumber.getRandomNumber(epochId)
		// console.log("RandomNumber",random[0].toString(),random[1].toString())


// Draw
		console.log("Draw -------------")
		await degisBar.close()
		await degisBar.settlement()
		await degisBar.open()

		epochId = await degisBar.getEpochId.call()
		info = await degisBar.getEpochInfo(epochId)
		console.log("EpochInfo",epochId.toString(),info[0].toString(),info[1].toString(),info[2].toString())

// After draw		
		console.log("After draw -------------")
		usePrize = await degisBar.getUserPrize.call(address)
		console.log("USER Prize",web3.utils.fromWei(usePrize.toString()))


// Prepare2
		console.log("Generate CertainNumber 2 -------------")

	    // Generate CertainNumber
	    await randomNumber.changeUrl("http://47.98.184.198:6689/9999")
		await degisBar.preSettlement()
		await sleep(60000)
		await randomNumber.changeUrl("http://47.98.184.198:6689/RandomNumber")
		 
		// epochId = await degisBar.getEpochId.call()
	 // 	   console.log("epochId",epochId.toString())
		// random = await randomNumber.getRandomNumber(epochId)
		// console.log("RandomNumber",random[0].toString(),random[1].toString())

// Draw2
		console.log("Draw 2 -------------")
		await degisBar.close()
		await degisBar.settlement()
		await degisBar.open()

		epochId = await degisBar.getEpochId.call()
		info = await degisBar.getEpochInfo(epochId)
		console.log("EpochInfo",epochId.toString(),info[0].toString(),info[1].toString(),info[2].toString())

// //After draw2		
		console.log("After draw 2 -------------")
		usePrize = await degisBar.getUserPrize.call(address)
		console.log("USER Prize",web3.utils.fromWei(usePrize.toString()))

//Receive prize
		console.log("Receive prize -------------")
		console.log("100 USDC From DegisBar -> Owner") 
		try{
			await degisBar.prizeWithdraw()
		}
		catch(err){
			console.log("Receive prize Error")
		}

		degisTokenBalance = await degisToken.balanceOf(address)
		console.log('USER DEGIS BALANCE:', web3.utils.fromWei(degisTokenBalance.toString()))
		degisTokenBalance = await degisToken.balanceOf(degisBar.address)
		console.log('BAR  DEGIS BALANCE', web3.utils.fromWei(degisTokenBalance.toString()))
		usdcTokenBalance = await usdcToken.balanceOf(address)
		console.log('USER USDC  BALANCE', web3.utils.fromWei(usdcTokenBalance.toString()))
		usdcTokenBalance = await usdcToken.balanceOf(degisBar.address)
		console.log('BAR  USDC  BALANCE', web3.utils.fromWei(usdcTokenBalance.toString()))

//After receive prize
		console.log("After receive prize -------------")
		usePrize = await degisBar.getUserPrize.call(address)
		console.log("USER Prize",web3.utils.fromWei(usePrize.toString()))


 //Redeem all code
 		console.log("Redeem all code-------------")
 		console.log("30+40=70 DEGIS From DegisBar -> Owner") 

 		await degisBar.redeem([999,9999])
 		degisTokenBalance = await degisToken.balanceOf(address)
		console.log('USER DEGIS BALANCE:', web3.utils.fromWei(degisTokenBalance.toString()))
		degisTokenBalance = await degisToken.balanceOf(degisBar.address)
		console.log('BAR  DEGIS BALANCE', web3.utils.fromWei(degisTokenBalance.toString()))
		usdcTokenBalance = await usdcToken.balanceOf(address)
		console.log('USER USDC  BALANCE', web3.utils.fromWei(usdcTokenBalance.toString()))
		usdcTokenBalance = await usdcToken.balanceOf(degisBar.address)
		console.log('BAR  USDC  BALANCE', web3.utils.fromWei(usdcTokenBalance.toString()))

		callback(true)
  	}
  	catch (err) {
    	callback(err)
  	}
}