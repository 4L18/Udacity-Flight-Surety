
var Test = require('../config/testConfig.js');
//var BigNumber = require('bignumber.js');

contract('Oracles', async (accounts) => {

  const TEST_ORACLES_COUNT = 20;
  // Watch contract events
  const STATUS_CODE_UNKNOWN = 0;
  const STATUS_CODE_CHECK_IN_CLOSED = 10;
  const STATUS_CODE_ON_TIME = 20;
  const STATUS_CODE_LATE_AIRLINE = 30;
  const STATUS_CODE_LATE_WEATHER = 40;
  const STATUS_CODE_LATE_TECHNICAL = 50;
  const STATUS_CODE_LATE_OTHER = 60;

  var config;

  before('setup contract', async () => {
    config = await Test.Config(accounts);
  });


  it('can register oracles', async () => {

    let fee = await config.flightSuretyApp.REGISTRATION_FEE.call();

    for(let a=0; a<TEST_ORACLES_COUNT; a++) {      
      await config.flightSuretyApp.registerOracle({ from: accounts[a], value: fee });
      let result = await config.flightSuretyApp.getMyIndexes.call({from: accounts[a]});
      console.log(`Oracle Registered: ${result[0]}, ${result[1]}, ${result[2]}`);
    }
  });

  it('can request flight status', async () => {
    
    // Submit a request for oracles to get status information for a flight
    await config.flightSuretyApp.fetchFlightStatus(config.firstAirline, config.flight, config.timestamp);

    // Since the Index assigned to each test account is opaque by design
    // loop through all the accounts and for each account, all its Indexes
    // and submit a response. The contract will reject a submission if it was
    // not requested so while sub-optimal, it's a good test of that feature
    for(let a=1; a<TEST_ORACLES_COUNT; a++) {

      // Get oracle information
      let oracleIndexes = await config.flightSuretyApp.getMyIndexes.call({ from: accounts[a]});
      
      for(let idx = 0; idx < 3; idx++) {

        try {

          // Submit a response...it will only be accepted if there is an Index match
          await config.flightSuretyApp.submitOracleResponse(oracleIndexes[idx], config.firstAirline, config.flight, config.timestamp, STATUS_CODE_ON_TIME, { from: accounts[a] });
          console.log('\nSuccess', idx, oracleIndexes[idx].toNumber(), config.flight, config.timestamp);
        }
        catch(e) {
          
          // Enable this when debugging
          console.log('\nError', idx, oracleIndexes[idx].toNumber(), config.flight, config.timestamp);
        }
      }
    }
  });
});
