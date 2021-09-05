// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./xDegis.sol";
import "./lib/LibOwnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DegisBar is LibOwnable {
    using SafeERC20 for IERC20;

    IERC20 DegisToken;

    uint256 public minAmount = 10e18;
    uint256 public maxCount = 50;
    uint256 public maxDigital = 10000;
    uint256 public randomNumber;

    struct UserInfo {
        uint256 prize;
        uint256 codeCount;
        mapping(uint256 => uint256) indexCodeMap; // map: index => userCode (index start from 0)
        mapping(uint256 => uint256) codeIndexMap; // map: userCode => index
        mapping(uint256 => uint256) codeAmountMap; // map: userCode => amount
    }

    struct CodeInfo {
        uint256 addrCount;
        mapping(uint256 => address) indexAddressMap;
        mapping(address => uint256) addressIndexMap;
    }

    mapping(address => UserInfo) userInfo;
    mapping(uint256 => CodeInfo) public indexCodeMap;

    constructor(IERC20 _degisAddress) {
        DegisToken = _degisAddress;
    }

    function buy(uint256[] calldata codes, uint256[] calldata amounts) public {
        checkBuyValue(codes, amounts);

        uint256 totalAmount = 0;

        for (uint256 i = 0; i < codes.length; i++) {
            require(amounts[i] >= minAmount, "Amount is too small");
            require(amounts[i] % minAmount == 0, "AMOUNT_MUST_TIMES_10");
            require(codes[i] < maxDigital, "OUT_OF_MAX_DIGITAL");

            totalAmount += amounts[i];

            if (userInfo[msg.sender].codeIndexMap[codes[i]] == 0) {
                userInfo[msg.sender].indexCodeMap[
                    userInfo[msg.sender].codeCount
                ] = codes[i];
                userInfo[msg.sender].codeCount =
                    userInfo[msg.sender].codeCount +
                    1;
                userInfo[msg.sender].codeIndexMap[codes[i]] = userInfo[
                    msg.sender
                ].codeCount;
            }

            userInfo[msg.sender].codeAmountMap[codes[i]] =
                userInfo[msg.sender].codeAmountMap[codes[i]] +
                amounts[i];

            //Save code info
            if (indexCodeMap[codes[i]].addressIndexMap[msg.sender] == 0) {
                indexCodeMap[codes[i]].indexAddressMap[
                    indexCodeMap[codes[i]].addrCount
                ] = msg.sender;
                indexCodeMap[codes[i]].addrCount =
                    indexCodeMap[codes[i]].addrCount +
                    1;

                indexCodeMap[codes[i]].addressIndexMap[
                    msg.sender
                ] = indexCodeMap[codes[i]].addrCount;
            }
        }
    }

    function withdraw() public {}

    function prizeWithdraw() public {}

    function getLuckyNumber() public onlyOwner {}

    function settlement() public {}

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
}
