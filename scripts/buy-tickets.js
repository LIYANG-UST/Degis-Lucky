const DegisToken = artifacts.require("./lib/DegisToken");
const MockUSD = artifacts.require('./lib/MockUSD');
const DegisLottery = artifacts.require('DegisLottery')
const RandomNumberGenerator = artifacts.require('RandomNumberGenerator')
const LinkTokenInterface = artifacts.require('LinkTokenInterface')

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function showticket(ticketsResponse) {
    const [ticketIds, ticketNumbers, ticketStatuses] = ticketsResponse
    if (ticketIds.length > 0) {
        return {
       
            id: ticketId.toString(),
            number: ticketNumbers[index].toString(),
            status: ticketStatuses[index],
        
        }
    }
    
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

		
        // await degis.mint(address, web3.utils.toWei('1000', 'ether'))


		
		const currentLotteryId = await lottery.viewCurrentLotteryId()
		console.log("current lottery id:", parseInt(currentLotteryId))

        const tickets = [11234, 13654, 16597]

        const cost = tickets.length * 10
        console.log("cost:", cost)

        await degis.approve(lottery.address, web3.utils.toWei(cost.toString(), 'ether'), {from: address})

		const tx1 = await lottery.buyTickets(
			currentLotteryId,
			tickets,
			{ from: address }
		  );
		console.log(tx1.tx)

        const ticketsResponse = await lottery.viewUserInfoForLotteryId(address, currentLotteryId, 0, 10, {from: address});

        console.log("ticketinfo:", ticketsResponse[2])
       
       

		callback(true)
  	}
  	catch (err) {
    	callback(err)
  	}
}