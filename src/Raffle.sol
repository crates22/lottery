// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {console} from "forge-std/console.sol";



/**
 * @title A sample Raffle Contract
 * @author socrates
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2
 */

contract Raffle is VRFConsumerBaseV2 {
    
    //**Errors */
    error Raffle__NotEnoughETHSent();//this custom error specifies the required amount and the actual amount of entrancfee sent
    error Raffle__TransferFailed();//this custom error is for when the transfer of funds to the winner fails
    error Raffle__NotOpen();
    error Raffle__UpKeepNotNeeded(uint256 balance, uint256 entrants, uint256 raffleState);//this custom error is for when upkeep is not needed

    //**Type Declarations */
        //**Enums */
    enum RaffleState{ //here we are defining the states of the raffle
        OPEN, //these can be presented as integers (OPEN = 0, CALCULATING_WINNER = 1)
        CALCULATING_WINNER
    }


    //**State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_etrancefee;
    uint256 private immutable i_interval;//Duration of the lottery in seconds
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    uint256 private s_lastTimeStamp;
    address payable[] private s_entrants;
    address private s_recentWinner;
    RaffleState private s_raffleState;


    //**Events */
    event EnteredRaffle(address indexed entrant); 
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId); 

    //**Modifiers */
    constructor(uint256 entrancefee, 
                uint256 interval, 
                address vrfCoordinator, 
                bytes32 gasLane,
                uint64 subscriptionId,
                uint32 callbackGasLimit)
        VRFConsumerBaseV2(vrfCoordinator) {
        i_etrancefee = entrancefee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;//here we declare the Raffle is opened by default
    }


    //**Functions */
    function enterRaffle() external payable{
        //i want a user to deposit funds to enter the raffle
        //require that the amount is equal to the entrance fee
        //we could use 'require(msg.value >= i_etrancefee, "Not enough funds to enter the raffle");' but instead we use a custom error which is more gas efficient
        if (msg.value < i_etrancefee){
            revert Raffle__NotEnoughETHSent();
        }

        if(s_raffleState != RaffleState.OPEN){
            revert Raffle__NotOpen();
        }

        s_entrants.push(payable(msg.sender));//this will push new participants into the array above (in state variables)

        //Adding events makes migration and front end "indexing" easier
        emit EnteredRaffle(msg.sender);//this is the event that will be emitted when a user enters the raffle

    }



    //When is the winnder supposed to be picked?
    /**
     * @dev This is the function that the Chainlink Automation nodes call to see if it's time to perform upkeep.
     * The following should be true for this to return true:
     * 1. The time interval has passed between raffles runs.
     * 2. The raffle is in the OPEN state.
     * 3. The contract has ETH (aka raffle entrants)
     * 4. The VRF Coordinator has LINK (aka the contract can pay Chainlink node operators)
     */

    //UpKeep is a function called by ChainLink nodes that will create a lottery draw for us; first we check if requirements are met, then we perform the lottery draw!
    //Once UpKeep is called and performed, the ChainLink VRF will respond and call the fulfillRandomWords function which picks the winner!

    function checkUpkeep(bytes memory/* checkData */) public view returns (bool upkeepNeeded, bytes memory /* performData */){ //function is provided by chainlink automation example: https://docs.chain.link/chainlink-automation/compatible-contracts
        bool timHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;//this is the condition that needs to be met for upkeep to be needed
        bool isOpen = RaffleState.OPEN == s_raffleState;//this is the condition that needs to be met for upkeep to be needed
        bool hasBalance = address(this).balance > 0;//this is the condition that needs to be met for upkeep to be needed
        bool hasEntrants = s_entrants.length > 0;//this is the condition that needs to be met for upkeep to be needed
        upkeepNeeded = timHasPassed && isOpen && hasBalance && hasEntrants;//if any of these conditions are false, upkeep is not needed
        return (upkeepNeeded, "0x0");//this is the performData that is returned
    }


    function performUpkeep(bytes calldata /* performData */)  external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded){
            revert Raffle__UpKeepNotNeeded(//this revert is saying that upkeep is not needed and these are the parameters that are not met
                address(this).balance,
                s_entrants.length,
                uint256(s_raffleState)
            );

        }
        
        //check to see if enough time has passed
        s_raffleState = RaffleState.CALCULATING_WINNER;//here we change the state of the raffle to calculating winner (since we stated that the raffle is choosing the winner in performUpkeep function)
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,//gas lane
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS//this is the number of random numbers we want to get back
        );

        

        

        emit RequestedRaffleWinner(requestId);//this is the event that will be emitted when a winner is picked; it is a redundant emit b/c we alreadu get the requestId from the VRFCoordinatorV2Mock
        
    }

    //CEI: Check-Effect-Interaction
    function fulfillRandomWords(//this function is needed to call back the random number generated from Chainlink (ie pick a random winner) and reset our raffle
        
        uint256 requestId, //this is the requestID we generated in the function above
        uint256[] memory randomWords//this is the array of stored random numbers generated; we want to pick a random winner from the s_entrants array
    ) internal override {//we override this b/c in the VRFConsumerBaseV2 contract the function is 'internal' and not 'private'
        //Modulo function; used to pick one of the entrants in the s_entrants array
        //a modulo function basically divides two numbers and the remainder is the winner; 10 % 9 = 1, therfore, mod is 1.
        //example: s_entratns = 10 and our random number (rng) is 12; therefore, 12 % 10 = 2; therefore the winner is the 2nd entrant in the array
        
        //Checks
        //Effects (our own contract)
        uint256 indexOfWinner = randomWords[0] % s_entrants.length;
        address payable winner = s_entrants[indexOfWinner];
        s_recentWinner = winner;
        
        s_raffleState = RaffleState.OPEN;//here we change the state of the raffle back to open since winner has been chosen
        
        s_entrants = new address payable[](0);//here we reset the entrants array to 0

        s_lastTimeStamp = block.timestamp;//here we reset the last timestamp to the current block timestamp


       //External interactions with other contracts/addresses
        (bool success, ) = winner.call{value: address(this).balance}("");//this is how we send the funds to the winner
        if (!success){
            revert Raffle__TransferFailed();
        }

        emit WinnerPicked(winner);//this is the event that will be emitted when a winner is picked
    }

    /**Getter Function */

    function getEntranceFee() public view returns(uint256){
        return i_etrancefee;
    }

     function getRaffleState () external view returns (RaffleState) {
        return s_raffleState;
     }

     function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_entrants[indexOfPlayer];

     }

     function getRecentWinner() external view returns (address){
            return s_recentWinner;
     }

     function getLengthOfPlayers() external view returns (uint256){
         return s_entrants.length;
     }

     function getLastTimeStamp() external view returns (uint256){
         return s_lastTimeStamp;
     }

}