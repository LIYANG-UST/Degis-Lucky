const Web3 = require("web3");
const HDWalletProvider = require("@truffle/hdwallet-provider");
require('dotenv').config()
const protocol = "https";
const ip = "api.avax-test.network";
const port = 9650;
const provider = new Web3.providers.HttpProvider(
  `${protocol}://${ip}/ext/bc/C/rpc`
);
const mnemonic = process.env.MNEMONIC

module.exports = {
  networks: {
    fuji: {
      provider: () => {
        return new HDWalletProvider({
          mnemonic: {
            phrase: mnemonic
          },
          numberOfAddresses: 1,
          shareNonce: true,
          providerOrUrl: provider,
        });
      },
      network_id: "*",
      timeoutBlocks: 50000,
    },
    development: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 7545,            // Standard Ethereum port (default: none)
      network_id: "*",       // Any network (default: none)
    },  
  },

  compilers: {
    solc: {
      version: '^0.8.0',
      optimizer: { enabled: true, runs: 200 }
    },
  },
};