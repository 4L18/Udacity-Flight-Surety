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
    requireIsOperational
    {
        require(!isCallerAuthorized(addr));
        authorizedCallers[addr] = true;
    }

    function unauthorizeCaller(address addr)
    external
    requireIsOperational
    {
        require(isCallerAuthorized(addr));
        authorizedCallers[addr] = false;
    }


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/
  
    function registerAirline(address addr)
    external
    requireIsOperational
    returns(bool)
    {
        require(addr != msg.sender);
        require(airlines[msg.sender].status == AirlineStatus.Registered
            || airlines[msg.sender].status == AirlineStatus.Authorized);
        
        bool success = false;

        if (airlinesCount < M) {
        
            airlines[addr].status = AirlineStatus.Authorized;
            airlinesCount = airlinesCount.add(1);
            emit AirlineRegistered(addr);
            success = true;

        } else {

            bool duplicate = airlines[addr].votedBy[msg.sender];
            require(!duplicate, "Caller has already called this function.");

            require(airlines[addr].votes > airlinesCount/2, "There is not consensus yet");
            
            airlines[addr].status = AirlineStatus.Authorized;
            airlinesCount = airlinesCount.add(1);
            emit AirlineRegistered(addr);
            success = true;
        }

        return success;
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
        
        require(airlines[fundsBy].status == AirlineStatus.Registered);
        require(fundsRegister[fundsBy] >= 10 ether);

        airlines[fundsBy].status = AirlineStatus.Authorized;
        authorizedCallers[fundsBy] = true;
        emit CallerAuthorized(fundsBy);

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

    function creditInsurees(address insured)
    external
    requireIsOperational
    onlyAuthorizedCallers(msg.sender)
    returns(bool)
    {
        bool success = false;
        uint credit = fundsRegister[insured];
        credit = credit.mul(15);
        credit = credit.div(10);
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