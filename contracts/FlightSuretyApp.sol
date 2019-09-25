pragma solidity ^0.4.24;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;
    bool private operational;
    FlightSuretyData flightSuretyData;
    mapping(address => bytes32) private insuredPassengers;

    struct Flight {
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }
    mapping(bytes32 => Flight) private flights;
    uint private flightsCount = 0;

    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_CHECK_IN_CLOSEDE = 10;
    uint8 private constant STATUS_CODE_ON_TIME = 20;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 30;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 40;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 50;
    uint8 private constant STATUS_CODE_LATE_OTHER = 60;


    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    
    event FlightRegistered(bytes32 flightNumber);
    event SuretyBought(address, bytes32);
    event SuretyWithdrawal(address, bytes32);
    event FlightStatusUpdated(bytes32, uint8);

    /********************************************************************************************/
    /*                                       CONSTRUCTOR & FALLBACK                             */
    /********************************************************************************************/

    constructor() 
    public 
    {
        contractOwner = msg.sender;
        operational = true;
        flightsCount = 0;
    }


    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    modifier requireIsOperational() 
    {
         // Modify to call data contract's status
        require(true, "Contract is currently not operational");  
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier onlyExternalOwnedAccounts(address origin, address sender)
    {
        require(origin == sender, "Contracts are not allowed to call this function");
        _;
    }


    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational()
    public
    view
    returns(bool) 
    {
        return operational;
    }

    function setOperatingStatus(bool mode)
    external
    requireContractOwner
    {
        require(mode != operational, "New mode must be different from existing mode.");
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function registerAirline(address addr)
    returns(bool)
    {
        bool success = flightSuretyData.registerAirline(addr);
        return (success);
    }

    function fund()
    payable
    requireIsOperational
    onlyExternalOwnedAccounts(tx.origin, msg.sender)
    returns(bool)
    {
        bool success = flightSuretyData.fund(msg.sender, msg.value);
        return (success);
    }

    function buy(bytes32 flightNumber)
    payable
    requireIsOperational
    onlyExternalOwnedAccounts(tx.origin, msg.sender)
    returns(bool)
    {
        require(flights[flightNumber].statusCode == 0, "Flight not registered or check-in is already closed");
        require(0 < msg.value && msg.value <= 10**18);

        bool success = flightSuretyData.buy(msg.sender, msg.value);
        insuredPassengers[msg.sender] = flightNumber;
        emit SuretyBought(msg.sender, flightNumber);
        return success;        
    }

    function withdrawal(bytes32 flightNumber)
    requireIsOperational
    onlyExternalOwnedAccounts(tx.origin, msg.sender)
    returns(bool)
    {
        require(flights[flightNumber].statusCode == 30);
        require(insuredPassengers[msg.sender] == flightNumber);

        bool success = flightSuretyData.creditInsurees(msg.sender);
        insuredPassengers[msg.sender] = 0;        
        emit SuretyWithdrawal(msg.sender, flightNumber);
        require(success);
    }

    function registerFlight(bytes32 flightNumber, address airlineAddr, uint256 timestamp)
    external
    requireIsOperational
    onlyExternalOwnedAccounts(tx.origin, msg.sender)
    {
        flightsCount = flightsCount.add(1);
        flights[flightNumber] = Flight({
                statusCode: 0,
                updatedTimestamp: timestamp,
                airline: airlineAddr
            });
        emit FlightRegistered(flightNumber);
    }
    
    function processFlightStatus(address airline, bytes32 flight, uint256 timestamp, uint8 statusCode)
    internal
    requireIsOperational
    onlyExternalOwnedAccounts(tx.origin, msg.sender)
    {
        require(flightSuretyData.isCallerAuthorized(msg.sender));
        flights[flight].statusCode = statusCode;
        flights[flight].updatedTimestamp = timestamp;
        emit FlightStatusUpdated(flight, statusCode);
    }

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            address airline,
                            bytes32 flight,
                            uint256 timestamp                            
                        )
                        external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    } 


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, bytes32 flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, bytes32 flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, bytes32 flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            bytes32 flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            bytes32 flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   
