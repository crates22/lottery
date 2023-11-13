//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "test/unit tests/mocks/LinkToken.sol";

contract HelperConfig is Script{
    

    uint96 public immutable BASE_FEE = 0.25 ether; //this is in LINK; these fees are paid to the LINK node to run the VRFCoordinator (fee denominated in LINK)
    uint96 public immutable GAS_PRICE_LINK = 5e9; //this is in gwei LINK
     
     struct NetworkConfig {
                uint256 entrancefee; 
                uint256 interval;  
                address vrfCoordinator; 
                bytes32 gasLane;
                uint64 subscriptionId;
                uint32 callbackGasLimit;
                address link;
                uint256 deployerKey;

    }

    uint256 public constant DEFAULT_ANVIL_KEY 
        = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    NetworkConfig public activeNetworkConfig;
    constructor(){
        if (block.chainid == 11155111){//block.chainid is one of Solidity's global variables that returns the chain id of the current chain; this if statement is saying that if the chain id is 11155111 (which is the chain id for Sepolia) then we want to run the getSepoliaEthConfig function; if not run on anvil
            activeNetworkConfig = getSepoliaEthConfig();}
        else{
            activeNetworkConfig = getOrCreateAnvilEthConfig();}
     }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory){ //this function is going to return configuration for everything we want out of ETH Sepolia (or any chain) specified in the struct above
            NetworkConfig memory sepoliaConfig = NetworkConfig(
            {entrancefee: 0.01 ether,
            interval: 30, 
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625, 
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c, 
            subscriptionId: 6532, 
            callbackGasLimit: 500000, //500,000 gas
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            deployerKey: vm.envUint("PRIVATE_KEY")});
            return sepoliaConfig;

    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory){
        if (activeNetworkConfig.vrfCoordinator != address(0)){
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(BASE_FEE, GAS_PRICE_LINK);//this line of code is saying that we are deploying a new VRFCoordinatorMock contract with  as the initial answer (see the constructos in the VRFCoordinatorV2Mock contract)
      

        LinkToken link = new LinkToken();//this line of code is saying that we are deploying a new LinkToken contract for anvil
        vm.stopBroadcast();

        return NetworkConfig({
            entrancefee: 0.01 ether, 
            interval: 30, 
            vrfCoordinator: address(vrfCoordinatorMock), 
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c, //gasLane doesn't need to be changed
            subscriptionId: 0, // our script will update this
            callbackGasLimit: 500000, //500,000 gas
            link: address(link),
            deployerKey: DEFAULT_ANVIL_KEY
            });


    }
}