# 📱 On-Chain Lost & Found Item Registry

> 🔍 Submit, claim, or verify lost items securely and immutably on the Stacks blockchain

## 🌟 Overview

The On-Chain Lost & Found Item Registry is a decentralized smart contract that enables users to:
- 📝 Submit lost items with reward offerings
- 🎯 Submit found items for claiming
- 🤝 Claim items that match their lost possessions
- ✅ Verify legitimate claims through owner approval
- 💰 Automatically distribute rewards upon successful verification

## 🚀 Features

- **Immutable Records**: All submissions are permanently stored on-chain
- **Reward System**: STX rewards for successful item returns
- **Verification Process**: Owner-controlled claim approval system
- **Status Tracking**: Real-time item status updates (Lost → Found → Claimed → Verified)
- **User Management**: Track all items associated with each user
- **Item Management**: Update or cancel items before they're claimed

## 📋 Item Status Flow

```
LOST ──→ CLAIMED ──→ VERIFIED ✅
  ↑         ↓
  └─── REJECTED ───┘

FOUND ──→ CLAIMED ──→ VERIFIED ✅
   ↑         ↓
   └─── REJECTED ───┘
```

## 🛠️ Contract Functions

### 📤 Submit Functions

#### `submit-lost-item`
Submit a lost item with optional reward
```clarity
(submit-lost-item "iPhone 14" "Black iPhone with blue case" "Downtown Coffee Shop" u1000000)
```

#### `submit-found-item` 
Submit a found item
```clarity
(submit-found-item "Wallet" "Brown leather wallet with ID" "Central Park Bench")
```

### 🎯 Claim Functions

#### `claim-item`
Claim an item that might be yours
```clarity
(claim-item u1)
```

#### `verify-claim`
Approve or reject a claim (item owner only)
```clarity
(verify-claim u1 true)  ;; Approve claim
(verify-claim u1 false) ;; Reject claim
```

### 📊 Management Functions

#### `update-item`
Update item details (before claiming)
```clarity
(update-item u1 "Updated Title" "New description" "Updated location")
```

#### `cancel-item`
Cancel an item submission (before claiming)
```clarity
(cancel-item u1)
```

### 🔍 Read Functions

#### `get-item`
Get item details by ID
```clarity
(get-item u1)
```

#### `get-user-items`
Get all item IDs for a user
```clarity
(get-user-items 'SP1234...)
```

#### `get-items-by-status`
Filter items by status (1=Lost, 2=Found, 3=Claimed, 4=Verified)
```clarity
(get-items-by-status u1) ;; Get all lost items
```

## 🎮 Usage Examples

### 📱 Scenario 1: Lost Item with Reward

1. **Submit Lost Item**:
   ```clarity
   (submit-lost-item "MacBook Pro" "Silver 13-inch with stickers" "University Library" u5000000)
   ```

2. **Someone Claims It**:
   ```clarity
   (claim-item u1)
   ```

3. **Verify the Claim**:
   ```clarity
   (verify-claim u1 true) ;; Reward automatically transferred!
   ```

### 🎒 Scenario 2: Found Item

1. **Submit Found Item**:
   ```clarity
   (submit-found-item "Keys" "Honda car keys with blue keychain" "Mall Parking Lot")
   ```

2. **Owner Claims It**:
   ```clarity
   (claim-item u2)
   ```

3. **Verify Ownership**:
   ```clarity
   (verify-claim u2 true)
   ```

## ⚡ Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### 🔧 Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/On-Chain-Lost-and-Found-Item-Registry
   cd On-Chain-Lost-and-Found-Item-Registry
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Run tests:
   ```bash
   clarinet test
   ```

4. Deploy to testnet:
   ```bash
   clarinet deploy --testnet
   ```

## 🧪 Testing

Run the test suite:
```bash
npm test
```

## 🏗️ Project Structure

```
On-Chain-Lost-and-Found-Item-Registry/
├── contracts/
│   └── On-Chain-Lost-and-Found-Item-Registry.clar
├── tests/
├── settings/
├── Clarinet.toml
├── package.json
└── README.md
```

## 📈 Error Codes

| Code | Description |
|------|-------------|
| 100  | Not authorized |
| 101  | Item not found |
| 102  | Already claimed |
| 103  | Invalid status |
| 104  | Not owner |
| 105  | Duplicate item |

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/clarity/)
- [Clarinet Documentation](https://github.com/hirosystems/clarinet)

---

Made with ❤️ for the Stacks community
