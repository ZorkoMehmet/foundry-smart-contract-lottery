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
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";



/**
 * @title A sample Raffle Contract
 * @author Mehmet Sorkulu
 * @notice This contract is creating a sample Raffle
 * @dev Implements Chainlink VRFv2
 */

contract Raffle is VRFConsumerBaseV2{
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 raffleState, uint256 currentBalance, uint256 numPlayers);
    error Raffle__NotEnoughTimePassed();

    enum RaffleState{OPEN, CALCULATING}

    uint16 private constant REQUEST_CONFORMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    // @dev Duration of the lottery in seconds
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /** Events */

    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);

    constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator, bytes32 gasLane, uint64 subscriptionId, uint32 callbackGasLimit) VRFConsumerBaseV2(vrfCoordinator){
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_raffleState  = RaffleState.OPEN;

    }
 
    function enterRaffle() external payable{
        //require(msg.value >= i_entranceFee, "Not enough ETH sent!");
        if(msg.value < i_entranceFee){
            revert Raffle__NotEnoughEthSent();
        }
        if(s_raffleState != RaffleState.OPEN){
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));

        emit EnteredRaffle(msg.sender);
    }


    /**
     * @dev This is the function that the Chainlink Automation nodes call
     * to see if it's time to perform an upkeep.
     * The following should be true to return true:
     * 1. The time interval has passed between raffle runs
     * 2. The raffle is in the OPEN state
     * 3. The contract has ETH (aka players)
     * 4. The subscription is funded with LINK
     */

    function checkUpkeep( bytes memory /* checkData */) public view returns(bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */) external{
        (bool upkeepNeeded, ) = checkUpkeep("");

        if(!upkeepNeeded){
            revert Raffle__UpkeepNotNeeded(
                uint256(s_raffleState),
                address(this).balance,
                s_players.length
            );
        }


        s_raffleState = RaffleState.CALCULATING;

        i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFORMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
    }
        // CEI - Checks, Effects, Interactions
    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override{
        // CHECKS - Requare (if -> error)
        // EFFECTS (Our own contract)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;

        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(winner);

        // INTERACTIONS (Other contracts)
        (bool success, ) = winner.call{value: address(this).balance}("");
        if(!success){
            revert Raffle__TransferFailed();
        }
    }
    /** Getter Functions */
 
    function getEntranceFee() external view returns (uint256){
        return i_entranceFee;
    }
}