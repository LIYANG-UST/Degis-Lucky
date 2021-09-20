// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/accsess/Ownable.sol";
import "./interfaces/IDegisBar.sol";

contract DegisTicket is ERC1155, Ownable {
    // Interface of degisBar, need to interact with
    IDegisBar degisBar;

    // total supply
    uint256 internal totalSupply;

    struct TicketInfo {
        address owner;
        uint16[] numbers;
        bool claimed;
        uint256 lotteryId;
    }

    // token id => token information
    mapping(uint256 => TicketInfo) internal ticketInfo;

    // user address => lottery ID => ticket IDs
    mapping(address => mapping(uint256 => uint256[])) internal userTickets;

    constructor(string memory _uri, IDegisBar _degisBar) ERC1155(_uri) {
        _nextId = 1;
        degisBar = _degisBar;
    }

    function mintDegisTicket(address _to) public {
        uint256 tokenId = _nextId++;
        _mint(_to, tokenId);
    }

    function getTotalSupply() external view returns (uint256) {
        return totalSupply_;
    }

    /**
     * @param   _ticketID: The unique ID of the ticket
     * @return  uint16[]: The chosen numbers for that ticket
     */
    function getTicketNumbers(uint256 _ticketID)
        external
        view
        returns (uint16[] memory)
    {
        return ticketInfo_[_ticketID].numbers;
    }

    /**
     * @param   _ticketID: The unique ID of the ticket
     * @return  address: Owner of ticket
     */
    function getOwnerOfTicket(uint256 _ticketID)
        external
        view
        returns (address)
    {
        return ticketInfo_[_ticketID].owner;
    }

    function getTicketClaimStatus(uint256 _ticketID)
        external
        view
        returns (bool)
    {
        return ticketInfo_[_ticketID].claimed;
    }

    function getUserTickets(uint256 _lotteryId, address _user)
        external
        view
        returns (uint256[] memory)
    {
        return userTickets_[_user][_lotteryId];
    }

    /**
     * @param   _to The address being minted to
     * @param   _numberOfTickets The number of NFT's to mint
     * @notice  Only the lotto contract is able to mint tokens. 
        // uint8[][] calldata _lottoNumbers
     */
    function batchMint(
        address _to,
        uint256 _lotteryId,
        uint8 _numberOfTickets,
        uint16[] calldata _numbers,
        uint8 sizeOfLottery
    ) external onlyLotto returns (uint256[] memory) {
        // Storage for the amount of tokens to mint (always 1)
        uint256[] memory amounts = new uint256[](_numberOfTickets);
        // Storage for the token IDs
        uint256[] memory tokenIds = new uint256[](_numberOfTickets);
        for (uint8 i = 0; i < _numberOfTickets; i++) {
            // Incrementing the tokenId counter
            totalSupply_ = totalSupply_.add(1);
            tokenIds[i] = totalSupply_;
            amounts[i] = 1;
            // Getting the start and end position of numbers for this ticket
            uint16 start = uint16(i.mul(sizeOfLottery));
            uint16 end = uint16((i.add(1)).mul(sizeOfLottery));
            // Splitting out the chosen numbers
            uint16[] calldata numbers = _numbers[start:end];
            // Storing the ticket information
            ticketInfo_[totalSupply_] = TicketInfo(
                _to,
                numbers,
                false,
                _lotteryId
            );
            userTickets_[_to][_lotteryId].push(totalSupply_);
        }
        // Minting the batch of tokens
        _mintBatch(_to, tokenIds, amounts, msg.data);
        // Emitting relevant info
        emit InfoBatchMint(_to, _lotteryId, _numberOfTickets, tokenIds);
        // Returns the token IDs of minted tokens
        return tokenIds;
    }

    function claimTicket(uint256 _ticketID, uint256 _lotteryId)
        external
        onlyLotto
        returns (bool)
    {
        require(
            ticketInfo_[_ticketID].claimed == false,
            "Ticket already claimed"
        );
        require(
            ticketInfo_[_ticketID].lotteryId == _lotteryId,
            "Ticket not for this lottery"
        );
        uint256 maxRange = ILottery(lotteryContract_).getMaxRange();
        for (uint256 i = 0; i < ticketInfo_[_ticketID].numbers.length; i++) {
            if (ticketInfo_[_ticketID].numbers[i] > maxRange) {
                return false;
            }
        }

        ticketInfo_[_ticketID].claimed = true;
        return true;
    }
}
