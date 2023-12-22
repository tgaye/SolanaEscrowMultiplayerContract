pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.0/contracts/access/Ownable.sol";


contract GAMEGEAR is Ownable {
    struct Player {
        uint256 balance;
        uint256 wager;
        uint256 wins;
        uint256 losses;
        uint256 totalBet;
        uint256 totalWon;
        uint256 totalLost;
    }

    struct Game {
        address player1;
        address player2;
        uint256 wager;
        bool isActive;
    }

    struct LobbyInfo {
        uint256 gameId;
        address player1;
        address player2;
        uint256 wager;
    }

    mapping(address => Player) public players;
    mapping(uint256 => Game) public games;
    mapping(address => uint256[]) internal playerGames;
    mapping(address => uint256) public activePlayers;  

    uint256 public gameCounter;
    uint256 public platformFees;  
    uint256 public maxLobbies = 10;  


    event GameResult(uint256 gameId, address winner, uint256 amount);

    constructor() Ownable(msg.sender) {
        // Other initialization code if necessary
    }


    function deposit() public payable {
        players[msg.sender].balance += msg.value;
    }

    function withdraw(uint256 amount) public {
        require(players[msg.sender].balance >= amount, "Insufficient funds");
        payable(msg.sender).transfer(amount);
        players[msg.sender].balance -= amount;
    }

    function withdrawFees() public onlyOwner {
        uint256 fees = platformFees;
        platformFees = 0;  // Reset the accumulated fees to 0
        payable(owner()).transfer(fees);  // Correctly convert owner() to payable and transfer the fees
    }

    function createGame(address player1, address player2, uint256 wager) public onlyOwner returns (uint256) {
        require(activePlayers[player1] == 0 && activePlayers[player2] == 0, "One of the players is already active in a game");
        uint256 fee = wager / 20; // Assuming a 5% fee
        uint256 totalDeduction = wager + fee;
        require(players[player1].balance >= totalDeduction && players[player2].balance >= totalDeduction, "Insufficient funds for one of the players");

        players[player1].balance -= totalDeduction;
        players[player2].balance -= totalDeduction;
        platformFees += fee * 2; // Fee from both players

        uint256 gameId = gameCounter++;
        games[gameId] = Game({
            player1: player1,
            player2: player2,
            wager: wager,
            isActive: true
        });

        activePlayers[player1] = gameId;
        activePlayers[player2] = gameId;

        return gameId;
    }


    function getActiveGameId(address playerAddress) public view returns (uint256) {
        return activePlayers[playerAddress];
    }

    function resolveGame(uint256 gameId, address winner) public onlyOwner {
        Game storage game = games[gameId];
        require(game.isActive, "Game is not active");

        uint256 winnerPrize = game.wager * 2; // No fee deduction here
        players[winner].balance += winnerPrize;
        players[winner].totalWon += game.wager;
        players[winner].wins++;

        address loser = (game.player1 == winner) ? game.player2 : game.player1;
        players[loser].totalLost += game.wager;
        players[loser].losses++;

        players[game.player1].totalBet += game.wager;
        players[game.player2].totalBet += game.wager;

        game.isActive = false;
        delete activePlayers[game.player1];
        delete activePlayers[game.player2];
        delete games[gameId];  // Remove the game from storage

        emit GameResult(gameId, winner, winnerPrize);
    }

    function setMaxLobbies(uint256 _maxLobbies) public onlyOwner {
        maxLobbies = _maxLobbies;
    }

   

    function getAllGameLobbies() public view returns (LobbyInfo[] memory) {
        uint256 activeGameCount = 0;
        for (uint256 i = 0; i < gameCounter; i++) {
            if (games[i].isActive) {
                activeGameCount++;
            }
        }

        LobbyInfo[] memory lobbies = new LobbyInfo[](activeGameCount);
        uint256 index = 0;

        for (uint256 i = 0; i < gameCounter; i++) {
            if (games[i].isActive) {
                lobbies[index] = LobbyInfo({
                    gameId: i,
                    player1: games[i].player1,
                    player2: games[i].player2,
                    wager: games[i].wager
                });
                index++;
            }
        }

        return lobbies;
    }


    function getBalance(address playerAddress) public view returns (uint256) {
            return players[playerAddress].balance;
        }


}
