pragma solidity > 0.7.0;
// SPDX-License-Identifier: UvA-DPP2023

/* Define the smart contract Voting*/
contract Voting {

    /*
      Define a data structure called candidate
    */
    struct candidate {
        /* Name of the candidate */
        string name;
        /* The Blockchain address of the candidate. This is not directly used in
         this contract, but please think about what can it be used for? */
        address ads;
        /* Count the voting results of the candidate */
        int votes;
    }

    /* The list of all candidates. The example we only accepts three candidates */
    candidate[3] public candidatelist;

    /* The constructor function of the contract */
    constructor()
    {
        /* Initialize three candidates; their names, addresses and votes */
        candidatelist[0].name = 'Peter';
        candidatelist[0].ads = 0x68B87b5eb0908a23FC68788968a67A6d988aC255;
        candidatelist[0].votes = 0;
        candidatelist[1].name = 'George';
        candidatelist[1].ads = 0x72f4752ba880387b3E4b1c229599E348A5381Cb1;
        candidatelist[1].votes = 0;
        candidatelist[2].name = 'Richard';
        candidatelist[2].ads = 0x1727Fb67D31993494114d2fE171DC902085Cc323;
        candidatelist[2].votes=0;
    }

    /* Get a specific candidate based on their id: 0-2 */
    function getCandidate(uint id)
        public
        view
        returns(string memory)
    {
        if (id<candidatelist.length) {
            return candidatelist[id].name;
         }else return "";
    }

    /* Vote a specific candidate */
    function voteCandidate(uint id)
        public
        virtual
    {
        if (id<candidatelist.length) {
            candidatelist[id].votes+=1;
        }
    }

    /* Get the voting results of a specific candidate */
    function getVoteResults(uint id)
        public
        view
        returns(int)
    {
        if (id<candidatelist.length) {
            return candidatelist[id].votes;
        }else return -1;
    }

}

// Assignment 2.1.a
// Students should  improve this smart contract, so that no double voting will be allowed
contract VotingNodoubleVoting is Voting{
    //  You will need to define some data structure to store the voting history, e.g., voters, etc.


    //Override the following function with new code
    // Double voting should be detected.
    function voteCandidate(uint id)
        public
        virtual
        override 
    {



    }  
}

// Assignment 2.1.b
// Students should  improve this smart contract to accept only votings within the time window
contract VotingInTimeWindow is VotingNodoubleVoting{
   // You will need to define variables of time window

   // how will you initialized the time window?


    // improve the vodie candidate function
    function voteCandidate(uint id)
        public
        override
        // you also need code to check the time window
        // only the voting submitted within in the time window will be accepted

    {
      // ....   

    }      
}