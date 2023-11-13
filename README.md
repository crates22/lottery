## About
# What does this contract do?

1. Users can enter the lottery by paying for a ticket.
    1. The ticket fees are going to go to the winner during the draw.
2. After X period of time, the lottery will automatically draw a winner. 
    1. This will be done programatically.
3. Using ChainLink VRF and ChainLink Automation.
    1. ChainLink VRF -> Randomness (choose winner)
    2. ChainLink Automation -> Time based trigger

## Tests!
1. Write some deploy scripts.
2. Write our tests such that:
    1. We work on a local chain (anvil), forked testnet, and forked mainnet.