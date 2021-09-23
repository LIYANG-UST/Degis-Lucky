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
		console.log("----------- Init -------------") 
  		const degis = await DegisToken.deployed()
    	const usdc = await MockUSD.deployed()
    	const lottery = await DegisLottery.deployed()
    	const rand = await RandomNumberGenerator.deployed()

    	let address = (await web3.eth.getAccounts())[0]
		console.log('my address:%s \n degis address:%s \n usdc address:%s \n lottery address: %s \n rand address:%s', 
						address, degis.address, usdc.address, lottery.address, rand.address)


		const linkAddress = "0x01BE23585060835E02B77ef475b0Cc51aA1e0709"
        const linkToken = await LinkTokenInterface.at(linkAddress)

		let linkBalance = await linkToken.balanceOf(address)
        console.log('\n my own Link Balance:', web3.utils.fromWei(linkBalance.toString()))

		
		const pre_tx = await lottery.setOperatorAndTreasuryAndInjectorAddresses(address, address, address, {from:address})
		console.log(pre_tx.tx)
		// start lottery

		let timestamp = new Date().getTime();
        timestamp = parseInt(timestamp / 1000 + 600); // 10 minutes
		console.log("end time stamp:", timestamp)

		const tx1 = await lottery.startLottery(
			timestamp,
			web3.utils.toBN(10e18),
			[500, 1500, 2000, 6000],
			0,
			{ from: address }
		  );
		console.log(tx1.tx)

		const currentLotteryId = await lottery.viewCurrentLotteryId()
		console.log("current lottery id:", currentLotteryId)

		callback(true)
  	}
  	catch (err) {
    	callback(err)
  	}
}