pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;
    bool private operational = true;
    mapping(address => uint) private fundsRegister;
    uint private raisedFunds= 0;
    mapping(address => bool) private authorizedCallers;


    struct Airline {
        uint id;
        AirlineStatus status;
        mapping(address => bool) votedBy;
        uint votes;
    }
    enum AirlineStatus {
        Voted,
        Registered,
        Authorized
    }
    mapping(address => Airline) private airlines;
    uint private airlinesCount = 0;


    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    
    event CallerHasBeenAuthorized(address caller);
    event AirlineHasBeenVoted(address airline);
    event AirlineRegistered(address airline);
    event RaisedFunds(uint funds);
    event PassengerWithdrawal(address insured);


    /********************************************************************************************/
    /*                                       CONSTRUCTOR & FALLBACK                             */
    /********************************************************************************************/

    constructor() public payable
    {
        contractOwner = msg.sender;
        operational = true;
        airlinesCount = 0;

        this.authorizeCaller(address(this));
        emit CallerHasBeenAuthorized(address(this));
        this.authorizeCaller(contractOwner);
        emit CallerHasBeenAuthorized(contractOwner);

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

    function isCallerAuthorized(address sender)
    public
    view
    returns(bool)
    {
        return authorizedCallers[sender];
    }
    
    function authorizeCaller(address addr)
    external
    onlyAuthorizedCallers(msg.sender)
    requireIsOperational
    {
        require(!isCallerAuthorized(addr));
        authorizedCallers[addr] = true;
        emit CallerHasBeenAuthorized(addr);
    }

    function unauthorizeCaller(address addr)
    external
    requireIsOperational
    {
        require(isCallerAuthorized(addr));
        authorizedCallers[addr] = false;
    }

    function getAirlineStatus(address airline)
    external
    view
    returns(AirlineStatus)
    {
        return airlines[airline].status;
    }

    function getAirlinesCount()
    external
    view
    returns(uint)
    {
        return airlinesCount;
    }

    function getAirlineFunds(address airline)
    external
    view
    returns(uint)
    {
        return fundsRegister[airline];
    }

    function getInsuredFunds(address insured)
    external
    view
    returns(uint)
    {
        return fundsRegister[insured];
    }


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/
  
    function registerAirline(address addr)
    external
    requireIsOperational
    returns(AirlineStatus)
    {
        airlines[addr].status = AirlineStatus.Registered;
        airlinesCount = airlinesCount.add(1);
        emit AirlineRegistered(addr);
        return airlines[addr].status;
    }

    function voteAirline(address addr)
    external
    requireIsOperational
    returns(AirlineStatus)
    {
        bool duplicate = airlines[addr].votedBy[msg.sender];
        require(!duplicate, "Caller has already voted this airline.");

        airlines[addr].votedBy[msg.sender] = true;
        airlines[addr].votes.add(1);
        airlines[addr].status = AirlineStatus.Voted;
        emit AirlineHasBeenVoted(addr);

        require(airlines[addr].votes > airlinesCount.div(2), "There is not consensus yet");
        this.registerAirline(addr);
        
        return airlines[addr].status;
    }

    function fund(address fundsBy, uint amount)
    external
    payable
    requireIsOperational
    onlyAuthorizedCallers(msg.sender)
    returns(bool)
    {
        bool success = false;

        uint total = fundsRegister[fundsBy].add(amount);
        fundsRegister[fundsBy] = total;
        raisedFunds.add(amount);
        emit RaisedFunds(raisedFunds);

        success = true;
        return success;
    }


    function buy(address buyer, uint amount)
    external
    payable
    requireIsOperational
    onlyAuthorizedCallers(msg.sender)
    returns(bool)
    {
        bool success = false;
        uint total = fundsRegister[buyer].add(amount);
        fundsRegister[buyer] = total;
        raisedFunds.add(amount);
        emit RaisedFunds(raisedFunds);
        success = true;
        return success;
    }

    function creditInsurees(address insured, uint credit)
    external
    requireIsOperational
    onlyAuthorizedCallers(msg.sender)
    returns(bool)
    {
        bool success = false;
        fundsRegister[insured] = 0;
        raisedFunds.sub(credit);
        pay(insured, credit);
        emit PassengerWithdrawal(insured);
        success = true;
        return success;
    }
    
    function pay(address insured, uint credit)
    internal
    requireIsOperational
    onlyAuthorizedCallers(msg.sender)
    {
        insured.transfer(credit);
    }
}