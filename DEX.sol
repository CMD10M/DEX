pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT
// import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//An automatic market that holds reserves of both ETH and Balloons. The reserves provide liquidity so anyone can swap between assets

contract DEX {

  IERC20 token;
  //token is defined as ERC20 Token address
  constructor(address token_addr) {
    token = IERC20(token_addr);
  }

  //variables track total liquidity and also individual addresses

  uint256 public totalLiquidity;
  mapping (address => uint256) public liquidity;

  // Initialization function - lets us set up ratio for dex to have liquidity/reserves

  function init(uint256 tokens) public payable returns (uint256) {

    //requires the totalliquidity to be zero which was defined above as a uint256
    require(totalLiquidity==0, "DEX:init -already has liquidity");
    //checks the balance of the contract address and calls it total liquidity
    totalLiquidity = address(this).balance;
    //uses mapping to map the address of the msg.sender to the totalLiquidity 
    liquidity[msg.sender] = totalLiquidity;
    //Uses transferFrom function in ERC20 contract to allow msg.sender to send tokens from contract address.
    require(token.transferFrom(msg.sender, address(this), tokens));
    //after transfer has occured or if it has occured, function 'returns' or shows new amount of totalLiquidity
    return totalLiquidity;
      }


    //Function automatically adjusts the price as the ratio of reserves change. Called an automated market maker (AMM). AMM's allow digital assets to be traded in a permissionless way by using liquidity pools with crypto tokens whose prices are determined by a constant mathematical formula.
    function price(uint256 input_amount, uint256 input_reserve, uint256 output_reserve) public view returns (uint256) {
      uint256 input_amount_with_fee = (input_amount * 997);
      uint256 numerator = (input_amount_with_fee * output_reserve);
      uint256 denominator = (input_reserve * 1000) + input_amount_with_fee;
      return numerator / denominator;
    }

    function ethToToken() public payable returns (uint256) {
      //checks the amount of equivalent tokens  in the address of the swapper
      uint256 token_reserve = token.balanceOf(address(this));
      //uses price function to determine how much tokens the person can buy. This price function 'call' corresponds to the initialization of the function above: msg.value = input_amount, address(this).balance - msg.value = input_reserve, token_reserve = output_reserve. Takes new variables and runs it through the price function
      uint256 tokens_bought = price(msg.value, address(this).balance - msg.value, token_reserve);
      //makes sure token transfer goes through
      require(token.transfer(msg.sender, tokens_bought));
      return tokens_bought;
    }

    function tokenToEth(uint256 tokens) public payable returns (uint256) {
      //checks the amount of equivalent tokens in the address of the swapper
      uint256 token_reserve = token.balanceOf(address(this));
      //uses price function to determine how much eth can be bought based on reserves and pre-defined formula
      uint256 eth_bought = price(tokens, token_reserve, address(this).balance);
      //boolean that checks amount eth bought from msg.sender
      (bool sent, ) = msg.sender.call{value: eth_bought}("");
      require (sent, "Failed to transfer ETH");
      require (token.transferFrom(msg.sender, address(this), tokens));
      return eth_bought;
    }
    //function that allows us to deposit into the liquidity pool
    function deposit() public payable returns (uint256) {
      //Defines current eth reserve
      uint256 eth_reserve = address(this).balance - msg.value;
      //Defines current token reserve
      uint256 token_reserve = token.balanceOf(address(this));
      //Defines ratio of tokens to ETH
      uint256 token_amount = ((msg.value * token_reserve)/ eth_reserve) + 1;
      //Defines amount of liquidity added from depositer
      uint256 liquidity_minted = (msg.value * totalLiquidity) / eth_reserve;
      //Calculates amount of new liquidity added from depositer
      liquidity[msg.sender] += liquidity_minted;
      //defines new amount of liquidity
      totalLiquidity += liquidity_minted;
      //Token is transfered from msg sender to contract
      require(token.transferFrom(msg.sender, address(this), token_amount));
      //returns how much liqudity was added
      return liquidity_minted;
    }

    //function so people can withdraw their liquidity
    function withdraw(uint256 liq_amount) public returns (uint256, uint256) {
      //defines current token reserve
      uint256 token_reserve = token.balanceOf(address(this));
      //defines eth amount based on ratio
      uint256 eth_amount = (liq_amount * address(this).balance) / totalLiquidity;
      //defines token_amount based on ratio
      uint256 token_amount = (liq_amount * token_reserve) / totalLiquidity;
      //calculates amount of liquidity withdrawn from msg sender
      liquidity[msg.sender] -= liq_amount;
      //calculates new amount of total liquidity
      totalLiquidity -= liq_amount;
      //boolean that checks the amount of eth withdrawn
      (bool sent, ) = msg.sender.call{value: eth_amount}("");
      //checks boolean and returns a failed to send message
      require(sent, "Failed to send user eth");
      //checks if tokens were sent from message sender
      require(token.transfer(msg.sender, token_amount));
      return (eth_amount, token_amount);
    }
}