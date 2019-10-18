
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`First airline is registered when contract is deployed`, async function () {
    var isRegistered = await config.flightSuretyData.isAuthorized(config.flightSuretyData.address);
    assert.equal(isRegistered, true);
  });
  
  it(`Only existing airline may register a new airline until there are at least four airlines registered`, async function () {
    
    var count = await config.flightSuretyData.getAirlinesCount();
    assert(count < 5);

    // from auth acc
    await config.flightSuretyData.registerAirline.call(config.testAddresses[2], { from: config.flightSuretyData.address});
    var isRegistered1 = await config.flightSuretyData.isRegistered(config.testAddresses[2]);
    assert.equal(isRegistered1, true);

    // from non auth acc
    await config.flightSuretyData.registerAirline.call(config.testAddresses[4], { from: config.testAddresses[3]});
    var isRegistered2 = await config.flightSuretyData.isRegistered(config.testAddresses[4]);
    assert.equal(isRegistered2, false);
  });
  
  it(`Registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airlines`, async function () {
    
    var isRegistered = true;

    for(var i = 3; i < 5; i++) {
        await config.flightSuretyData.registerAirline.call(config.testAddresses[i], { from: config.flightSuretyData.address});
    }
    // 5 cuentas registradas. No hay consenso
    await config.flightSuretyData.registerAirline.call(config.testAddresses[6], { from: config.flightSuretyData.address});
    isRegistered = await config.flightSuretyData.isRegistered(config.testAddresses[6]);
    assert.equal(isRegistered, false);
    
    isRegistered = false;

    for(var i = 0; i <= 5; i++) {
        await config.flightSuretyData.authorizeCaller(config.testAddresses[i]);
        await config.flightSuretyData.voteAirline.call(config.testAddresses[6], { from: config.testAddresses[i]});
    }
    // 5 cuentas votan a favor. Sí hay consenso
    isRegistered = await config.flightSuretyData.isRegistered(config.testAddresses[6]);
    assert.equal(isRegistered, true);
  });
  
  it(`Airline can be registered, but does not participate in contract until it submits funding of 10 ether`, async function () {
    
    await config.flightSuretyData.registerAirline.call(config.testAddresses[7], { from: config.flightSuretyData.address});
    await config.flightSuretyData.fund.call(config.testAddresses[7], 10, { from: config.flightSuretyData.address});
    var funds = await config.flightSuretyData.getAirlineFunds(config.testAddresses[7]);
    console.log(funds);
    assert(funds >= 10, "Less than 10 ether funded");
  });

  it(`Passengers may pay up to 1 ether for purchasing flight insurance`, async function () {
    
    await config.flightSuretyApp.buy.call(config.testAddresses[8], 1);
    var funds = await config.flightSuretyData.getInsuredFunds(config.testAddresses[8], {from: config.flightSuretyData.address});
    assert.equal(funds, 1);
  });

  it(`If flight is delayed due to airline fault, passenger receives credit of 1.5X the amount they paid`, async function () {
    
    var success = await config.flightSuretyApp.withdrawal.call(config.flight, {from: config.testAddresses[8]});
    assert.equal(success, true);
  });

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);

      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {}

    let result = await config.flightSuretyData.isAuthorized.call(newAirline, {from: newAirline}); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });
});
