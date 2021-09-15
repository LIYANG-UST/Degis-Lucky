const DegisToken = artifacts.require("./lib/DegisToken");
const MockUSD = artifacts.require('./lib/MockUSD');
const DegisBar = artifacts.require('DegisBar')


module.exports = async callback => {
  	try {

  		const degisToken = await DegisToken.deployed()
    	const usdcToken = await MockUSD.deployed()
    	const degisBar = await DegisBar.deployed()
    	degisBar.init()

    	var address = (await web3.eth.getAccounts())[0]
    	console.log(address)

    	var degisAdress= await degisBar.getDegisTokenAddress()
    	var usdcAdress= await degisBar.getUsdcTokenAddress()

    	console.log('degisBar contract:', degisBar.address)
    	console.log(degisAdress)
    	console.log(degisToken.address)
    	console.log(usdcAdress)
    	console.log(usdcToken.address)
    	

    	console.log("Get token-------------") 
    	console.log("100 USDC From Mint -> Owner , 100 DEGIS From Mint -> Owner") 
    	var amount = web3.utils.toWei('100','ether')
    	
    	const cmd1 = await degisToken.mint(address, amount)
    	const cmd2 = await usdcToken.mint(address, amount)

    	var degisTokenBalance;
    	var usdcTokenBalance;
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


//Redeem code
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

		degisBar.setOperator(address)

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

//Prepare
		degis.preSettlement()
		await sleep(10000)

//Draw
		console.log("Draw -------------")
		degisBar.close()
		await degisBar.settlement()
		degisBar.open()

//After draw		
		console.log("After draw -------------")
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