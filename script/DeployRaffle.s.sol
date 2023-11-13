//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;


import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateSubsctiption, FundSubscription, AddConsumer} from "script/Interactions.s.sol";

contract DeployRaffle is Script{
    function run() external returns (Raffle, HelperConfig){ //this line of code is saying that the run function will return a Raffle contract
        HelperConfig helperConfig = new HelperConfig();
        (uint256 entrancefee, 
        uint256 interval,  
        address vrfCoordinator, 
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        address link,
        uint256 deployerKey) = helperConfig.activeNetworkConfig();
        
        if(subscriptionId == 0) {
            //we are going to need to create a subscription (done via our interactions contract)
            CreateSubsctiption createSubsctiption = new CreateSubsctiption();
            subscriptionId = createSubsctiption.createSubscription(vrfCoordinator, deployerKey);
        }

            //we are going to need to fund the subscription (done via our interactions contract)
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(vrfCoordinator, subscriptionId, link, deployerKey);


        vm.startBroadcast();
        Raffle raffle = new Raffle(
            entrancefee, 
            interval, 
            vrfCoordinator,
            gasLane, 
            subscriptionId, 
            callbackGasLimit);//we add the input parameters specified in our constructor in Rallfe.sol to the parentheses
        vm.stopBroadcast();

        //once the subscription is deployed we then add our consumer (same as if you use the front end)
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address (raffle), vrfCoordinator, subscriptionId, deployerKey);
        
        return (raffle, helperConfig);
    
    }
}