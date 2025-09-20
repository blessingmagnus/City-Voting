# Community-Driven Urban Planning Smart Contract

A blockchain-based governance system that enables residents to propose, vote on, and fund local infrastructure projects through a transparent and democratic process.

## Overview

This smart contract implements a decentralized autonomous organization (DAO) for urban planning, allowing community members to:

- Register as voters by staking STX tokens
- Propose infrastructure projects with detailed specifications
- Vote on proposed projects during designated periods
- Contribute funding to approved projects
- Execute approved projects through transparent fund distribution

## Features

### Core Functionality
- **Voter Registration**: Stake-based registration system requiring minimum token holdings
- **Project Proposals**: Community members can propose infrastructure projects with budget requirements
- **Democratic Voting**: Time-bound voting periods with quorum requirements
- **Funding Mechanism**: Community-driven funding for approved projects
- **Transparent Execution**: Administrative execution of approved projects with fund distribution

### Security Features
- Owner-only administrative functions
- Double-voting prevention
- Voting period validation
- Quorum requirements (20% of registered voters)
- Stake-based voting eligibility

## Contract Constants

### Error Codes
- `ERR-UNAUTHORIZED-ACCESS (100)`: Caller lacks required permissions
- `ERR-PROJECT-NOT-FOUND (101)`: Referenced project does not exist
- `ERR-INVALID-PROJECT-STATUS (102)`: Project not in required status for operation
- `ERR-VOTING-PERIOD-EXPIRED (103)`: Voting period has ended
- `ERR-VOTING-PERIOD-ACTIVE (104)`: Voting period is still active
- `ERR-ALREADY-VOTED (105)`: User has already voted on this project
- `ERR-INSUFFICIENT-FUNDS (106)`: Insufficient funds for operation
- `ERR-INVALID-AMOUNT (107)`: Invalid amount specified
- `ERR-NOT-ELIGIBLE-VOTER (108)`: User not eligible to vote
- `ERR-INVALID-VOTING-PERIOD (109)`: Invalid voting period duration
- `ERR-PROJECT-ALREADY-EXECUTED (110)`: Project has already been executed
- `ERR-QUORUM-NOT-MET (111)`: Insufficient voter participation

### Project Status
- `STATUS-PROPOSED (0)`: Project has been proposed but voting hasn't started
- `STATUS-VOTING (1)`: Project is in active voting period
- `STATUS-APPROVED (2)`: Project has been approved by vote
- `STATUS-REJECTED (3)`: Project has been rejected by vote
- `STATUS-EXECUTED (4)`: Project has been executed and funds distributed

### System Parameters
- **Minimum Voting Period**: 144 blocks (~24 hours)
- **Maximum Voting Period**: 1008 blocks (~1 week)
- **Minimum Proposal Amount**: 1,000,000 microSTX (1 STX)
- **Quorum Requirement**: 20% of registered voters
- **Default Voting Token Requirement**: 1,000,000 microSTX (1 STX)

## Public Functions

### Voter Management

#### `register-voter(stake-amount: uint)`
Register as a voter by staking the required amount of STX tokens.

**Parameters:**
- `stake-amount`: Amount of microSTX to stake (minimum 1 STX)

**Returns:** `(ok true)` on success

#### `update-voter-stake(additional-stake: uint)`
Increase your existing stake to maintain or enhance voting eligibility.

**Parameters:**
- `additional-stake`: Additional microSTX to stake

**Returns:** `(ok true)` on success

#### `deactivate-voter(voter: principal)` [Admin Only]
Deactivate a registered voter.

**Parameters:**
- `voter`: Principal address of the voter to deactivate

**Returns:** `(ok true)` on success

### Project Management

#### `propose-project(title: string-ascii, description: string-ascii, budget: uint, voting-period: uint)`
Submit a new infrastructure project proposal.

**Parameters:**
- `title`: Project title (max 100 characters)
- `description`: Project description (max 500 characters)
- `budget`: Requested budget in microSTX (minimum 1 STX)
- `voting-period`: Proposed voting duration in blocks (144-1008 blocks)

**Returns:** `(ok project-id)` with the assigned project ID

#### `start-voting(project-id: uint, voting-period: uint)` [Admin Only]
Initiate the voting period for a proposed project.

**Parameters:**
- `project-id`: ID of the project to start voting for
- `voting-period`: Voting duration in blocks (144-1008 blocks)

**Returns:** `(ok true)` on success

#### `vote-on-project(project-id: uint, vote-for: bool)`
Cast a vote on an active project proposal.

**Parameters:**
- `project-id`: ID of the project to vote on
- `vote-for`: `true` to vote in favor, `false` to vote against

**Returns:** `(ok true)` on success

#### `finalize-voting(project-id: uint)` [Admin Only]
Conclude the voting period and determine the project outcome.

**Parameters:**
- `project-id`: ID of the project to finalize

**Returns:** `(ok status)` with the final project status

### Funding and Execution

#### `contribute-to-project(project-id: uint, amount: uint)`
Contribute funds to an approved project.

**Parameters:**
- `project-id`: ID of the approved project
- `amount`: Contribution amount in microSTX

**Returns:** `(ok true)` on success

#### `execute-project(project-id: uint, recipient: principal)` [Admin Only]
Execute an approved project by transferring funds to the specified recipient.

**Parameters:**
- `project-id`: ID of the approved project to execute
- `recipient`: Principal address to receive the project funds

**Returns:** `(ok true)` on success

### Administrative Functions

#### `set-contract-owner(new-owner: principal)` [Owner Only]
Transfer contract ownership to a new address.

**Parameters:**
- `new-owner`: Principal address of the new contract owner

**Returns:** `(ok true)` on success

#### `set-voting-token-requirement(new-amount: uint)` [Admin Only]
Update the minimum token requirement for voting eligibility.

**Parameters:**
- `new-amount`: New minimum stake amount in microSTX

**Returns:** `(ok true)` on success

## Read-Only Functions

### `get-project(project-id: uint)`
Retrieve complete details for a specific project.

### `get-vote(project-id: uint, voter: principal)`
Get voting information for a specific voter on a specific project.

### `get-voter-info(voter: principal)`
Retrieve registration and stake information for a voter.

### `get-project-contribution(project-id: uint, contributor: principal)`
Get the contribution amount from a specific contributor to a project.

### `get-contract-stats()`
Retrieve overall contract statistics including total projects and voters.

### `is-voting-active(project-id: uint)`
Check if a project is currently in an active voting period.

### `get-voting-results(project-id: uint)`
Get comprehensive voting results and status for a project.

## Usage Example

```clarity
;; Register as a voter
(contract-call? .urban-planning register-voter u1000000)

;; Propose a new park project
(contract-call? .urban-planning propose-project 
  "Community Park Renovation" 
  "Upgrade playground equipment and add walking paths" 
  u5000000 
  u720)

;; Vote on project #1
(contract-call? .urban-planning vote-on-project u1 true)

;; Contribute to approved project
(contract-call? .urban-planning contribute-to-project u1 u500000)
```

## Governance Model

This contract implements a stake-weighted democratic governance system where:

1. **Participation**: Users must stake STX tokens to participate in governance
2. **Proposal**: Any eligible voter can propose infrastructure projects
3. **Deliberation**: Projects have designated voting periods for community input
4. **Decision**: Projects are approved based on simple majority with quorum requirements
5. **Funding**: Community members can contribute to approved projects
6. **Execution**: Approved projects are executed by contract administrators

## Security Considerations

- All financial operations include comprehensive validation
- Voting is time-bounded with strict period enforcement
- Double-voting is prevented through mapping-based tracking
- Administrative functions are restricted to contract owner
- Stake requirements ensure voter commitment to community outcomes

## Development and Deployment

This contract is written in Clarity for the Stacks blockchain. Deploy using the Stacks CLI or compatible development tools.

### Prerequisites
- Stacks wallet for deployment
- Sufficient STX for contract deployment and initial operations
- Understanding of Clarity smart contract development