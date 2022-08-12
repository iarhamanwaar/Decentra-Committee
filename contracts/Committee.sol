// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Committee is Ownable {
    // since committee inherits ownable there is no need to separately
    // mention a manager, the owner is the manager

    event NewMember(string name, uint memberId);
    event CommitteeDispensed(string name, uint memberId, uint amount);
    event MemberTopUp(string name, uint memberId);

    uint committeeAmount = 0.001 ether;
    uint committeeInterval = 1 weeks;
    uint lastPayout = 0;
    bool isCommitteeOpen = true;
    uint randNonce = 0;
    bool canTopUp = false;

    // struct that defines member properties
    struct Member {
        string name;
        uint id;
        address payable addressId;
        bool hasRecievedPayout;
        bool hasPaid;
    }

    // list of members who are in the committee
    Member[] public members;

    mapping(address => uint) addressToId;

    // when a user wants to join the committee, function returns the id of user
    function join(string memory _name) external payable returns (uint) {
        // check if committee is open to join
        require(isCommitteeOpen);

        // check if user has paid the correct amount
        require(msg.value == committeeAmount);

        // save new id of member
        uint id = members.length;

        // push new member to array and save id
        members.push(Member(_name, id, payable(msg.sender), false, true));

        emit NewMember(_name, id);
        return id;
    }

    // when the manager wants to disperse committee
    function payout() external onlyOwner {
        // check if a week has passed or not
        require(lastPayout < (block.timestamp + committeeInterval));

        // lock the committee so that no new members can join
        isCommitteeOpen = false;

        // construct a memory array of members who didnt get a payout yet
        // max length of array can be members.length when the first payout is being done
        Member[] memory membersToChooseFrom = new Member[](members.length);

        // counter outside loop so number of members is known
        uint counter = 0;
        for (uint i = 0; i < members.length; i++) {
            if (!members[i].hasRecievedPayout) {
                membersToChooseFrom[counter] = members[i];
                counter++;
            }
        }

        // case when the last payout is made
        if (counter == 1) {
            // allow the members to topup their payments for next week
            canTopUp = true;
        }

        // pick a random winner
        uint randomIndex = uint(
            keccak256(abi.encodePacked(block.timestamp, randNonce))
        ) % counter;
        randNonce++;
        Member storage winner = members[membersToChooseFrom[randomIndex].id];

        winner.addressId.transfer(address(this).balance);
        winner.hasRecievedPayout = true;
        winner.hasPaid = false;

        lastPayout = block.timestamp;

        emit CommitteeDispensed(winner.name, winner.id, address(this).balance);
    }

    // when users need to top up for the next time
    function topUp() public payable {
        // first check if top up is allowed
        require(canTopUp);

        // check if user has paid the correct amount
        require(msg.value == committeeAmount);

        // find member id using mapping of address
        uint memberId = addressToId[msg.sender];
        members[memberId].hasRecievedPayout = false;
        members[memberId].hasPaid = true;

        emit MemberTopUp(members[memberId].name, memberId);
    }
}
