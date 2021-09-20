// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IDegisTicket is IERC1155 {
    function mintDegisTicket(address) external;
}
