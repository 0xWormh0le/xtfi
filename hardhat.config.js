require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-web3");
require("@nomiclabs/hardhat-etherscan");
require("solidity-coverage");
require('hardhat-deploy');
require('dotenv').config()

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

task("balance", "Prints an account's ETH balance")
  .addParam("account", "The account's address")
  .setAction(async args => {
    const balance = await web3.eth.getBalance(args.account);

    console.log(web3.utils.fromWei(balance, "ether"), "ETH");
  });

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

 module.exports = {
  solidity: "0.8.4",
  namedAccounts: {
    deployer: 0,
  },
  networks: {
    kovan: {
      url: `https://eth-kovan.alchemyapi.io/v2/${process.env.KOVAN_KEY}`,
      accounts: {
        mnemonic: process.env.MNEMONIC
      }
    }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  }
};
