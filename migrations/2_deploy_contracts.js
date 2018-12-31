var Interface = artifacts.require("./Interface.sol");
var Doffler = artifacts.require("./Doffler.sol");

module.exports = function(deployer) {
  deployer.deploy(Interface);
  deployer.link(Interface, Doffler);
  deployer.deploy(Doffler);
};
