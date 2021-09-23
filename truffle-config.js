const Web3 = require("web3");
const HDWalletProvider = require("@truffle/hdwallet-provider");
const dotenv = require('dotenv')
const result = dotenv.config();
if (result.error) {
  throw result.error;
}
console.log(result.parsed);
var mnemonic = process.env.mnemonic;
var infuraKey = process.env.infuraKey;

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
  
    rinkeby: {
      provider: () => new HDWalletProvider(mnemonic, 'wss://rinkeby.infura.io/ws/v3/' + infuraKey),
      network_id: 4,       // Rinkeby's id
      gas: 5500000,        // Ropsten has a lower block limit than mainnet
      confirmations: 2,    // # of confs to wait between deployments. (default: 0)
      networkCheckTimeout: 1000000000,
      timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
      skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    }
  },

  compilers: {
    solc: {
      version: '0.8.5',
      settings: {
        optimizer: {
          enabled: true, // Default: false
          runs: 1000, // Default: 200
        },
      },
      evmVersion: "byzantium"
    },
  },
};