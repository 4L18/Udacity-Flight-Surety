var HDWalletProvider = require("truffle-hdwallet-provider");
var mnemonic = "tribe report come suffer program orbit mobile almost split hurt verify blouse";

module.exports = {
  networks: {
    development: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:7545/", 0, 50);
      },
      network_id: '*',
      //gas: 9999999
    }
  },
  compilers: {
    solc: {
      version: "^0.4.24"
    }
  }
};