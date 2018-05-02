var CryptArtifacts = artifacts.require("./CryptArtifacts.sol");

module.exports = function(deployer) {
  deployer.deploy(CryptArtifacts);
};