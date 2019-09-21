pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;
    bool private operational = true;
    mapping(address => uint) private contractFunds;
    uint private raisedFunds= 0;
    uint constant M = 5;
    mapping(address => bool) private authorizedCallers;

    struct Airline {
        uint id;
        AirlineStatus status;
        mapping(address => bool) votedBy;
        uint votes;
    }
    enum AirlineStatus {
        Registered,
        Authorized
    }
    mapping(address => Airline) private airlines;
    uint private airlinesCount = 0;
    


    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    
    event CallerAuthorized(address caller);
    event AirlineAdded(address airline);
    event AirlineRegistered(address airline);
    event RaisedFunds(uint funds);

    /********************************************************************************************/
    /*                                       CONSTRUCTOR & FALLBACK                                  */
    /********************************************************************************************/

    constructor() public payable
    {
        contractOwner = msg.sender;
        operational = true;
        airlinesCount = 0;
        //flightCount = 0;
        //insuranceCount = 0;

        authorizedCallers[address(this)] = true;
        emit CallerAuthorized(address(this));
        authorizedCallers[contractOwner] = true;
        emit CallerAuthorized(contractOwner);

        airlinesCount = airlinesCount.add(1);
        airlines[contractOwner] = Airline({
                id: airlinesCount,
                status: AirlineStatus.Authorized,
                votes: 0
            });
        emit AirlineRegistered(contractOwner);
        
        address(this).transfer(msg.value);
    }

    function() external payable 
    {
        
    }
    
    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  
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

    modifier onlyAuthorizedCallers(address _address)
    {
        require(msg.sender == _address, "The caller can not invoke this operation.");
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
    onlyAuthorizedCallers(msg.sender)
    {
        require(mode != operational, "New mode must be different from existing mode");
        operational = mode;
    }

    function isCallerAuthorized()
    public
    view
    returns(bool)
    {
        return authorizedCallers[msg.sender];
    }
    
    function authorizeCaller(address addr)
    external
    requireIsOperational
    {
        //require(!isCallerAuthorized());
        authorizedCallers[addr] = true;
    }

    function unauthorizeCaller(address addr)
    external
    requireIsOperational
    {
        require(isCallerAuthorized());
        authorizedCallers[addr] = false;
    }


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/
  
    function registerAirline(address addr)
    external
    requireIsOperational
    {
        require(addr != msg.sender);
        require(airlines[msg.sender].status == AirlineStatus.Registered
            || airlines[msg.sender].status == AirlineStatus.Authorized);

        airlinesCount = airlinesCount.add(1);
        emit AirlineAdded(addr);

        if (airlinesCount < M) {
        
            airlines[addr].status = AirlineStatus.Authorized;
            emit AirlineRegistered(addr);

        } else {

            bool duplicate = airlines[addr].votedBy[msg.sender];
            require(!duplicate, "Caller has already called this function.");

            require(airlines[addr].votes > airlinesCount/2, "There is not consensus yet");
            
            airlines[addr].status = AirlineStatus.Authorized;
            emit AirlineRegistered(addr);
        }
    }

    function fund()
    external
    payable
    requireIsOperational
    {
        contractFunds[msg.sender] += msg.value;
        raisedFunds += msg.value;
        emit RaisedFunds(raisedFunds);
        
        require(airlines[msg.sender].status == AirlineStatus.Registered);
        require(contractFunds[msg.sender] >= 10 ether);

        airlines[msg.sender].status = AirlineStatus.Authorized;
        authorizedCallers[msg.sender] = true;
        emit CallerAuthorized(msg.sender);
    }

    /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (                             
                            )
                            external
                            payable
    {

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                )
                                external
                                pure
    {
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            external
                            pure
    {
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }
}

