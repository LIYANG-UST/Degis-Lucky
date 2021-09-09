// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./xDegis.sol";
import "./lib/LibOwnable.sol";
import "./lib/Types.sol";
import "./lib/SafeMath.sol";
import "./DegisStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract DegisBar is LibOwnable ,DegisStorage{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    modifier notClosed() {
        require(!closed, "GAME_ROUND_CLOSE");
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == operator, "NOT_OPERATOR");
        _;
    }

    IERC20 DEGIS_TOKEN;
    IERC20 USDC_TOKEN;

    constructor(address _degisAddress, address _usdcAddress) {
        DEGIS_TOKEN = IERC20(_degisAddress);
        USDC_TOKEN = IERC20(_usdcAddress);
    }

    /// --------------Public Method--------------------------
    function init() external onlyOwner {
        // poolInfo.delegatePercent = 700; // 70%
        maxDigital = 10000; // 0000~9999
        closed = false;
        feeRate = 0;
        // posPrecompileAddress = address(0xda);
        // randomPrecompileAddress = address(0x262);
        maxCount = 50;
        minAmount = 10 ether;
        // minGasLeft = 100000;
        // firstDelegateMinValue = 100 ether;
        epochId = 0;
    }

    // 压注 
    function buy(uint256[] calldata codes, uint256[] calldata amounts) external notClosed {
        checkBuyValue(codes, amounts);

        uint256 totalAmount = 0;

        for (uint256 i = 0; i < codes.length; i++) {
            require(amounts[i] >= minAmount, "Amount is too small");
            require(amounts[i] % minAmount == 0, "AMOUNT_MUST_TIMES_10");
            require(codes[i] < maxDigital, "OUT_OF_MAX_DIGITAL");
            // require(pendingRedeemSearchMap[msg.sender][codes[i]] == 0, "BUYING_CODE_IS_EXITING");

            totalAmount += amounts[i];

            if (userInfoMap[msg.sender].codeIndexMap[codes[i]] == 0) {
                userInfoMap[msg.sender].indexCodeMap[userInfoMap[msg.sender].codeCount] = codes[i];
                userInfoMap[msg.sender].codeCount = userInfoMap[msg.sender].codeCount + 1; //???令人迷惑
                userInfoMap[msg.sender].codeIndexMap[codes[i]] = userInfoMap[msg.sender].codeCount;
            }

            userInfoMap[msg.sender].codeAmountMap[codes[i]] =
                userInfoMap[msg.sender].codeAmountMap[codes[i]] +
                amounts[i];

            //Save code info
            if (indexCodeMap[codes[i]].addressIndexMap[msg.sender] == 0) {
                indexCodeMap[codes[i]].indexAddressMap[indexCodeMap[codes[i]].addrCount] = msg.sender;
                indexCodeMap[codes[i]].addrCount = indexCodeMap[codes[i]].addrCount + 1; //???令人迷惑
                indexCodeMap[codes[i]].addressIndexMap[msg.sender] = indexCodeMap[codes[i]].addrCount;
            }
        }

        //check weather the maximum number is exceeded 
        require(
            userInfoMap[msg.sender].codeCount <= maxCount,
            "OUT_OF_MAX_COUNT"
        );

        //transform token
        DEGIS_TOKEN.safeTransferFrom(msg.sender, address(this), totalAmount);
        degisPoolInfo.demandDepositPool = degisPoolInfo.demandDepositPool.add(totalAmount);

        emit Buy(msg.sender, totalAmount, codes, amounts);
    }

    // 退注
    function redeem(uint256[] memory codes) external notClosed returns (bool)
    {
        checkRedeemValue(codes);

        if (redeemAddress(codes, msg.sender)) {
            return true;
        } else {
            // for (uint256 n = 0; n < codes.length; n++) {
            //     pendingRedeemMap[pendingRedeemStartIndex + pendingRedeemCount].user = msg.sender;
            //     pendingRedeemMap[pendingRedeemStartIndex + pendingRedeemCount].code = codes[n];
            //     pendingRedeemCount = pendingRedeemCount.add(1);
            //     pendingRedeemSearchMap[msg.sender][codes[n]] = 1;
            // }
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
            // for (uint256 i = pendingPrizeWithdrawStartIndex; i < pendingPrizeWithdrawStartIndex + pendingPrizeWithdrawCount; i++) {
            //     require(pendingPrizeWithdrawMap[i] != msg.sender, "ALREADY_WITHDRAWING");
            // }
            // pendingPrizeWithdrawMap[pendingPrizeWithdrawStartIndex + pendingPrizeWithdrawCount] = msg.sender;
            // pendingPrizeWithdrawCount = pendingPrizeWithdrawCount.add(1);
            emit PrizeWithdraw(msg.sender, false, 0);
            return false;
        }
    }

    // 保险收益进入奖池
    function prizeIncome(uint256 totalAmount) external onlyOperator returns(bool)
    {
        USDC_TOKEN.safeTransferFrom(msg.sender, address(this), totalAmount);
        usdcPoolInfo.prizePool = usdcPoolInfo.prizePool.add(totalAmount);
        emit PrizeIncome(msg.sender, totalAmount);
        return true;
    }

    // 开奖
    function settlement() external onlyOperator  {
        require(closed, "MUST_CLOSE_BEFORE_SETTLEMENT");

        // should use the random number latest
        epochId = epochId.add(1); 
        currentRandom = getLuckyNumber();

        require(currentRandom != 0, "RANDOM_NUMBER_NOT_READY");

        uint256 winnerCode = uint256(currentRandom.mod(maxDigital));

        uint256 prizePool = usdcPoolInfo.prizePool;

        address[] memory winners;

        uint256[] memory amounts;

        if (indexCodeMap[winnerCode].addrCount > 0) {
            winners = new address[](indexCodeMap[winnerCode].addrCount);
            amounts = new uint256[](indexCodeMap[winnerCode].addrCount);

            uint256 winnerStakeAmountTotal = 0;
            for (uint256 i = 0; i < indexCodeMap[winnerCode].addrCount; i++) {
                winners[i] = indexCodeMap[winnerCode].indexAddressMap[i];
                winnerStakeAmountTotal = winnerStakeAmountTotal.add(
                    userInfoMap[winners[i]].codeAmountMap[winnerCode]
                );
            }

            for (uint256 j = 0; j < indexCodeMap[winnerCode].addrCount; j++) {
                amounts[j] = prizePool
                    .mul(userInfoMap[winners[j]].codeAmountMap[winnerCode])
                    .div(winnerStakeAmountTotal);
                userInfoMap[winners[j]].prize = userInfoMap[winners[j]]
                    .prize
                    .add(amounts[j]);
            }

            usdcPoolInfo.demandDepositPool = usdcPoolInfo.demandDepositPool.add(
                prizePool
            );

            usdcPoolInfo.prizePool = 0;

        } else {
            winners = new address[](1);
            winners[0] = address(0);
            amounts = new uint256[](1);
            amounts[0] = 0;
        }

        emit RandomGenerate(epochId, currentRandom);
        emit LotteryResult(epochId, winnerCode, prizePool, winners, amounts);
    }


    /// --------------运维--------------------------

    /// @dev This function is called regularly by the robot every 6 morning to open betting.
    function open() external onlyOperator {
        closed = false;
    }

    /// @dev This function is called regularly by the robot on 4 nights a week to close bets.
    function close() external onlyOperator {
        closed = true;
    }

    /// @dev The settlement robot calls this function daily to update the capital pool and settle the pending refund.
    function update() external onlyOperator  {
        require(
            usdcPoolInfo.demandDepositPool <= getBalance(USDC_TOKEN),
            "SC_BALANCE_ERROR"
        );

        require(
            degisPoolInfo.demandDepositPool <= getBalance(DEGIS_TOKEN),
            "SC_BALANCE_ERROR"
        );

        updateBalance();
    }

    /// @dev The owner calls this function to set the operator address.
    /// @param op This is operator address.
    function setOperator(address op) external onlyOwner  {
        require(op != address(0), "INVALID_ADDRESS");
        operator = op;
    }

    /// @dev Owner calls this function to modify the number of lucky draw digits, and the random number takes the modulus of this number.
    /// @param max New value.
    function setMaxDigital(uint256 max) external onlyOwner  {
        require(max > 0, "MUST_GREATER_THAN_ZERO");
        maxDigital = max;
    }

    /// @dev Get a user's codes and amounts;
    function getUserCodeList(address user)
        external
        view
        returns (uint256[] memory codes, uint256[] memory amounts)
    {
        uint256 cnt = userInfoMap[user].codeCount;
        codes = new uint256[](cnt);
        amounts = new uint256[](cnt);
        // exits = new uint256[](cnt);
        for (uint256 i = 0; i < cnt; i++) {
            codes[i] = userInfoMap[user].indexCodeMap[i];
            amounts[i] = userInfoMap[user].codeAmountMap[codes[i]];
            // exits[i] = pendingRedeemSearchMap[user][codes[i]];
        }
    }

    /// --------------Private Method--------------------------


    // TODO
    function getLuckyNumber() private pure returns(uint256) {
        uint256 luckNumber = 9999;
        return luckNumber;
    }

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
            require(userInfoMap[msg.sender].codeIndexMap[codes[i]] > 0, "CODE_NOT_EXIST");
            require(codes[i] < maxDigital, "OUT_OF_MAX_DIGITAL");
            for (uint256 m = i + 1; m < length; m++) {
                require(codes[i] != codes[m], "CODES_MUST_NOT_SAME");
            }

            // require(pendingRedeemSearchMap[msg.sender][codes[i]] == 0, "STAKER_CODE_IS_EXITING");
        }
    }

    /// @dev Remove user info map.
    function removeUserCodesMap(uint256 codeToRemove, address user) private {
        require(userInfoMap[user].codeIndexMap[codeToRemove] > 0, "CODE_NOT_EXIST");
        require(userInfoMap[user].codeCount != 0, "CODE_COUNT_IS_ZERO");

        if (userInfoMap[user].codeCount > 1) {
            // get code index in map
            uint256 i = userInfoMap[user].codeIndexMap[codeToRemove] - 1;
            // save last element to index position
            userInfoMap[user].indexCodeMap[i] = userInfoMap[user].indexCodeMap[userInfoMap[user].codeCount - 1];
            // update index of swap element
            userInfoMap[user].codeIndexMap[userInfoMap[user].indexCodeMap[i]] = i + 1;
        }

        // remove the index of record
        userInfoMap[user].codeIndexMap[codeToRemove] = 0;

        // remove last element
        userInfoMap[user].indexCodeMap[userInfoMap[user].codeCount - 1] = 0;
        userInfoMap[user].codeCount = userInfoMap[user].codeCount.sub(1);
    }

    function removeCodeInfoMap(uint256 code, address user) private {
        require(indexCodeMap[code].addressIndexMap[user] > 0, "CODE_NOT_EXIST_2");
        require(indexCodeMap[code].addrCount != 0, "ADDRESS_COUNT_IS_ZERO");

        if (indexCodeMap[code].addrCount > 1) {
            uint256 i = indexCodeMap[code].addressIndexMap[user] - 1;
            indexCodeMap[code].indexAddressMap[i] = indexCodeMap[code].indexAddressMap[indexCodeMap[code].addrCount - 1];
            indexCodeMap[code].addressIndexMap[indexCodeMap[code].indexAddressMap[i]] = i + 1;
        }

        indexCodeMap[code].addressIndexMap[user] = 0;
        indexCodeMap[code].indexAddressMap[indexCodeMap[code].addrCount - 1] = address(0);
        indexCodeMap[code].addrCount = indexCodeMap[code].addrCount.sub(1);
    }

    function redeemAddress(uint256[] memory codes, address user)
        private
        returns (bool)
    {
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < codes.length; i++) {
            totalAmount = totalAmount.add(
                userInfoMap[user].codeAmountMap[codes[i]]
            );
        }

        require(totalAmount > 0, "REDEEM_TOTAL_AMOUNT_SHOULD_NOT_ZERO");

        if (totalAmount <= degisPoolInfo.demandDepositPool) {
            require(
                degisPoolInfo.demandDepositPool <= getBalance(DEGIS_TOKEN),
                "SC_BALANCE_ERROR"
            );

            degisPoolInfo.demandDepositPool = degisPoolInfo.demandDepositPool.sub(
                totalAmount
            );

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
        uint256 totalAmount = userInfoMap[user].prize;
        if (totalAmount <= usdcPoolInfo.demandDepositPool) {
            require(
                usdcPoolInfo.demandDepositPool <= getBalance(USDC_TOKEN),
                "SC_BALANCE_ERROR"
            );

            usdcPoolInfo.demandDepositPool = usdcPoolInfo.demandDepositPool.sub(
                totalAmount
            );

            userInfoMap[user].prize = 0;

            USDC_TOKEN.safeTransfer(user, totalAmount);
            emit PrizeWithdraw(msg.sender, true, totalAmount);
            return true;
        }
        return false;
    }

    function updateBalance() private returns (bool) {
        if (
            getBalance(USDC_TOKEN) > usdcPoolInfo.demandDepositPool
        ) {
            usdcPoolInfo.prizePool = getBalance(USDC_TOKEN).sub(
                     usdcPoolInfo.demandDepositPool
            );
            return true;
        }

        return false;
    }

    function prizeWithdrawPendingRefund() private returns (bool) {
        for (; pendingPrizeWithdrawCount > 0; ) {
            uint256 i = pendingPrizeWithdrawStartIndex;
            require(
                pendingPrizeWithdrawMap[i] != address(0),
                "PRIZE_WITHDRAW_ADDRESS_ERROR"
            );

            if (gasleft() < minGasLeft) {
                emit GasNotEnough();
                return false;
            }

            if (prizeWithdrawAddress(pendingPrizeWithdrawMap[i])) {
                pendingPrizeWithdrawStartIndex = pendingPrizeWithdrawStartIndex.add(1);
                pendingPrizeWithdrawCount = pendingPrizeWithdrawCount.sub(1);
            } else {
                return false;
            }
        }
        return true;
    }

    function getBalance(IERC20 token) private view returns(uint256)
    {
        return token.balanceOf(address(this));
    }
}
