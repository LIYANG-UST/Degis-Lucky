// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "./LibOwnable.sol";

contract RandomNumber is ChainlinkClient, LibOwnable {
    using Chainlink for Chainlink.Request;

    bytes32 private jobId;
    address private oracleAddress;

    string private url;
    string private path;

    enum RequestStatus {
        INIT,
        SENT,
        COMPLETED
    }

    struct Info {
        uint256 randomNumber;
        uint256 epochId;
        bool isUsed;
        RequestStatus requestStatus;
    }

    mapping(uint256 => Info) data;
    mapping(bytes32 => uint256) requests;

    /**
     * @notice Deploy the contract with a specified address for the LINK
     * and Oracle contract addresses
     * @dev Sets the storage for the specified addresses
     * @param _link The address of the LINK token contract
     */
    constructor(
        address _link,
        address _oracleAddress,
        string memory _url,
        string memory _path
    ) {
        bytes32 _jobId = "1755320a535b4fcd9aa873ca616204d6";
        // oracleAddress = 0x7D9398979267a6E050FbFDFff953Fc612A5aD4C9;
        // url = "http://api.m.taobao.com/rest/api3.do?api=mtop.common.getTimestamp"
        jobId = _jobId;
        oracleAddress = _oracleAddress;
        url = _url;
        path = _path;
        operator = msg.sender;
        setChainlinkToken(_link);
    }

    function changeJobId(bytes32 _jobId) public onlyOwner {
        jobId = _jobId;
    }

    function changeOrcaleAddress(address _oracleAddress) public onlyOwner {
        oracleAddress = _oracleAddress;
    }

    function changeUrl(string memory _url) public onlyOwner {
        url = _url;
    }

    function changePath(string memory _path) public onlyOwner {
        path = _path;
    }

    function changeOperator(address op) external onlyOwner {
        require(op != address(0), "INVALID_ADDRESS");
        operator = op;
    }

    function getJobId() public view returns (bytes32) {
        return jobId;
    }

    function getOrcaleAddress() public view returns (address) {
        return oracleAddress;
    }

    function getUrl() public view returns (string memory) {
        return url;
    }

    function getPath() public view returns (string memory) {
        return path;
    }

    function getOperatorAddress() public view returns (address) {
        return operator;
    }

    function getRandomNumber(uint256 epochId)
        public
        view
        returns (uint256 randomNumber, bool requestStatus)
    {
        if (data[epochId].requestStatus != RequestStatus.COMPLETED) {
            requestStatus = false;
        } else {
            requestStatus = true;
        }

        randomNumber = data[epochId].randomNumber;
    }

    struct RequestInfo {
        address oracle;
        bytes32 jobId;
        uint256 payment;
        string url;
        string path;
        int256 time;
        bytes32 requestId;
    }

    /** @notice generate the random number
     *  @param _epochId The epoch Id
     */
    function genRandomNumber(uint256 _epochId) public onlyOwner {
        if (data[_epochId].isUsed == false) {
            data[_epochId].isUsed = true;
            data[_epochId].requestStatus = RequestStatus.INIT;
        }
        if (data[_epochId].requestStatus == RequestStatus.INIT) {
            RequestInfo memory ris;
            ris.oracle = oracleAddress;
            ris.jobId = jobId;
            ris.payment = 1e17;
            ris.url = url;
            ris.path = path;
            ris.time = 1;
            ris.requestId = createRequestTo(
                ris.oracle,
                ris.jobId,
                ris.payment,
                ris.url,
                ris.path,
                ris.time
            );

            requests[ris.requestId] = _epochId;
            data[_epochId].requestStatus = RequestStatus.SENT;
        }
    }

    /**
     * @notice Creates a request to the specified Oracle contract address
     * @dev This function ignores the stored Oracle contract address and
     * will instead send the request to the address specified
     * @param _oracle The Oracle contract address to send the request to
     * @param _jobId The bytes32 JobID to be executed
     * @param _url The URL to fetch data from
     * @param _path The dot-delimited path to parse of the response
     * @param _times The number to multiply the result by
     */
    function createRequestTo(
        address _oracle,
        bytes32 _jobId,
        uint256 _payment,
        string memory _url,
        string memory _path,
        int256 _times
    ) private onlyOwner returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(
            _jobId,
            address(this),
            this.fulfill.selector
        );
        req.add("url", _url);
        req.add("path", _path);
        req.addInt("times", _times);
        requestId = sendChainlinkRequestTo(_oracle, req, _payment);
    }

    /**
     * @notice The fulfill method from requests created by this contract
     * @dev The recordChainlinkFulfillment protects this function from being called
     * by anyone other than the oracle address that the request was sent to
     * @param _requestId The ID that was generated for the request
     * @param _data The answer provided by the oracle
     */
    function fulfill(bytes32 _requestId, uint256 _data)
        public
        recordChainlinkFulfillment(_requestId)
    {
        data[requests[_requestId]].requestStatus = RequestStatus.COMPLETED;
        data[requests[_requestId]].randomNumber = _data;
    }

    /**
     * @notice Returns the address of the LINK token
     * @dev This is the public implementation for chainlinkTokenAddress, which is
     * an internal method of the ChainlinkClient contract
     */
    function getChainlinkToken() public view returns (address) {
        return chainlinkTokenAddress();
    }

    /**
     * @notice finish the LINK withdraw process
     * @param _amount: the amount he withdraw
     */
    function withdrawLink(uint256 _amount) public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(msg.sender, _amount), "Unable to transfer");
    }

    /**
     * @notice view the LINK balances
     */
    function getLinkBalance() public view onlyOwner returns (uint256) {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        return link.balanceOf(address(this));
    }

    /**
     * @notice Call this method if no response is received within 5 minutes
     * @param _requestId The ID that was generated for the request to cancel
     * @param _payment The payment specified for the request to cancel
     * @param _callbackFunctionId The bytes4 callback function ID specified for
     * the request to cancel
     * @param _expiration The expiration generated for the request to cancel
     */
    function cancelRequest(
        bytes32 _requestId,
        uint256 _payment,
        bytes4 _callbackFunctionId,
        uint256 _expiration
    ) public onlyOwner {
        cancelChainlinkRequest(
            _requestId,
            _payment,
            _callbackFunctionId,
            _expiration
        );
    }
}
