//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "test/unit tests/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";


//this script is used to create a subscription, fund a subscription, and add a consumer which will be called by the DeployRaffle script (line 21 'if' statement and below)
contract CreateSubsctiption is Script {
    
    function createSubscriptionUsingConfig() public returns (uint64){
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , , , ,uint256 deployerKey) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(
        address vrfCoordinator, 
        uint256 deployerKey) 
    public returns (uint64){//this creates the subscription depending on the vrfCoordinator addy
        console.log("Creating subscription on ChainID: ", block.chainid);
        
        vm.startBroadcast(deployerKey);

        uint64 subID = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();//this is the function that creates the subscription

        vm.stopBroadcast();

        console.log("Your sub ID is: ", subID);
        console.log("Please update subscriptionID in HelperConfig.s.sol");
        return subID;

    
    } 
    
    
    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}


contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (, ,  address vrfCoordinator, ,uint64 subscriptionId, ,address link, uint256 deployerKey) = helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinator, subscriptionId, link, deployerKey);

    }

    function fundSubscription (
        address vrfCoordinator, 
        uint64 subID, 
        address link, 
        uint256 deployerKey) public {
            console.log("funding subscription: ", subID);
            console.log("Using vrfCoordinator: ", vrfCoordinator);
            console.log("On ChainID: ", block.chainid);

        if (block.chainid == 31337){//anvil chainID
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
            subID, 
            FUND_AMOUNT);//this line of code is saying that we are funding the subscription with 3 LINK
            vm.stopBroadcast();
        }
        
        else { 
            console.log(LinkToken(link).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(link).balanceOf(address(this)));
            console.log(address(this));

            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subID));
            vm.stopBroadcast();
        }
}


    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    
    function addConsumer(
        address raffle, 
        address vrfCoordinator, 
        uint64 subscriptionId, 
                        uint256 deployerKey) 
    public {
        console.log("Adding consumer to raffle: ", raffle);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);
        
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subscriptionId, raffle);//this line of code is saying that we are adding the raffle contract as a consumer to the VRFCoordinatorMock contract
        vm.stopBroadcast();
    }
    
    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        
        (, , address vrfCoordinator, , , uint64 subscriptionId, ,uint256 deployerKey) = helperConfig.activeNetworkConfig();
        addConsumer(raffle, vrfCoordinator, subscriptionId, deployerKey);
    }
    
    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);  //this is saying that we want to get the most recent deployment of the Raffle contract
    
    addConsumerUsingConfig(raffle);
    
    
    }
}