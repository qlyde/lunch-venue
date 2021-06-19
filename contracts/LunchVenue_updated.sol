// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

/// @title Contract to agree on the lunch venue
/// @author James Kroeger
contract LunchVenue {
    // ------------------------ EXTENSION 2 ------------------------
    // An enumeration to track the current stage in the voting process.
    // -------------------------------------------------------------
    enum State {
        Planning, // In this state, the `manager` can `addVenue()` and `addFriend()`
        Voting, // In this state, a `Friend` can `doVote()`
        Finished // In this state, the voting process has finished and a venue may have been selected
        // Cancelled
    }

    struct Friend {
        string name;
        bool voted;
    }

    struct Vote {
        address voterAddress;
        uint venue;
    }

    // ------------------------ EXTENSION 2 ------------------------
    // The initial stage in the voting process is `Planning`.
    // In this stage, the contract manager is responsible for adding friends and venues.
    // -------------------------------------------------------------
    State public state = State.Planning;

    // ------------------------ EXTENSION 3 ------------------------
    // `timeoutBlock` is the block number at which the voting process will timeout.
    // A timeout is signified by a transition to the `Finished` state.
    // The `votedVenue` will be decided based on the current votes.
    // -------------------------------------------------------------
    uint public timeoutBlock;

    mapping (uint => string) public venues; // List of venues (venue no, name)
    mapping (address => Friend) public friends; // List of friends (address, Friend)
    uint public numVenues = 0;
    uint public numFriends = 0;
    uint public numVotes = 0;
    address public manager; // Manager of lunch venues
    string public votedVenue = ""; // Where to have lunch

    mapping (uint => Vote) private votes; // List of votes (vote no, Vote)
    mapping (uint => uint) private results; // List of vote counts (venue no, no of votes)

    // -------------------------------------------------------------
    // -------------------------------------------------------------

    // Creates a new lunch venue contract
    constructor() {
        manager = msg.sender; // Set contract creator as manager
    }

    // ------------------------ EXTENSION 3 ------------------------
    /// @notice Set the `timeoutBlock`
    /// @param blockNumber Block for timeout to occur
    /// @return New timeout block
    function setTimeout(uint blockNumber)
        public
        restricted
        stateIs(State.Voting)
        returns (uint)
    {
        require(block.number >= timeoutBlock, "We have already timed out");
        require(block.number <= blockNumber, "Timeout block cannot be in the past");
        return timeoutBlock = blockNumber;
    }

    // ------------------------ EXTENSION 3 ------------------------
    /// @notice Extend the `timeoutBlock`
    /// @param nblocks Number of blocks to extend the timeout for
    /// @return New timeout block
    function extendTimeout(uint nblocks)
        public
        restricted
        stateIs(State.Voting)
        returns (uint)
    {
        require(block.number >= timeoutBlock, "We have already timed out");
        return timeoutBlock += nblocks;
    }

    // ------------------------ EXTENSION 3 ------------------------
    /// @notice Reduce the `timeoutBlock`
    /// @param nblocks Number of blocks to reduce the timeout for
    /// @return New timeout block
    function reduceTimeout(uint nblocks)
        public
        restricted
        stateIs(State.Voting)
        returns (uint)
    {
        require(block.number >= timeoutBlock, "We have already timed out");
        require(block.number <= timeoutBlock - nblocks, "Timeout block cannot be in the past");
        return timeoutBlock -= nblocks;
    }

    /// @notice Add a new lunch venue
    /// @dev To simplify the code duplication of venues is not checked
    /// @param name Name of the venue
    /// @return Number of lunch venues added so far
    function addVenue(string memory name)
        public
        restricted
        // ----- EXTENSION 2 ----- Must be in `Planning` stage to `addVenue()`
        stateIs(State.Planning)
        returns (uint)
    {
        numVenues++;
        venues[numVenues] = name;
        return numVenues;
    }

    /// @notice Add a new friend who can vote on lunch venue
    /// @dev To simplify the code duplication of friends is not checked
    /// @param friendAddress Friend's account address
    /// @param name Friend's name
    /// @return Number of friends added so far
    function addFriend(address friendAddress, string memory name)
        public
        restricted
        // ----- EXTENSION 2 ----- Must be in `Planning` stage to `addFriend()`
        stateIs(State.Planning)
        returns (uint)
    {
        Friend memory f;
        f.name = name;
        f.voted = false;
        friends[friendAddress] = f;
        numFriends++;
        return numFriends;
    }

    // ------------------------ EXTENSION 2 ------------------------
    // Transition from `Voting` state to `Planning` state.
    // -------------------------------------------------------------
    /// @notice Begin voting stage
    /// @dev Can only transition to `Voting` state from the `Planning` state
    function startVoting()
        public
        restricted
        stateIs(State.Planning)
    {
        state = State.Voting;

        // ------------------------ EXTENSION 3 ------------------------
        // The default `timeoutBlock` will be 280 blocks from the current block.
        // With an average block time of 13 seconds the timeout will be approx. 60 minutes from contract creation.
        // -------------------------------------------------------------
        timeoutBlock = block.number + 280;
    }

    /// @notice Vote for a lunch venue
    /// @param venue Venue number being voted
    /// @return validVote Is the vote valid? A valid vote should be from a registered friend who hasn't voted and to a registered venue
    function doVote(uint venue)
        public
        // ----- EXTENSION 2 ----- Must be in `Voting` stage to `doVote()`
        stateIs(State.Voting)
        returns (bool validVote)
    {
        // ------------------------ EXTENSION 3 ------------------------
        // Check if timeout has been reached.
        // If so, call `finalResult()` to force a lunch venue to be chosen based on current votes.
        // The state transitions to `Finished`.
        // -------------------------------------------------------------
        if (block.number >= timeoutBlock) {
            finalResult();
            return false;
        }

        // ------------------------ EXTENSION 1 ------------------------
        // Here we check if the voter has already voted and do not allow them to vote again if so.
        // -------------------------------------------------------------
        if (!canVoteFor(msg.sender, venue))
            return false;

        friends[msg.sender].voted = true;
        Vote memory v;
        v.voterAddress = msg.sender;
        v.venue = venue;
        numVotes++;
        votes[numVotes] = v;

        if (numVotes >= numFriends / 2 + 1) // Quorum is met
            finalResult();

        return true;
    }

    /// @notice Determine winner venue
    /// @dev If top 2 venues have the same no of votes, final result depends on vote order
    function finalResult() private {
        if (numVotes == 0) {
            // ------------------------ EXTENSION 3 ------------------------
            // If voting has timed out and there are no votes, set the `votedVenue` to "<UNDECIDED>".
            // -------------------------------------------------------------
            votedVenue = "<UNDECIDED>";
        } else {
            uint highestVotes = 0;
            uint highestVenue = 0;

            for (uint i = 1; i <= numVotes; i++) { // For each vote
                uint voteCount = 1;
                if (results[votes[i].venue] > 0) { // Already start counting
                    voteCount += results[votes[i].venue];
                }
                results[votes[i].venue] = voteCount;

                if (voteCount > highestVotes) { // New winner
                    highestVotes = voteCount;
                    highestVenue = votes[i].venue;
                }
            }

            votedVenue = venues[highestVenue]; // Chosen lunch venue
        }

        state = State.Finished; // ----- EXTENSION 2 ----- Voting is now closed
    }

    // ------------------------ EXTENSION 1 ------------------------
    // A function to check if a given address is allowed to vote for a given venue.
    // Here we also check if the voter has already voted and do not allow them to vote again if so.
    // -------------------------------------------------------------
    /// @notice Check if an address is able to vote for a venue
    /// @dev `voterAddress` is not guaranteed to be a `Friend` so check that they are
    /// @dev `voterAddress` may have already voted so do not allow them to vote again if so
    /// @dev `venue` is not guaranteed to be a valid `Venue` so check that it is
    /// @param voterAddress Address of the attempted voter
    /// @param venue Venue being voted for
    /// @return Can `voterAddress` vote for `venue`?
    function canVoteFor(address voterAddress, uint venue) private view returns (bool) {
        // Does friend exist?
        if (bytes(friends[msg.sender].name).length == 0) return false;

        // Does venue exist?
        if (bytes(venues[venue]).length == 0) return false;

        // ------------------------ EXTENSION 1 ------------------------
        // A friend cannot vote more than once.
        // This prevents monopolization of the voting.
        // -------------------------------------------------------------
        if (friends[voterAddress].voted) return false;

        return true;
    }

    // ------------------------ EXTENSION 2 ------------------------
    // A modifier to check the current state of the contract.
    // -------------------------------------------------------------
    /// @notice Check state is as expected
    /// @param _state Is the voting process in this state?
    modifier stateIs(State _state) {
        if (state != _state) {
            if (state == State.Planning)
                require(false, "Function cannot be called in the Planning state");
            else if (state == State.Voting)
                require(false, "Function cannot be called in the Voting state");
            else if (state == State.Finished)
                require(false, "Function cannot be called in the Finished state");
        }
        _;
    }

    /// @notice Only manager can do
    modifier restricted() {
        require(msg.sender == manager, "Can only be executed by the manager");
        _;
    }
}
