//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is StdCheats, Test {

    /*Events*/
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

    function testRaffleInitializesInOpenState() public view { 
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);//this assert statement is saying that the raffle state should be OPEN
    }
    

    //////////////////////////////
    // enterRaffle testing     //
    ////////////////////////////

    function testRaffleRevertWhenYouDontPayEnough() public {
        //Arrange
        vm.prank(USER);

        //Act/Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughETHSent.selector);//this line of code is saying that we expect the revert to be caused by the Raffle__NotEnoughETHSent error
        raffle.enterRaffle{value: 0 ether}();

    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(USER);
        raffle.enterRaffle{value: entrancefee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == USER);
    }

    //testing events (here we're testing line 109 in Raffle.sol)
    function testEmitsEventsOnEntrance() public {
        vm.prank(USER);
        vm.expectEmit(true, false, false, false, address(raffle));
        
        emit EnteredRaffle(USER);//this is the emit we are expecting 
        raffle.enterRaffle{value: entrancefee}();//we perform the call to the enterRaffle function in Raffle.sol, that should emit this event (a user entering the raffle)
    }

    //testing the revert when the raffle is not open (calculating a winner)
    function testCantEnterWhenRaflleIsCalculating() public{
        vm.prank(USER);
        raffle.enterRaffle{value: entrancefee}();

        //these lines of code are needed in order to put us in a 'CALUCLATING_WINNER' state
        vm.warp(block.timestamp + interval +1);//vm.warp which sets the block.teimstamp
        vm.roll(block.number + 1);//vm.roll sets the block number
        raffle.performUpkeep("");


        vm.expectRevert(Raffle.Raffle__NotOpen.selector);//this line of code is saying that we expect the revert to be caused by the Raffle__NotOpen error
        vm.prank(USER);
        raffle.enterRaffle{value: entrancefee}();
    }
    


    //////////////////////////
    // checkUpkeep testing  //
    //////////////////////////

    function testCheckUpKeepReturnsFalseIfithasNoBalance() public {
        //Arrange
        vm.warp(block.timestamp + interval +1);//vm.warp which sets the block.teimstamp
        vm.roll(block.number + 1);//vm.roll sets the block number

        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assert(!upkeepNeeded);//this is saying "assert not false" which is true
    }

     function testCheckUpKeepReturnsFalseIfRaffleNotOpen() public {
        vm.prank(USER);
        raffle.enterRaffle{value: entrancefee}();

        vm.warp(block.timestamp + interval +1);//vm.warp which sets the block.teimstamp
        vm.roll(block.number + 1);//vm.roll sets the block number
        raffle.performUpkeep("");//this is setting it to the calculating state
        Raffle.RaffleState raffleState = raffle.getRaffleState();//this is saying that the raffle state is calculating winner


        (bool upkeepNeeded, ) = raffle.checkUpkeep("");//this is saying that upkeep is not needed

        assert(raffleState == Raffle.RaffleState.CALCULATING_WINNER);//this is aserting that the raffle state is calculating winner
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        vm.prank(USER);
        raffle.enterRaffle{value: entrancefee}();
        
        vm.warp(block.timestamp + interval +1);//vm.warp which sets the block.timestamp
        vm.roll(block.number + 1);//vm.roll sets the block number
        raffle.performUpkeep("");//this is setting it to the calculating state
        ((block.timestamp + 1)-block.timestamp) < interval;//this is saying that the time interval has not passed
        

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");//thi is saying that upkeep is not needed if enough time has not passed

        //assert(((block.timestamp +1)-block.timestamp) < interval);//this is saying that the time interval has not passed
        assert(!upkeepNeeded);

    }

    function testCheckUpkeepReturnsTrueWhenParametersAreMet() public {
        vm.prank(USER);
        raffle.enterRaffle{value: entrancefee}();
        
        vm.warp(block.timestamp + interval +1);//vm.warp which sets the block.timestamp
        vm.roll(block.number + 1);//vm.roll sets the block number


        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(upkeepNeeded);
    }

    //////////////////////////
    // performUpkeep testing//
    //////////////////////////
    
    function testPerformUpkeepCanOnlyRunifCheckUpKeepisTrue() public{
        vm.prank(USER);
        raffle.enterRaffle{value: entrancefee}();

        vm.warp(block.timestamp + interval +1);//vm.warp which sets the block.timestamp
        vm.roll(block.number + 1);//vm.roll sets the block number

        raffle.performUpkeep("");//this is setting it to the calculating state

        //here this test will pass as is since the since an upKeep is needed 
        //however, if we remove vm.warp and vm.roll this will fail since upKeep is not needed and, therefore, performUpkeep will revert

    }

    function testPerformUpkeepRevertifCheckUpKeepisFalse() public{
        
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState raffleState = raffle.getRaffleState();
    
        

        //expectRevert docs: (https://book.getfoundry.sh/cheatcodes/expect-revert?highlight=expectrevert#expectrevert)
        //this is derived from the Raffle__UpKeepNotNeeded error line 137 in raffle.sol
        
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpKeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                uint256(raffleState)
            )
        );
        raffle.performUpkeep("");
    

    
        //we're expecting this transaction to fail (b/c expectRevert is saying "the transaction after me should fail"")

        //here this test will pass as is since the since an upKeep is needed 
    }




    //What if I need to test using the output of an event? We need to be able to test for events being emitted and their values being emitted.

    modifier RaffleEnteredandTimePassed() {
        vm.prank(USER);
        raffle.enterRaffle{value: entrancefee}();

        vm.warp(block.timestamp + interval +1);//vm.warp which sets the block.timestamp
        vm.roll(block.number + 1);//vm.roll sets the block number
        _;
    }

    function testPerformUpKeepUpdatesRaffleStateandEmitsRequestId() public RaffleEnteredandTimePassed {
        //Act
        vm.recordLogs(); //https://book.getfoundry.sh/cheatcodes/record-logs?highlight=recordlo#recordlogs
        raffle.performUpkeep("");//emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();//this will get all the values/recorded logs of emitted events and store in array

        //now we can get the requestId out of the array we just created from Vm.Log
        bytes32 requestId = entries[1].topics[1];//this is saying that we want the requestId from the 2nd event (the first event is the emit EnteredRaffle(USER) event stored in the VRFCoordinatorV2Mock contract)

        Raffle.RaffleState raffleState = raffle.getRaffleState();


        assert(uint256 (requestId) > 0); //to make sure the requestId was emitted
        assert(uint256 (raffleState) == 1); //to make sure the raffle state is calculating winner

    }


    ///////////////////////////////
    // fulfillRandomWords testing//
    //////////////////////////////

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }

        _;
    }

    function testFulfillRandomWordsCanOnlybeCalledAfterPerformUpkeep(uint256 randomRequestId) public RaffleEnteredandTimePassed skipFork {
        // Arrange
        vm.expectRevert("nonexistent request");

        //in order for us to test for every requestId generated we use a fuzzTest -> https://book.getfoundry.sh/reference/config/testing?highlight=fuzz#fuzz
        //this is where the 'uint256 randomRequestId is used and generates a new random number for each test

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(    //this is saying that we expect the revert to be caused by the "nonexistent request" error
            randomRequestId,
            address(raffle)
        );
    }



    //This test will be the full Raffle test where we enter the raffle, 
    //move the time up fo checkupkeep to be true, perform upkeep and send request to generate a random number,
    //and then fulfill random words.

    function testFulFillRandomWordsPicksAWinnerResetsAndSendsMoney() public RaffleEnteredandTimePassed skipFork{

        //Arrange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for(uint256 i = startingIndex; 
            i < startingIndex + additionalEntrants; 
            i++
        ){
            address player = address(uint160(i));// this is saying that we want to convert the uint256 i to an address where i = 1, 2 ,3, etc.
            hoax(player, USER_BALANCE);//hoax is == prank + deal
            raffle.enterRaffle{value: entrancefee}();
        }

        uint256 prize = entrancefee + (additionalEntrants * entrancefee);

        //kick off a request to chainlink vrf
        
        vm.recordLogs(); //https://book.getfoundry.sh/cheatcodes/record-logs?highlight=recordlo#recordlogs
        raffle.performUpkeep("");//emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();//this will get all the values/recorded logs of emitted events and store in array
        bytes32 requestId = entries[1].topics[1];
        uint256 previousTimeStamp = raffle.getLastTimeStamp();


        //now we need to pretend to be the VRFCoordinatorV2Mock contract and generate a random number and pick a winner

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(    //this is saying that we expect the revert to be caused by the "nonexistent request" error
            uint256 (requestId),
            address(raffle)
            );

        //Assert
        assert(uint256(raffle.getRaffleState()) == 0);//this is saying that the raffle state should be open
        assert(raffle.getRecentWinner() != address(0));//this is saying that the recent winner should not be address 0
        assert(raffle.getLengthOfPlayers() == 0);//this is saying that the length of players should be 0 after the winner is picked
        assert(previousTimeStamp < raffle.getLastTimeStamp());//this is saying that the previous timestamp should be less than the current timestamp
        console.log(raffle.getRecentWinner().balance);
        console.log(prize + USER_BALANCE);

        assert(raffle.getRecentWinner().balance == USER_BALANCE + prize - entrancefee);//this is saying that the recent winner's balance should be the starting user balance + the prize


    }


} 
