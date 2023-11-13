//SPDX License Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {CreateSubsctiption, FundSubscription, AddConsumer} from "script/Interactions.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";


contract InteractionsTest is Test {
event EnteredRaffle(address indexed entrant);

Raffle raffle;
HelperConfig helperConfig;

    uint256 entrancefee; 
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;
    uint256 deployerKey; //= 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    
    address USER = makeAddr("user"); // here we are creating a fake address to use in our tests (https://book.getfoundry.sh/reference/forge-std/make-addr?highlight=makeaddr#makeaddr)
    uint256 public constant USER_BALANCE = 50 ether;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        vm.deal(USER, USER_BALANCE);//this line of code is saying that we are setting up the USER addy with 1 ETH  

        (
            entrancefee, 
            interval,  
            vrfCoordinator, 
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link,
            
         ) = helperConfig.activeNetworkConfig();


    }


    function testSubscriptionIsCreated() public {
        VRFCoordinatorV2Mock vrfMock = VRFCoordinatorV2Mock(vrfCoordinator);
        uint64 createdSubscriptionId = vrfMock.createSubscription();

        // Now check if the subscription has been created
        (, , address owner, ) = vrfMock.getSubscription(createdSubscriptionId);

        // In this mock contract, the owner of the subscription should be the sender of the createSubscription call.
        // The default sender is the address that deployed this contract.
        // If the createSubscription was called by another address, replace address(this) with that address.
        assert(owner == address(this));
}



    function testSubscriptionIsFunded() public {
        //we are going to need to create and fund a subscription (done via our interactions contract)
        VRFCoordinatorV2Mock vrfMock = VRFCoordinatorV2Mock(vrfCoordinator);
        subscriptionId = vrfMock.createSubscription();
        deployerKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;//anvil priv key

        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundSubscription(vrfCoordinator, subscriptionId, link, deployerKey);

        (uint96 balance,,,) = VRFCoordinatorV2Mock(vrfCoordinator).getSubscription(subscriptionId);//this is the function that gets the subscription balance sent to vrfCoordinator
        console.log("Balance is: ", balance);

        assert(balance == 3 ether);
    }

    // function testConsumerIsAdded() public {
    //     VRFCoordinatorV2Mock vrfMock = VRFCoordinatorV2Mock(vrfCoordinator);
    //     subscriptionId = vrfMock.createSubscription();
    //     deployerKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;//anvil priv key

    //     AddConsumer addConsumer = new AddConsumer();
    //     bool success = addConsumer.addConsumer{from: vrfCoordinator}(address (raffle), vrfCoordinator, subscriptionId, deployerKey);
        
    //     require(success, "Adding consumer failed");


    //     bool isConsumerAdded = vrfMock.consumerIsAdded(subscriptionId, address(raffle));
    //     console.log("Consumer is added: ", isConsumerAdded);

    //     assert(isConsumerAdded == true);


    // }
}

