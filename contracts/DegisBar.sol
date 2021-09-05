// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./xDegis.sol";

contract DegisBar {

    address owner;

    uint256 public minAmount = 10e18;
    uint256 public luckyDivider = 10000;
    uint256 public randomNumber;

    struct UserInfo {
        uint256 prize;
        uint256 codeCount;
        mapping(uint256 => uint256) indexCodeMap;      // map: index => userCode (index start from 0)
        mapping(uint256 => uint256) codeIndexMap;      // map: userCode => index
        mapping(uint256 => uint256) codeAmountMap;     // map: userCode => amount
    }

    mapping(address => uint256) userBalance;



    modifier onlyOwner() {
        require(msg.sender == owner, 'only the owner can call this function');
        _;
    }


    function deposit() public {

    }

    function withdraw() public {

    }

    function getLuckyNumber() public onlyOwner {

    }
}