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
		console.log("----------- Start buy ticktes -------------") 
  		const degisToken = await DegisToken.deployed()
  		const lottery = await DegisLottery.deployed()
		const address = await web3.eth.getAccounts()
        const user0 = address[0]
		const user1 = address[1]
		const user2 = address[2]
		const tickets = [10000, 11111, 12222, 13333, 14444, 15555, 16666, 17777, 18888, 19999]

        const cost = tickets.length * 10

        await degisToken.approve(lottery.address, web3.utils.toWei(cost.toString(), 'ether'), {from: user2})
		tx2 = await lottery.buyTickets(tickets, { from: user2 });
		console.log(tx2.tx)

        await degisToken.approve(lottery.address, web3.utils.toWei(cost.toString(), 'ether'), {from: user2})
        tx2 = await lottery.buyTickets(tickets, { from: user2 });
        console.log(tx2.tx)

        const currentLotteryId = await lottery.viewCurrentLotteryId()
        const user1TicketsResponse = await lottery.viewUserInfoForLotteryId(user1, currentLotteryId, 0, 40, {from: user1});
        const user2TicketsResponse = await lottery.viewUserInfoForLotteryId(user2, currentLotteryId, 0, 40, {from: user2});

        console.log("[INFO]","USER1 Tickets:")
        console.log(user1TicketsResponse[0].toString())
        console.log(user1TicketsResponse[1].toString())
        console.log(user1TicketsResponse[2].toString())       
       
        console.log("[INFO]","USER2 Tickets:")
        console.log(user2TicketsResponse[0].toString())
        console.log(user2TicketsResponse[1].toString())
        console.log(user2TicketsResponse[2].toString()) 

        contractDegisBalance = await degisToken.balanceOf(lottery.address)
        user1DegisTokenBalance = await degisToken.balanceOf(user1)
        user2DegisTokenBalance = await degisToken.balanceOf(user2)
        console.log('[INFO]:', 'CONTRACT DEGIS BALANCE', web3.utils.fromWei(contractDegisBalance.toString()))
        console.log('[INFO]:', 'USER1 DEGIS BALANCE', web3.utils.fromWei(user1DegisTokenBalance.toString()))
        console.log('[INFO]:', 'USER2 DEGIS BALANCE', web3.utils.fromWei(user2DegisTokenBalance.toString()))

        console.log("----------- End buy ticktes -------------")
		callback(true)
  	}
  	catch (err) {
    	callback(err)
  	}
}