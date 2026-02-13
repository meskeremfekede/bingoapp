# Multiplayer Bingo Game

This document outlines the features and logic for a multiplayer number-calling game.

---

## Admin Side Features

### 1. Game Creation
- **Fields:** Game Name, Game Code, Max Players, Max Cards per Player, Winning Pattern, Card Cost.
- **Action:** Creates a new game document in Firebase.

### 2. Game List & Search
- Displays all games in a list or grid.
- **Details per game:** Game Name, Pattern, Called Numbers, Winner, Status (Completed/Ongoing).
- Includes a search bar to filter games.

### 3. Player Management
- A dashboard to view and manage all players.
- **Features:** Search players, Add/Remove players, Refresh list.
- Displays total player balance and individual player details.

### 4. Admin Profile/Settings
- **Change Password:** A dedicated section to update admin credentials.
- **Registration Code:** View and change the current game registration code.

---

## Player Side Features

### 1. Games Navigation

**A. Active Games List:**
- Displays games open for joining.
- **Game Card Details:** Game ID, Admin Name, Player Count (current/max), Entry Fee, Max Cards, Winning Patterns.
- Each card has a "Join" button.

**B. Joining a Game & Lobby:**
- Player joins with a Game Code.
- After joining, the player enters a lobby.
- **Lobby View:** Shows a list of joined players, game settings, and a waiting message.

**C. Card Selection:**
- When the game starts, the player selects 1 or 2 cards.
- Entry fee is deducted from the player's wallet upon selection.

### 2. Gameplay Screen

**A. Game Board:**
- Displays the player's 5x5 Bingo card(s).
- Called numbers are highlighted in real-time.

**B. Competitors List:**
- Shows a list of other players in the game.
- Tracks player progress (optional).

**C. Game Progress:**
- Displays a running log of called numbers.
- Shows the active winning patterns.
- A popup announces the winner, ending the game.

### 3. Completed Games History
- A separate tab to view past games.
- **Details:** Game ID, Winner, Prize, Date.

### 4. Wallet Navigation

- **Current Balance:** Real-time display of the player's wallet.
- **Transaction History:** A detailed list of all deposits, game fees, and prizes, filterable by date or type.

### 5. Player Profile

- **Profile Details:** Name, Email, Change Password option.
- **Rank Display:** Shows the player's rank (e.g., "Gold") based on wins or total prize money.

---

## Core Logic & Technical Requirements

### Firebase Structure
- **`games/<gameId>`:** Document for each game containing all game-related data (players, money, winner, etc.).
- **`players/<playerId>`:** Document for each player storing their balance and profile info.

### Money & Game Flow
1.  **Game Creation:** Admin sets game rules. `totalMoney` is initialized to `0`.
2.  **Player Join:** Player's balance is checked. The card cost is deducted and added to the game's `totalMoney` pot.
3.  **Game Start & Win:** A winner is declared. The `totalMoney` is split between the winner (e.g., 75%) and the admin (e.g., 25%).
4.  **Real-time Updates:** Use `StreamBuilder` in Flutter to listen for live changes to game state, balances, and called numbers.
