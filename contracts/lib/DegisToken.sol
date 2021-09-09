// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DegisToken is ERC20 {
    address public minter;
    address public owner;
    event MinterChanged(address indexed from, address to);

    /**
     * @notice use ERC20 constructor and set the owner
     */
    constructor() payable ERC20("DegisToken", "DEGIS") {
        minter = msg.sender;
        owner = msg.sender;
    }

    /**
     * @notice get the balance that one user(LP) can unlock(maximum)
     * @param _newMinter: new minter's address
     */
    function passMinterRole(address _newMinter) public returns (bool) {
        require(
            msg.sender == owner,
            "Error! only the owner can change the minter role"
        );
        minter = _newMinter;

        emit MinterChanged(msg.sender, _newMinter);
        return true;
    }

    /**
     * @notice mint _amount tokens to _account
     * @param _account: receiver's address
     * @param _amount: amount to be minted
     */
    function mint(address _account, uint256 _amount) public {
        //check if msg.sender have minter role
        require(msg.sender == minter, "Error! Msg.sender must be the minter");

        _mint(_account, _amount);
    }
}
