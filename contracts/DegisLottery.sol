// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IDegisLottery.sol";
import "./interfaces/IRandomNumberGenerator.sol";

contract DegisLottery is ReentrancyGuard, IDegisLottery, Ownable {
    using SafeERC20 for IERC20;

    address public injectorAddress;
    address public operatorAddress;
    address public treasuryAddress; // Currently no treasury fee

    uint256 public currentLotteryId; // Total Rounds
    uint256 public currentTicketId; // Total Tickets

    uint256 public maxNumberTicketsPerBuyOrClaim = 10;

    uint256 public maxPriceTicketInDegis = 50 ether;
    uint256 public minPriceTicketInDegis = 0.005 ether;

    uint256 public pendingInjectionNextLottery;

    uint256 public constant MIN_LENGTH_LOTTERY = 4 hours - 5 minutes; // 4 hours
    uint256 public constant MAX_LENGTH_LOTTERY = 7 days + 5 minutes; // 7 days
    uint256 public constant MAX_TREASURY_FEE = 3000; // 30%

    IERC20 public DegisToken;
    IERC20 public USDCToken;
    IRandomNumberGenerator public randomGenerator;

    enum Status {
        Pending,
        Open,
        Close,
        Claimable
    }

    struct Lottery {
        Status status;
        uint256 startTime;
        uint256 endTime;
        uint256 priceTicketInDegis; // 10
        uint256[4] rewardsBreakdown; // 0: 1 matching number // 3: 4 matching numbers
        uint256 treasuryFee; // 500: 5% // 200: 2% // 50: 0.5%
        uint256[4] rewardPerTicketInBracket;
        uint256[4] countWinnersPerBracket;
        uint256 firstTicketId;
        uint256 firstTicketIdNextLottery;
        uint256 amountCollected;
        uint32 finalNumber;
    }

    struct Ticket {
        uint32 number;
        address owner;
    }

    // lotteryId => Lottery Info
    mapping(uint256 => Lottery) private _lotteries;

    // ticketId => Ticket Info
    mapping(uint256 => Ticket) private _tickets;

    // Bracket calculator is used for verifying claims for ticket prizes
    mapping(uint32 => uint32) private _bracketCalculator;

    // lotteryId => (Lucky Number => Total Amount of this number)
    // e.g. in lottery round 3, 10 Tickets are sold with "1234": 3 => (1234 => 10) 
    mapping(uint256 => mapping(uint32 => uint256))
        private _numberTicketsPerLotteryId;

    // Keep track of user ticket ids for a given lotteryId
    // userAddress => (lotteryId => all tickets he bought in this round)
    // e.g. Alice bought [1324, 6545, 5647] in round 3: Alice => 3 => [1324,6545,5647]
    mapping(address => mapping(uint256 => uint256[]))
        private _userTicketIdsPerLotteryId;


    // only user address
    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == operatorAddress, "Not operator");
        _;
    }

    modifier onlyOwnerOrInjector() {
        require(
            (msg.sender == owner()) || (msg.sender == injectorAddress),
            "Not owner or injector"
        );
        _;
    }

    event AdminTokenRecovery(address token, uint256 amount);
    event LotteryClose(
        uint256 indexed lotteryId,
        uint256 firstTicketIdNextLottery
    );
    event LotteryInjection(uint256 indexed lotteryId, uint256 injectedAmount);
    event LotteryOpen(
        uint256 indexed lotteryId,
        uint256 startTime,
        uint256 endTime,
        uint256 priceTicketInDegis,
        uint256 firstTicketId,
        uint256 injectedAmount
    );
    event LotteryNumberDrawn(
        uint256 indexed lotteryId,
        uint256 finalNumber,
        uint256 countWinningTickets
    );
    event NewOperatorAndTreasuryAndInjectorAddresses(
        address operator,
        address treasury,
        address injector
    );
    event NewRandomGenerator(address indexed randomGenerator);
    event TicketsPurchase(
        address indexed buyer,
        uint256 indexed lotteryId,
        uint256 numberTickets
    );
    event TicketsClaim(
        address indexed claimer,
        uint256 amount,
        uint256 indexed lotteryId,
        uint256 numberTickets
    );

    /**
     * @notice Constructor
     * @dev RandomNumberGenerator must be deployed prior to this contract
     * @param _degisTokenAddress: address of the DEGIS token (for buying tickets)
     * @param _usdcTokenAddress: address of the USDC token (for prize distribution)
     * @param _randomGeneratorAddress: address of the RandomGenerator contract used to work with ChainLink VRF
     */
    constructor(
        address _degisTokenAddress,
        address _usdcTokenAddress,
        address _randomGeneratorAddress
    ) {
        DegisToken = IERC20(_degisTokenAddress);
        USDCToken = IERC20(_usdcTokenAddress);
        randomGenerator = IRandomNumberGenerator(_randomGeneratorAddress);

        // Initializes the bracketCalculator, constant numbers
        _bracketCalculator[0] = 1;
        _bracketCalculator[1] = 11;
        _bracketCalculator[2] = 111;
        _bracketCalculator[3] = 1111;
    }

    /**
     * @notice Buy tickets for the current lottery round
     * @param _lotteryId: lottery round
     * @param _ticketNumbers: array of ticket numbers between 1,000,0 and 1,999,9
     * @dev Callable by users
     */
    function buyTickets(uint256 _lotteryId, uint32[] calldata _ticketNumbers)
        external
        override
        notContract
        nonReentrant
    {
        require(_ticketNumbers.length != 0, "no tickets are being bought");
        require(
            _ticketNumbers.length <= maxNumberTicketsPerBuyOrClaim,
            "too many tickets are being bought at one time"
        );
        require(
            _lotteries[_lotteryId].status == Status.Open,
            "sorry, current lottery is not open"
        );
        require(
            block.timestamp < _lotteries[_lotteryId].endTime,
            "sorry, current lottery is over"
        );

        // Calculate number of Degis that the user need to pay
        uint256 amountDegisToTransfer = _calculateTotalPriceForBulkTickets(
            _lotteries[_lotteryId].priceTicketInDegis,
            _ticketNumbers.length
        );

        // Transfer degis tokens to this contract (need approval)
        DegisToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            amountDegisToTransfer
        );

        for (uint256 i = 0; i < _ticketNumbers.length; i++) {
            uint32 currentTicketNumber = _ticketNumbers[i];

            require(
                (currentTicketNumber >= 10000) && (currentTicketNumber <= 19999),
                "ticket number is outside the range"
            );

            // used when drawing the prize 
            _numberTicketsPerLotteryId[_lotteryId][
                1 + (currentTicketNumber % 10)
            ]++;
            _numberTicketsPerLotteryId[_lotteryId][
                11 + (currentTicketNumber % 100)
            ]++;
            _numberTicketsPerLotteryId[_lotteryId][
                111 + (currentTicketNumber % 1000)
            ]++;
            _numberTicketsPerLotteryId[_lotteryId][
                1111 + (currentTicketNumber % 10000)
            ]++;
            
            // Store this ticket number to the user's record
            _userTicketIdsPerLotteryId[msg.sender][_lotteryId].push(
                currentTicketId
            );

            // Store this ticket number to global ticket state
            _tickets[currentTicketId] = Ticket({
                number: currentTicketNumber,
                owner: msg.sender
            });

            // Increase total lottery ticket number
            currentTicketId++;
        }

        emit TicketsPurchase(msg.sender, _lotteryId, _ticketNumbers.length);
    }

    /**
     * @notice Claim a set of winning tickets for a lottery
     * @param _lotteryId: lottery round
     * @param _ticketIds: array of ticket ids
     * @param _brackets: array of brackets for the ticket ids 
                         which level of prize to claim e.g. "match4", "match1"
     * @dev Callable by users only
     */
    function claimTickets(
        uint256 _lotteryId,
        uint256[] calldata _ticketIds,
        uint32[] calldata _brackets
    ) external override notContract nonReentrant {
        require(_ticketIds.length == _brackets.length, 
                "ticketIds and brackets does not have the same length");
        require(_ticketIds.length != 0, "no ticketIds given");
        require(
            _ticketIds.length <= maxNumberTicketsPerBuyOrClaim,
            "too many tickets to claim at one time"
        );
        require(
            _lotteries[_lotteryId].status == Status.Claimable,
            "this round of lottery are not ready for claiming"
        );

        uint256 rewardToTransfer;

        for (uint256 i = 0; i < _ticketIds.length; i++) {
            require(_brackets[i] < 4, 
                    "bracket is out of range, only 4 brackets are available");

            uint256 thisTicketId = _ticketIds[i];

            require(
                _lotteries[_lotteryId].firstTicketIdNextLottery > thisTicketId,
                "ticketId is too large"
            );
            require(
                _lotteries[_lotteryId].firstTicketId <= thisTicketId,
                "ticketId is too small"
            );
            require(
                msg.sender == _tickets[thisTicketId].owner,
                "you are not the owner of this ticket"
            );

            // Update the lottery ticket owner to 0x address (it has been claimed)
            _tickets[thisTicketId].owner = address(0);

            uint256 rewardForTicketId = _calculateRewardsForTicketId(
                _lotteryId,
                thisTicketId,
                _brackets[i]
            );

            // Check user is claiming the correct bracket
            require(rewardForTicketId != 0, "no prize for this bracket");

            // Check the highest level prize
            // If you deserve a higher level prize, you cannot draw another level prize that is lower
            if (_brackets[i] != 3) {
                require(
                    _calculateRewardsForTicketId(
                        _lotteryId,
                        thisTicketId,
                        _brackets[i] + 1
                    ) == 0,
                    "bracket must be higher"
                );
            }

            // Increase the reward to transfer
            rewardToTransfer += rewardForTicketId;
        }

        // Transfer the prize to winner
        USDCToken.safeTransfer(msg.sender, rewardToTransfer);

        emit TicketsClaim(
            msg.sender,
            rewardToTransfer,
            _lotteryId,
            _ticketIds.length
        );
    }

    /**
     * @notice Close a lottery
     * @param _lotteryId: lottery round
     * @dev Callable only by the operator
     */
    function closeLottery(uint256 _lotteryId)
        external
        override
        onlyOperator
        nonReentrant
    {
        require(
            _lotteries[_lotteryId].status == Status.Open,
            "this lottery is not open currently"
        );
        require(
            block.timestamp > _lotteries[_lotteryId].endTime,
            "this lottery has not reached the end time, only can be closed after the end time"
        );

        // Set the upper bound of this round's ticketId
        _lotteries[_lotteryId].firstTicketIdNextLottery = currentTicketId;

        // Request a random number from the generator 
        randomGenerator.getRandomNumber();

        // Update the lottery status to "Close"
        _lotteries[_lotteryId].status = Status.Close;

        emit LotteryClose(_lotteryId, currentTicketId);
    }

    /**
     * @notice Draw the final number, calculate reward in Degis for each group, 
               and make this lottery claimable (need to wait for the random generator)
     * @param _lotteryId: lottery round
     * @param _autoInjection: reinjects funds into next lottery 
     * @dev Callable only by the operator
     */
    function drawFinalNumberAndMakeLotteryClaimable(
        uint256 _lotteryId,
        bool _autoInjection
    ) external override onlyOperator nonReentrant {
        require(
            _lotteries[_lotteryId].status == Status.Close,
            "this lottery has not closed, you should first close it"
        );
        require(
            _lotteryId == randomGenerator.viewLatestLotteryId(),
            "the final lucky numbers have not been drawn"
        );

        // Get the final lucky numbers from randomGenerator
        uint32 finalNumber = randomGenerator.viewRandomResult();

        // Initialize a number to count addresses in all the previous bracket
        // Ensure that a ticket is not counted several times in different brackets 
        uint256 numberAddressesInPreviousBracket;

        // Calculate the prize amount given to winners
        // Currently treasuryFee = 0 => amountToWinners = amountCollected
        uint256 amountToWinners = (
            ((_lotteries[_lotteryId].amountCollected) *
                (10000 - _lotteries[_lotteryId].treasuryFee))
        ) / 10000;

        // Initializes the amount to treasury (currently 0)
        uint256 amountToTreasury;

        // Calculate prizes for each bracket, starting from the highest one
        for (uint32 i = 0; i < 4; i++) {
            uint32 j = 3 - i;
            uint32 transformedWinningNumber = _bracketCalculator[j] +
                (finalNumber % (uint32(10)**(j + 1)));

            _lotteries[_lotteryId].countWinnersPerBracket[j] =
                _numberTicketsPerLotteryId[_lotteryId][
                    transformedWinningNumber
                ] -
                numberAddressesInPreviousBracket;

            // If there are winners for this _bracket 
            if (
                (_numberTicketsPerLotteryId[_lotteryId][
                    transformedWinningNumber
                ] - numberAddressesInPreviousBracket) != 0
            ) {
                // B. If rewards at this bracket are > 0, calculate, else, report the numberAddresses from previous bracket
                if (_lotteries[_lotteryId].rewardsBreakdown[j] != 0) {
                    _lotteries[_lotteryId].rewardPerTicketInBracket[j] =
                        ((_lotteries[_lotteryId].rewardsBreakdown[j] *
                            amountToWinners) /
                            (_numberTicketsPerLotteryId[_lotteryId][
                                transformedWinningNumber
                            ] - numberAddressesInPreviousBracket)) /
                        10000;

                    // Update numberAddressesInPreviousBracket
                    numberAddressesInPreviousBracket = _numberTicketsPerLotteryId[
                        _lotteryId
                    ][transformedWinningNumber];
                }
            // No winners, prize added to the amount to withdraw to treasury 
            } else {
                _lotteries[_lotteryId].rewardPerTicketInBracket[j] = 0;

                amountToTreasury +=
                    (_lotteries[_lotteryId].rewardsBreakdown[j] *
                        amountToWinners) /
                    10000;
            }
        }

        // Update internal statuses for this lottery round
        _lotteries[_lotteryId].finalNumber = finalNumber;
        _lotteries[_lotteryId].status = Status.Claimable;

        // If autoInjection, all unused prize will be rolled to next round
        if (_autoInjection) {
            pendingInjectionNextLottery = amountToTreasury;
            amountToTreasury = 0;
        }

        // Amount to treasury from the treasuryFee part
        amountToTreasury += (_lotteries[_lotteryId].amountCollected -
            amountToWinners);

        // Transfer prize to treasury address
        if (amountToTreasury > 0) {
            USDCToken.safeTransfer(
                treasuryAddress,
                amountToTreasury
            );
        }

        emit LotteryNumberDrawn(
            currentLotteryId,
            finalNumber, // final result for this round
            numberAddressesInPreviousBracket // total winners
        );
    }

    /**
     * @notice Change the random generator contract address
     * @dev The calls to functions are used to verify the new generator implements them properly.
     * It is necessary to wait for the VRF response before starting a round.
     * Callable only by the contract owner
     * @param _randomGeneratorAddress: address of the random generator
     */
    function changeRandomGenerator(address _randomGeneratorAddress)
        external
        onlyOwner
    {
        require(
            _lotteries[currentLotteryId].status == Status.Claimable,
            "current lottery is not claimable"
        );

        // Request a random number from the new generator 
        IRandomNumberGenerator(_randomGeneratorAddress).getRandomNumber();

        // Get the finalNumber based on the randomResult
        IRandomNumberGenerator(_randomGeneratorAddress).viewRandomResult();

        // Set the new address
        randomGenerator = IRandomNumberGenerator(_randomGeneratorAddress);

        emit NewRandomGenerator(_randomGeneratorAddress);
    }

    /**
     * @notice Inject funds
     * @param _lotteryId: lottery round
     * @param _amount: amount to inject 
     * @dev Callable by owner(incentive) or injector address(insurancePool income)
            First transfer USDC and then call this function to record
     */
    function injectFunds(uint256 _lotteryId, uint256 _amount)
        external
        override
        onlyOwnerOrInjector
    {
        require(
            _lotteries[_lotteryId].status == Status.Open,
            "the lottery round is not open, choose the right round"
        );

        uint256 USDC_Balance = USDCToken.balanceOf(address(this));
        require(
            _lotteries[_lotteryId].amountCollected + _amount == USDC_Balance,
            "the amount is wrong"
        );

        _lotteries[_lotteryId].amountCollected += _amount;

        emit LotteryInjection(_lotteryId, _amount);
    }

    /**
     * @notice Start the lottery
     * @dev Callable only by operator
     * @param _endTime: endTime of the lottery (timestamp in s)
     * @param _priceTicketInDegis: price of a ticket in DEGIS
     * @param _rewardsBreakdown: breakdown of rewards per bracket (must sum to 10,000)(100 <=> 1)
     * @param _treasuryFee: treasury fee (10,000 = 100%, 100 = 1%) (set as 0)
     */
    function startLottery(
        uint256 _endTime,
        uint256 _priceTicketInDegis,
        uint256[4] calldata _rewardsBreakdown,
        uint256 _treasuryFee
    ) external override onlyOperator {
        require(
            (currentLotteryId == 0) ||
                (_lotteries[currentLotteryId].status == Status.Claimable),
            "Not time to start lottery"
        );

        require(
            ((_endTime - block.timestamp) > MIN_LENGTH_LOTTERY) &&
                ((_endTime - block.timestamp) < MAX_LENGTH_LOTTERY),
            "the lottery length is outside of range, 4 hours to 7 days"
        );

        require(
            (_priceTicketInDegis >= minPriceTicketInDegis) &&
                (_priceTicketInDegis <= maxPriceTicketInDegis),
            "Outside of limits"
        );

        require(_treasuryFee <= MAX_TREASURY_FEE, "treasury fee is too high");

        require(
            (_rewardsBreakdown[0] +
                _rewardsBreakdown[1] +
                _rewardsBreakdown[2] +
                _rewardsBreakdown[3]) == 10000,
            "total rewards of each bracket must equal 10000"
        );

        currentLotteryId++;

        _lotteries[currentLotteryId] = Lottery({
            status: Status.Open,
            startTime: block.timestamp,
            endTime: _endTime,
            priceTicketInDegis: _priceTicketInDegis,
            rewardsBreakdown: _rewardsBreakdown,
            treasuryFee: _treasuryFee,
            rewardPerTicketInBracket: [
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0)
            ],
            countWinnersPerBracket: [
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0)
            ],
            firstTicketId: currentTicketId,
            firstTicketIdNextLottery: currentTicketId,
            amountCollected: pendingInjectionNextLottery,
            finalNumber: 0
        });

        emit LotteryOpen(
            currentLotteryId,
            block.timestamp,
            _endTime,
            _priceTicketInDegis,
            currentTicketId,
            pendingInjectionNextLottery
        );

        pendingInjectionNextLottery = 0;
    }

    /**
     * @notice Recover wrong tokens sent to the contract, only by the owner
               All tokens except Degis and USDC are wrong tokens
     * @param _tokenAddress: the address of the token to withdraw
     * @param _tokenAmount: token amount to withdraw
     */
    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount)
        external
        onlyOwner
    {
        require(_tokenAddress != address(DegisToken), "Cannot be DEGIS token");

        IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);

        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    /**
     * @notice Set the upper/lower limit of the ticket price
     * @dev Only callable by the owner
     * @param _minPriceTicketInDegis: minimum price of a ticket in Degis
     * @param _maxPriceTicketInDegis: maximum price of a ticket in Degis
     */
    function setMinAndMaxTicketPrice(
        uint256 _minPriceTicketInDegis,
        uint256 _maxPriceTicketInDegis
    ) external onlyOwner {
        require(
            _minPriceTicketInDegis <= _maxPriceTicketInDegis,
            "minPrice must be < maxPrice"
        );

        minPriceTicketInDegis = _minPriceTicketInDegis;
        maxPriceTicketInDegis = _maxPriceTicketInDegis;
    }

    /**
     * @notice Set max number of tickets that a user can buy/claim at one time
     * @dev Only callable by the owner
     */
    function setMaxNumberTicketsPeyBuyOrClaim(uint256 _maxNumber)
        external
        onlyOwner
    {
        require(_maxNumber != 0, "Must be > 0");
        maxNumberTicketsPerBuyOrClaim = _maxNumber;
    }

    /**
     * @notice Set operator, treasury, and injector addresses
     * @dev Only callable by the owner
     * @param _operatorAddress: address of the operator
     * @param _treasuryAddress: address of the treasury
     * @param _injectorAddress: address of the injector
     */
    function setOperatorAndTreasuryAndInjectorAddresses(
        address _operatorAddress,
        address _treasuryAddress,
        address _injectorAddress
    ) external onlyOwner {
        require(_operatorAddress != address(0), "Cannot be zero address");
        require(_treasuryAddress != address(0), "Cannot be zero address");
        require(_injectorAddress != address(0), "Cannot be zero address");

        operatorAddress = _operatorAddress;
        treasuryAddress = _treasuryAddress;
        injectorAddress = _injectorAddress;

        emit NewOperatorAndTreasuryAndInjectorAddresses(
            _operatorAddress,
            _treasuryAddress,
            _injectorAddress
        );
    }

    /**
     * @notice Calculate price of a set of tickets
     * @param _priceTicket price of one ticket (in Degis)
     * @param _numberTickets number of tickets to buy
     */
    function calculateTotalPriceForBulkTickets(
        uint256 _priceTicket,
        uint256 _numberTickets
    ) external pure returns (uint256) {
        require(_numberTickets != 0, "number of tickets must be > 0");

        return _calculateTotalPriceForBulkTickets(_priceTicket, _numberTickets);
    }

    /**
     * @notice View current lottery id
     */
    function viewCurrentLotteryId() external view override returns (uint256) {
        return currentLotteryId;
    }

    /**
     * @notice View lottery information
     * @param _lotteryId: lottery id
     */
    function viewLottery(uint256 _lotteryId)
        external
        view
        returns (Lottery memory)
    {
        return _lotteries[_lotteryId];
    }

    /**
     * @notice View ticker statuses and numbers for an array of ticket ids
     * @param _ticketIds: array of _ticketId
     */
    function viewNumbersAndStatusesForTicketIds(uint256[] calldata _ticketIds)
        external
        view
        returns (uint32[] memory, bool[] memory)
    {
        uint256 length = _ticketIds.length;
        uint32[] memory ticketNumbers = new uint32[](length);
        bool[] memory ticketStatuses = new bool[](length);

        for (uint256 i = 0; i < length; i++) {
            ticketNumbers[i] = _tickets[_ticketIds[i]].number;
            if (_tickets[_ticketIds[i]].owner == address(0)) {
                ticketStatuses[i] = true;
            } else {
                ticketStatuses[i] = false;
            }
        }

        return (ticketNumbers, ticketStatuses);
    }

    /**
     * @notice View rewards for a given ticket, providing a bracket, and lottery id
     * @dev Computations are mostly offchain. This is used to verify a ticket!
     * @param _lotteryId: lottery round
     * @param _ticketId: ticket id
     * @param _bracket: bracket for the ticketId to verify the claim and calculate rewards
     */
    function viewRewardsForTicketId(
        uint256 _lotteryId,
        uint256 _ticketId,
        uint32 _bracket
    ) external view returns (uint256) {
        // Check lottery is in claimable status
        if (_lotteries[_lotteryId].status != Status.Claimable) {
            return 0;
        }

        // Check ticketId is within range
        if (
            (_lotteries[_lotteryId].firstTicketIdNextLottery < _ticketId) &&
            (_lotteries[_lotteryId].firstTicketId >= _ticketId)
        ) {
            return 0;
        }

        return _calculateRewardsForTicketId(_lotteryId, _ticketId, _bracket);
    }

    /**
     * @notice View user ticket ids, numbers, and statuses of user for a given lottery
     * @param _user: user address
     * @param _lotteryId: lottery round
     * @param _cursor: cursor to start where to retrieve the tickets
     * @param _size: the number of tickets to retrieve
     */
     // e.g. Alice, round 10, check her ticket-30 to ticket-35
    function viewUserInfoForLotteryId(
        address _user,
        uint256 _lotteryId,
        uint256 _cursor,
        uint256 _size
    )
        external
        view
        returns (
            uint256[] memory,
            uint32[] memory,
            bool[] memory,
            uint256
        )
    {
        uint256 length = _size;
        uint256 numberTicketsBoughtAtLotteryId = _userTicketIdsPerLotteryId[
            _user
        ][_lotteryId].length;

        if (length > (numberTicketsBoughtAtLotteryId - _cursor)) {
            length = numberTicketsBoughtAtLotteryId - _cursor;
        }

        uint256[] memory lotteryTicketIds = new uint256[](length);
        uint32[] memory ticketNumbers = new uint32[](length);
        bool[] memory ticketStatuses = new bool[](length);

        for (uint256 i = 0; i < length; i++) {
            lotteryTicketIds[i] = _userTicketIdsPerLotteryId[_user][_lotteryId][
                i + _cursor
            ];
            ticketNumbers[i] = _tickets[lotteryTicketIds[i]].number;

            // True = ticket claimed
            if (_tickets[lotteryTicketIds[i]].owner == address(0)) {
                ticketStatuses[i] = true;
            } else {
                // ticket not claimed (includes the ones that cannot be claimed)
                ticketStatuses[i] = false;
            }
        }

        return (
            lotteryTicketIds,
            ticketNumbers,
            ticketStatuses,
            _cursor + length
        );
    }

    /**
     * @notice Calculate rewards for a given ticket, in given round and given bracket
     * @param _lotteryId: lottery round
     * @param _ticketId: ticket id
     * @param _bracket: bracket for the ticketId to verify the claim and calculate rewards
     */
    function _calculateRewardsForTicketId(
        uint256 _lotteryId,
        uint256 _ticketId,
        uint32 _bracket
    ) internal view returns (uint256) {
        // Retrieve the user number combination from the ticketId
        uint32 userNumber = _tickets[_ticketId].number;

        // Retrieve the winning number combination 
        uint32 winningTicketNumber = _lotteries[_lotteryId].finalNumber;

        // Apply transformation to verify the claim provided by the user is true
        uint32 transformedWinningNumber = _bracketCalculator[_bracket] +
            (winningTicketNumber % (uint32(10)**(_bracket + 1)));

        uint32 transformedUserNumber = _bracketCalculator[_bracket] +
            (userNumber % (uint32(10)**(_bracket + 1)));

        // Confirm that the two transformed numbers are the same
        if (transformedWinningNumber == transformedUserNumber) {
            return _lotteries[_lotteryId].rewardPerTicketInBracket[_bracket];
        } else {
            return 0;
        }
    }

    /**
     * @notice Calculate final price for bulk of tickets
     * @param _priceTicket: price of a ticket
     * @param _numberTickets: number of tickets purchased
     */
    function _calculateTotalPriceForBulkTickets(
        uint256 _priceTicket,
        uint256 _numberTickets
    ) internal pure returns (uint256) {
        return _priceTicket * _numberTickets;
    }

    /**
     * @notice Check if an address is a contract
     */
    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
}
