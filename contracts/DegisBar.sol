// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IDegisTicket.sol";
import "./lib/LibOwnable.sol";
import "./lib/Types.sol";
import "./lib/SafeMath.sol";
import "./interfaces/IRandomNumber.sol";
import "./DegisStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract DegisBar is LibOwnable, DegisStorage {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    IERC20 DEGIS_TOKEN;
    IERC20 USDC_TOKEN;

    // ERC721 Degis Ticket: 10 Degis = 1 Degis Ticket
    IDegisTicket degisTicket;
    IRandomNumber randomGenerator;

    IERC20 USDC_TOKEN;
    IERC20 Degis_TOKEN;

    address randomNumberAddress;

    uint256 totalTickets;
    uint256 totalPrize;

    // All the needed info around a lottery
    struct LotteryInfo {
        uint256 lotteryID; // ID for lotto
        Status lotteryStatus; // Status for lotto
        uint256 prizePoolInCake; // The amount of cake for prize money
        uint256 costPerTicket; // Cost per ticket in $cake
        uint8[] prizeDistribution; // The distribution for prize money
        uint256 startingTimestamp; // Block timestamp for star of lotto
        uint256 closingTimestamp; // Block timestamp for end of entries
        uint16[] winningNumbers; // The winning numbers
    }
    // Lottery ID's to info
    mapping(uint256 => LotteryInfo) internal allLotteries_;

    //-------------------------------------------------------------------------
    // MODIFIERS
    //-------------------------------------------------------------------------

    modifier onlyRandomGenerator() {
        require(
            msg.sender == address(randomGenerator_),
            "Only random generator"
        );
        _;
    }

    modifier notContract() {
        require(!address(msg.sender).isContract(), "contract not allowed");
        require(msg.sender == tx.origin, "proxy contract not allowed");
        _;
    }

    modifier notClosed() {
        require(!closed, "GAME_ROUND_CLOSE");
        _;
    }

    //-------------------------------------------------------------------------
    // CONSTRUCTOR
    //-------------------------------------------------------------------------

    constructor(
        IERC20 _degisAddress,
        IERC20 _usdcAddress,
        address _randomNumberAddress,
        IDegisTicket _degisTicket
    ) {
        DEGIS_TOKEN = _degisAddress;
        USDC_TOKEN = _usdcAddress;

        randomNumberAddress = _randomNumberAddress;

        DEGIS_TOKEN = IERC20(_degisAddress);
        USDC_TOKEN = IERC20(_usdcAddress);
        RANDOM_NUMBER = RandomNumber(_randomNumberAddress);

        operator = msg.sender;

        maxDigital = 10000; // 0000~9999
        closed = false;

        maxCount = 50;
        minAmount = 10 ether;

        degisTicket = _degisTicket;
    }

    function initialize(address _degisTicket, address _IRandomNumberGenerator)
        external
        initializer
        onlyOwner
    {
        require(
            _lotteryNFT != address(0) && _IRandomNumberGenerator != address(0),
            "Contracts cannot be 0 address"
        );
        degisTicket = IDegisTicket(_degisTicket);
        randomGenerator_ = IRandomNumber(_IRandomNumberGenerator);
    }

    //-------------------------------------------------------------------------
    // VIEW FUNCTIONS
    //-------------------------------------------------------------------------
    function costToBuyTickets(uint256 _lotteryId, uint256 _numberOfTickets)
        external
        view
        returns (uint256 totalCost)
    {
        uint256 pricePer = allLotteries_[_lotteryId].costPerTicket;
        totalCost = pricePer.mul(_numberOfTickets);
    }

    function getBasicLottoInfo(uint256 _lotteryId)
        external
        view
        returns (LottoInfo memory)
    {
        return (allLotteries_[_lotteryId]);
    }

    function drawWinningNumbers(uint256 _lotteryId, uint256 _seed)
        external
        onlyOwner
    {
        // Checks that the lottery is past the closing block
        require(
            allLotteries_[_lotteryId].closingTimestamp <= getCurrentTime(),
            "Cannot set winning numbers during lottery"
        );
        // Checks lottery numbers have not already been drawn
        require(
            allLotteries_[_lotteryId].lotteryStatus == Status.Open,
            "Lottery State incorrect for draw"
        );
        // Sets lottery status to closed
        allLotteries_[_lotteryId].lotteryStatus = Status.Closed;
        // Requests a random number from the generator
        requestId_ = randomGenerator_.getRandomNumber(_lotteryId, _seed);
        // Emits that random number has been requested
        emit RequestNumbers(_lotteryId, requestId_);
    }

    // 由randomNumber合约调用, 在其得到随机数结果后, 更新到当前合约内
    function numbersDrawn(
        uint256 _lotteryId,
        bytes32 _requestId,
        uint256 _randomNumber
    ) external onlyRandomGenerator {
        require(
            allLotteries_[_lotteryId].lotteryStatus == Status.Closed,
            "Draw numbers first"
        );
        if (requestId_ == _requestId) {
            allLotteries_[_lotteryId].lotteryStatus = Status.Completed;
            allLotteries_[_lotteryId].winningNumbers = _split(_randomNumber);
        }

        emit LotteryClose(_lotteryId, degisTicket.getTotalSupply());
    }

    /**
     * @param   _prizeDistribution An array defining the distribution of the
     *          prize pool. I.e if a lotto has 5 numbers, the distribution could
     *          be [5, 10, 15, 20, 30] = 100%. This means if you get one number
     *          right you get 5% of the pool, 2 matching would be 10% and so on.
     * @param   _prizePoolInCake The amount of Cake available to win in this
     *          lottery.
     * @param   _startingTimestamp The block timestamp for the beginning of the
     *          lottery.
     * @param   _closingTimestamp The block timestamp after which no more tickets
     *          will be sold for the lottery. Note that this timestamp MUST
     *          be after the starting block timestamp.
     */
    function createNewLotto(
        uint8[] calldata _prizeDistribution, // e.g. [60, 20, 15, 5]
        uint256 _prizePoolInCake,
        uint256 _costPerTicket,
        uint256 _startingTimestamp,
        uint256 _closingTimestamp
    ) external onlyOwner returns (uint256 lotteryId) {
        require(
            _prizeDistribution.length == sizeOfLottery_,
            "Invalid distribution"
        );
        uint256 prizeDistributionTotal = 0;
        for (uint256 j = 0; j < _prizeDistribution.length; j++) {
            prizeDistributionTotal = prizeDistributionTotal.add(
                uint256(_prizeDistribution[j])
            );
        }
        // Ensuring that prize distribution total is 100%
        require(
            prizeDistributionTotal == 100,
            "Prize distribution is not 100%"
        );
        require(
            _prizePoolInCake != 0 && _costPerTicket != 0,
            "Prize or cost cannot be 0"
        );
        require(
            _startingTimestamp != 0 && _startingTimestamp < _closingTimestamp,
            "Timestamps for lottery invalid"
        );
        // Incrementing lottery ID
        lotteryIdCounter_ = lotteryIdCounter_.add(1);
        lotteryId = lotteryIdCounter_;
        uint16[] memory winningNumbers = new uint16[](sizeOfLottery_);
        Status lotteryStatus;
        if (_startingTimestamp >= getCurrentTime()) {
            lotteryStatus = Status.Open;
        } else {
            lotteryStatus = Status.NotStarted;
        }
        // Saving data in struct
        LottoInfo memory newLottery = LottoInfo(
            lotteryId,
            lotteryStatus,
            _prizePoolInCake,
            _costPerTicket,
            _prizeDistribution,
            _startingTimestamp,
            _closingTimestamp,
            winningNumbers
        );
        allLotteries_[lotteryId] = newLottery;

        // Emitting important information around new lottery.
        emit LotteryOpen(lotteryId, degisTicket.getTotalSupply());
    }

    //-------------------------------------------------------------------------
    // General Access Functions

    function batchBuyLottoTicket(
        uint256 _lotteryId,
        uint8 _numberOfTickets,
        uint16[] calldata _chosenNumbersForEachTicket
    ) external notContract {
        // Ensuring the lottery is within a valid time
        require(
            getCurrentTime() >= allLotteries_[_lotteryId].startingTimestamp,
            "Invalid time for mint:start"
        );
        require(
            getCurrentTime() < allLotteries_[_lotteryId].closingTimestamp,
            "Invalid time for mint:end"
        );
        if (allLotteries_[_lotteryId].lotteryStatus == Status.NotStarted) {
            if (
                allLotteries_[_lotteryId].startingTimestamp >= getCurrentTime()
            ) {
                allLotteries_[_lotteryId].lotteryStatus = Status.Open;
            }
        }
        require(
            allLotteries_[_lotteryId].lotteryStatus == Status.Open,
            "Lottery not in state for mint"
        );
        require(_numberOfTickets <= 50, "Batch mint too large");
        // Temporary storage for the check of the chosen numbers array
        uint256 numberCheck = _numberOfTickets.mul(sizeOfLottery_);
        // Ensuring that there are the right amount of chosen numbers
        require(
            _chosenNumbersForEachTicket.length == numberCheck,
            "Invalid chosen numbers"
        );
        // Getting the cost and discount for the token purchase
        (uint256 totalCost, uint256 discount, uint256 costWithDiscount) = this
            .costToBuyTicketsWithDiscount(_lotteryId, _numberOfTickets);
        // Transfers the required cake to this contract
        cake_.transferFrom(msg.sender, address(this), costWithDiscount);
        // Batch mints the user their tickets
        uint256[] memory ticketIds = degisTicket.batchMint(
            msg.sender,
            _lotteryId,
            _numberOfTickets,
            _chosenNumbersForEachTicket,
            sizeOfLottery_
        );
        // Emitting event with all information
        emit NewBatchMint(
            msg.sender,
            ticketIds,
            _chosenNumbersForEachTicket,
            totalCost,
            discount,
            costWithDiscount
        );
    }

    function claimReward(uint256 _lotteryId, uint256 _tokenId)
        external
        notContract
    {
        // Checking the lottery is in a valid time for claiming
        require(
            allLotteries_[_lotteryId].closingTimestamp <= getCurrentTime(),
            "Wait till end to claim"
        );
        // Checks the lottery winning numbers are available
        require(
            allLotteries_[_lotteryId].lotteryStatus == Status.Completed,
            "Winning Numbers not chosen yet"
        );
        require(
            degisTicket.getOwnerOfTicket(_tokenId) == msg.sender,
            "Only the owner can claim"
        );
        // Sets the claim of the ticket to true (if claimed, will revert)
        require(
            degisTicket.claimTicket(_tokenId, _lotteryId),
            "Numbers for ticket invalid"
        );
        // Getting the number of matching tickets
        uint8 matchingNumbers = _getNumberOfMatching(
            degisTicket.getTicketNumbers(_tokenId),
            allLotteries_[_lotteryId].winningNumbers
        );
        // Getting the prize amount for those matching tickets
        uint256 prizeAmount = _prizeForMatching(matchingNumbers, _lotteryId);
        // Removing the prize amount from the pool
        allLotteries_[_lotteryId].prizePoolInCake = allLotteries_[_lotteryId]
            .prizePoolInCake
            .sub(prizeAmount);
        // Transfering the user their winnings
        cake_.safeTransfer(address(msg.sender), prizeAmount);
    }

    function batchClaimRewards(uint256 _lotteryId, uint256[] calldata _tokeIds)
        external
        notContract
    {
        require(_tokeIds.length <= 50, "Batch claim too large");
        // Checking the lottery is in a valid time for claiming
        require(
            allLotteries_[_lotteryId].closingTimestamp <= getCurrentTime(),
            "Wait till end to claim"
        );
        // Checks the lottery winning numbers are available
        require(
            allLotteries_[_lotteryId].lotteryStatus == Status.Completed,
            "Winning Numbers not chosen yet"
        );
        // Creates a storage for all winnings
        uint256 totalPrize = 0;
        // Loops through each submitted token
        for (uint256 i = 0; i < _tokeIds.length; i++) {
            // Checks user is owner (will revert entire call if not)
            require(
                degisTicket.getOwnerOfTicket(_tokeIds[i]) == msg.sender,
                "Only the owner can claim"
            );
            // If token has already been claimed, skip token
            if (degisTicket.getTicketClaimStatus(_tokeIds[i])) {
                continue;
            }
            // Claims the ticket (will only revert if numbers invalid)
            require(
                degisTicket.claimTicket(_tokeIds[i], _lotteryId),
                "Numbers for ticket invalid"
            );
            // Getting the number of matching tickets
            uint8 matchingNumbers = _getNumberOfMatching(
                degisTicket.getTicketNumbers(_tokeIds[i]),
                allLotteries_[_lotteryId].winningNumbers
            );
            // Getting the prize amount for those matching tickets
            uint256 prizeAmount = _prizeForMatching(
                matchingNumbers,
                _lotteryId
            );
            // Removing the prize amount from the pool
            allLotteries_[_lotteryId].prizePoolInCake = allLotteries_[
                _lotteryId
            ].prizePoolInCake.sub(prizeAmount);
            totalPrize = totalPrize.add(prizeAmount);
        }
        // Transferring the user their winnings
        USDC_TOKEN.safeTransfer(address(msg.sender), totalPrize);
    }

    // 退注
    function redeem(uint256[] memory codes) external notClosed returns (bool) {
        checkRedeemValue(codes);

        if (redeemAddress(codes, msg.sender)) {
            return true;
        } else {
            emit Redeem(msg.sender, false, codes, 0);
            return false;
        }
    }

    // 领奖
    function prizeWithdraw() external notClosed returns (bool) {
        require(userInfoMap[msg.sender].prize > 0, "NO_PRIZE_TO_WITHDRAW");
        if (prizeWithdrawAddress(msg.sender)) {
            return true;
        } else {
            emit PrizeWithdraw(msg.sender, false, 0);
            return false;
        }
    }

    // 手动添加奖励
    function prizeIncome(uint256 _amount) external onlyOwner returns (bool) {
        USDC_TOKEN.safeTransferFrom(msg.sender, address(this), _amount);
        totalPrize += _amount;
        emit PrizeIncome(msg.sender, _amount);
        return true;
    }

    /// --------------运维--------------------------

    /// @dev This function is called regularly by the robot every 6 morning to open betting.
    function open() external onlyOwner {
        closed = false;
    }

    /// @dev This function is called regularly by the robot on 4 nights a week to close bets.
    function close() external onlyOwner {
        closed = true;
    }

    /// @dev The settlement robot calls this function daily to update the capital pool and settle the pending refund.
    function update() external onlyOwner {
        require(totalPrize <= getBalance(USDC_TOKEN), "SC_BALANCE_ERROR");

        require(totalTickets <= getBalance(DEGIS_TOKEN), "SC_BALANCE_ERROR");

        updateBalance();
    }

    /// @dev The owner calls this function to set the operator address.
    /// @param op This is operator address.
    function setOperator(address op) external onlyOwner {
        require(op != address(0), "INVALID_ADDRESS");
        operator = op;
    }

    /// @dev Owner calls this function to modify the number of lucky draw digits, and the random number takes the modulus of this number.
    /// @param max New value.
    function setMaxDigital(uint256 max) external onlyOwner {
        require(max > 0, "MUST_GREATER_THAN_ZERO");
        maxDigital = max;
    }

    /// @dev Get a user's codes and amounts;
    function getUserCodeList(address user)
        external
        view
        returns (uint256[] memory codes, uint256[] memory amounts)
    {
        uint256 code_amount = userInfoMap[user].codeCount;

        codes = new uint256[](code_amount);
        amounts = new uint256[](code_amount);

        for (uint256 i = 0; i < code_amount; i++) {
            codes[i] = userInfoMap[user].indexCodeMap[i];
            amounts[i] = userInfoMap[user].codeAmountMap[codes[i]];
        }
    }

    function getEpochId() external view returns (uint256) {
        return epochId;
    }

    function getEpochInfo(uint256 epochId)
        external
        view
        returns (
            uint256,
            bool,
            bool
        )
    {
        return (
            epochInfo[epochId].randomNumber,
            epochInfo[epochId].isUsed,
            epochInfo[epochId].isDrawed
        );
    }

    function getUserPrize(address user)
        external
        view
        onlyOwner
        returns (uint256)
    {
        uint256 prize = userInfoMap[user].prize;
        return prize;
    }

    function getMyPrzie() external view returns (uint256) {
        uint256 prize = userInfoMap[msg.sender].prize;
        return prize;
    }

    function getLuckyNumber(uint256 _epochId)
        external
        view
        onlyOwner
        returns (uint256)
    {
        require(epochInfo[_epochId].isUsed == true, "LUCKY_NUMBER_NOT_READY");
        return epochInfo[_epochId].randomNumber;
    }

    /// --------------Private Method--------------------------
    function checkBuyValue(uint256[] memory codes, uint256[] memory amounts)
        private
        view
    {
        require(tx.origin == msg.sender, "NOT_ALLOW_SMART_CONTRACT");
        require(
            codes.length == amounts.length,
            "CODES_AND_AMOUNTS_LENGTH_NOT_EUQAL"
        );
        require(codes.length > 0, "INVALID_CODES_LENGTH");
        require(codes.length <= maxCount, "CODES_LENGTH_TOO_LONG");
    }

    function checkRedeemValue(uint256[] memory codes) private view {
        require(codes.length > 0, "INVALID_CODES_LENGTH");
        require(codes.length <= maxCount, "CODES_LENGTH_TOO_LONG");

        uint256 length = codes.length;

        //check codes
        for (uint256 i = 0; i < length; i++) {
            require(
                userInfoMap[msg.sender].codeIndexMap[codes[i]] > 0,
                "CODE_NOT_EXIST"
            );
            require(codes[i] < maxDigital, "OUT_OF_MAX_DIGITAL");
            for (uint256 m = i + 1; m < length; m++) {
                require(codes[i] != codes[m], "CODES_MUST_NOT_SAME");
            }

            // require(pendingRedeemSearchMap[msg.sender][codes[i]] == 0, "STAKER_CODE_IS_EXITING");
        }
    }

    /// @dev Remove user info map.
    function removeUserCodesMap(uint256 codeToRemove, address user) private {
        require(
            userInfoMap[user].codeIndexMap[codeToRemove] > 0,
            "CODE_NOT_EXIST"
        );
        require(userInfoMap[user].codeCount != 0, "CODE_COUNT_IS_ZERO");

        if (userInfoMap[user].codeCount > 1) {
            // get code index in map
            uint256 i = userInfoMap[user].codeIndexMap[codeToRemove] - 1;
            // save last element to index position
            userInfoMap[user].indexCodeMap[i] = userInfoMap[user].indexCodeMap[
                userInfoMap[user].codeCount - 1
            ];
            // update index of swap element
            userInfoMap[user].codeIndexMap[userInfoMap[user].indexCodeMap[i]] =
                i +
                1;
        }

        // remove the index of record
        userInfoMap[user].codeIndexMap[codeToRemove] = 0;

        // remove last element
        userInfoMap[user].indexCodeMap[userInfoMap[user].codeCount - 1] = 0;
        userInfoMap[user].codeCount = userInfoMap[user].codeCount.sub(1);
    }

    function removeCodeInfoMap(uint256 code, address user) private {
        require(
            indexCodeMap[code].addressIndexMap[user] > 0,
            "CODE_NOT_EXIST_2"
        );
        require(indexCodeMap[code].addrCount != 0, "ADDRESS_COUNT_IS_ZERO");

        if (indexCodeMap[code].addrCount > 1) {
            uint256 i = indexCodeMap[code].addressIndexMap[user] - 1;
            indexCodeMap[code].indexAddressMap[i] = indexCodeMap[code]
                .indexAddressMap[indexCodeMap[code].addrCount - 1];
            indexCodeMap[code].addressIndexMap[
                indexCodeMap[code].indexAddressMap[i]
            ] = i + 1;
        }

        indexCodeMap[code].addressIndexMap[user] = 0;
        indexCodeMap[code].indexAddressMap[
            indexCodeMap[code].addrCount - 1
        ] = address(0);
        indexCodeMap[code].addrCount = indexCodeMap[code].addrCount.sub(1);
    }

    function redeemAddress(uint256[] memory codes, address user)
        private
        returns (bool)
    {
        uint256 totalAmount = 0;

        // total amount to be redeemed
        for (uint256 i = 0; i < codes.length; i++) {
            totalAmount = totalAmount.add(
                userInfoMap[user].codeAmountMap[codes[i]]
            );
        }

        require(totalAmount > 0, "REDEEM_TOTAL_AMOUNT_SHOULD_NOT_ZERO");

        if (totalAmount <= totalTickets) {
            require(
                totalTickets <= getBalance(DEGIS_TOKEN),
                "SC_BALANCE_ERROR"
            );

            totalTickets -= totalAmount;

            for (uint256 m = 0; m < codes.length; m++) {
                userInfoMap[user].codeAmountMap[codes[m]] = 0;
                removeUserCodesMap(codes[m], user);
                removeCodeInfoMap(codes[m], user);
            }

            DEGIS_TOKEN.safeTransfer(user, totalAmount);
            emit Redeem(user, true, codes, totalAmount);
            return true;
        }
        return false;
    }

    function prizeWithdrawAddress(address user) private returns (bool) {
        uint256 user_prize = userInfoMap[user].prize;
        if (user_prize <= totalPrize) {
            require(totalPrize <= getBalance(USDC_TOKEN), "SC_BALANCE_ERROR");

            totalPrize -= user_prize;

            userInfoMap[user].prize = 0;

            USDC_TOKEN.safeTransfer(user, user_prize);
            emit PrizeWithdraw(msg.sender, true, user_prize);
            return true;
        }
        return false;
    }

    function updateBalance() private returns (bool) {
        if (getBalance(USDC_TOKEN) > totalPrize) {
            totalPrize = getBalance(USDC_TOKEN);
            return true;
        }

        return false;
    }

    function getBalance(IERC20 token) private view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function getUsdcTokenAddress() public view returns (address) {
        return usdcAddress;
    }

    function getDegisTokenAddress() public view returns (address) {
        return degisAddress;
    }

    function _getNumberOfMatching(
        uint16[] memory _usersNumbers,
        uint16[] memory _winningNumbers
    ) internal pure returns (uint8 noOfMatching) {
        // Loops through all wimming numbers
        for (uint256 i = 0; i < _winningNumbers.length; i++) {
            // If the winning numbers and user numbers match
            if (_usersNumbers[i] == _winningNumbers[i]) {
                // The number of matching numbers increases
                noOfMatching += 1;
            }
        }
    }

    /**
     * @param   _noOfMatching: The number of matching numbers the user has
     * @param   _lotteryId: The ID of the lottery the user is claiming on
     * @return  uint256: The prize amount in cake the user is entitled to
     */
    function _prizeForMatching(uint8 _noOfMatching, uint256 _lotteryId)
        internal
        view
        returns (uint256)
    {
        uint256 prize = 0;
        // If user has no matching numbers their prize is 0
        if (_noOfMatching == 0) {
            return 0;
        }
        // Getting the percentage of the pool the user has won
        uint256 perOfPool = allLotteries_[_lotteryId].prizeDistribution[
            _noOfMatching - 1
        ];
        // Timesing the percentage one by the pool
        prize = allLotteries_[_lotteryId].prizePoolInCake.mul(perOfPool);
        // Returning the prize divided by 100 (as the prize distribution is scaled)
        return prize.div(100);
    }

    function _split(uint256 _randomNumber)
        internal
        view
        returns (uint16[] memory)
    {
        // Temparary storage for winning numbers
        uint16[] memory winningNumbers = new uint16[](sizeOfLottery_);
        // Loops the size of the number of tickets in the lottery
        for (uint256 i = 0; i < sizeOfLottery_; i++) {
            // Encodes the random number with its position in loop
            bytes32 hashOfRandom = keccak256(
                abi.encodePacked(_randomNumber, i)
            );
            // Casts random number hash into uint256
            uint256 numberRepresentation = uint256(hashOfRandom);
            // Sets the winning number position to a uint16 of random hash number
            winningNumbers[i] = uint16(
                numberRepresentation.mod(maxValidRange_)
            );
        }
        return winningNumbers;
    }
}
