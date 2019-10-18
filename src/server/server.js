import "regenerator-runtime/runtime";
import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';


let config;
let web3;
let flightSuretyApp;
let accounts;
let defaultAccount;
let fee;
let oracles;

async function setup() {
  config = Config['localhost'];
  web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
  flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
  accounts = await web3.eth.getAccounts();
  defaultAccount = accounts[0];
  fee = await flightSuretyApp.methods.REGISTRATION_FEE().call();
  oracles = new Array();
  registerOracles();
}

async function registerOracles() {
    
    for(let i = 0; i < accounts.length; i++) {
      await flightSuretyApp.methods.registerOracle().send({ from: accounts[i], value: fee, gas: 3000000 });
      console.log(accounts[i]);
    }
}

setup();

flightSuretyApp.events.OracleRequest({
        fromBlock: 0
    }, async function (error, event) {
      if(!error) {
        console.log(event); 
        
        for(let acc = 0; acc < accounts.length; acc++) {
            
            let oracleIndexes = await flightSuretyApp.methods.getMyIndexes().call({ from: accounts[acc]});
            
            for(let i = 0; i < oracleIndexes.length; i++) {
                if(oracleIndexes[i] == event.returnValues.index) {
                    await flightSuretyApp.methods.submitOracleResponse(event.returnValues.index, event.returnValues.airline, event.returnValues.flight, event.returnValues.timestamp, 20).call({ from: accounts[acc] });              
                }
            }
        }
    } else {
        console.log(err);
    }
});

flightSuretyApp.events.FlightStatusUpdated({
        fromBlock: 0
    }, async function (error, event) {
        console.log('algo');
      if(!error) {
        console.log('\n FSU EVENT:\n' + event); 
    } else {
        console.log(err);
    }
});

const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

export default app;