import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';

let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let accounts = web3.eth.getAccounts();
    
async function setup() {
  try {
    web3.eth.defaultAccount = accounts[0];
    await flightSuretyData.methods.authorizeCaller(config.appAddress).send({from: accounts[0]});

  } catch(e) {
    console.log(e);
  }
}

// Register all the oracles using the registerOracle
// function from flightSuretyApp
async function registerOracle(address) {
  try {
    await flightSuretyApp.methods.registerOracle().send({from: accounts[address], value: FlightSuretyApp.REGISTRATION_FEE});
  } catch(e) {
    console.log(e)
  }
}

// Implement the flightSuretyApp.events.OracleRequest
// Inside of it execute the submitOracleResponse from flightSuretyApp
flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, function (error, event) {
    if (error) console.log(error)
    console.log(event)
});

const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

export default app;