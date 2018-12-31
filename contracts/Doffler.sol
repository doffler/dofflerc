pragma solidity ^0.4.24;
import "openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol";

contract Doffler is StandardToken {

	// Define constants
	string public constant name = "Doffler";
	string public constant symbol = "DOF";
	uint256 public constant decimals = 18;
	uint256 public constant INITIAL_SUPPLY = 1000000000000 * (10 ** decimals);

	mapping(address => uint) balances;
	mapping(address => mapping(address => uint)) allowed;

	event Deposit(address indexed from, uint tokens);
	event Request(address client, bytes32 hash, address[] edges, bytes program, bytes input, uint bounty, uint deadline);
	event Response(address edge, bytes32 hash);

	// Offloading properties
	struct Workload {
		address client;
		address[] edges;                    // Addresses of Edge devices the client requests the workload
		bytes32 program;                      // IPFS address of the target program
		bytes32 input;					              // Hash value of the input data
		mapping(address => bytes) outputs;  // Hash values of the output data from edge devices
		uint bounty;                        // Bounty for the workload
		uint deadline;                      // Block number when challenging period is over and the bounty is distributed
	}

	mapping(address => uint) deposits;
	mapping(bytes32 => Workload) workloads;

	constructor() public {
		totalSupply_ = INITIAL_SUPPLY;
		balances[owner] = INITIAL_SUPPLY;
	}

	// ------------------------------------------------------------------------
	// Offloading interfaces
	// ------------------------------------------------------------------------
	function deposit(uint _tokens) public returns (bool _success) {
		balances[msg.sender] = balances[msg.sender].sub(_tokens);
		deposits[msg.sender] = deposits[msg.sender].add(_tokens);
		emit Deposit(msg.sender, _tokens);
		return true;
	}

	function depositOf(address _depositOwner) public view returns (uint _deposit) {
		return deposits[_depositOwner];
	}

	function drawDeposit(uint _tokens) public returns (bool _success) {
		require(_tokens <= deposits[msg.sender]);
		deposits[msg.sender] = deposits[msg.sender].sub(_tokens);
		balances[msg.sender] = balances[msg.sender].add(_tokens);
		emit Deposit(msg.sender, deposits[msg.sender]);
		return true;
	}

	function request(bytes32 _hash, address[] memory _edges, bytes memory _program, bytes memory _input, uint _bounty, uint _period) public returns (bool _success) {
		require(deposits[msg.sender] >= _bounty);
		//TODO: same request
		//bytes[] memory outputs = new bytes[](_edges.length);
		//workloads[_hash] = Workload(msg.sender, _edges, _program, _input, outputs, _bounty, _deadline);
		Workload memory workload;
		workload.client = msg.sender;
		workload.edges = _edges;
		workload.program = _program;
		workload.input = _input;
		workload.bounty = _bounty;
		workload.deadline = block.number + _period;
		workloads[_hash] = workload;
		emit Request(msg.sender, _hash, _edges, _program, _input, _bounty, workload.deadline);
		return true;
	}

	function requestOf(bytes32 _hash) public view returns (address[] memory edges, bytes memory program, bytes memory input, uint bounty, uint deadline) {
		Workload memory workload = workloads[_hash];
		return (workload.edges, workload.program, workload.input, workload.bounty, workload.deadline);
	}

	function response(bytes32 _hash, bytes memory _output) public returns (bool _success) {
		require(block.number < workloads[_hash].deadline);
		workloads[_hash].outputs[msg.sender] = _output;
		//TODO: Handle validators who are not included in the edges
		emit Response(msg.sender, _hash);
		return true;
	}

	function responseOf(bytes32 _hash, address _edge) public view returns (bytes memory _output) {
		return workloads[_hash].outputs[_edge];
	}

	function reward(bytes32 _hash) public returns (bool _success) {
		require(block.number >= workloads[_hash].deadline);
		Workload memory workload = workloads[_hash];
		uint edge_length = workload.edges.length;
		uint bounty = workload.bounty / edge_length;
		//TODO: Verify outputs
		for (uint i = 0; i < edge_length; i++) {
			address edge = workload.edges[i];
			balances[edge] += bounty;
			emit Transfer(workload.client, edge, bounty);
		}
		//TODO: Send rewards to other validators except edges
		//TODO: Add challenge process
		return true;
	}

	//TODO: challenge process
	//function challenge(bytes memory output) public returns (bool _success) {
	//    return true;
	//}

	// ------------------------------------------------------------------------
	// ERC-20 interfaces
	// ------------------------------------------------------------------------
	function totalSupply() public view returns (uint) {
		return _totalSupply.sub(balances[address(0)]);
	}

	function balanceOf(address _tokenOwner) public view returns (uint _balance) {
		return balances[_tokenOwner];
	}

	function transfer(address _to, uint _tokens) public returns (bool _success) {
		balances[msg.sender] = balances[msg.sender].sub(_tokens);
		balances[_to] = balances[_to].add(_tokens);
		emit Transfer(msg.sender, _to, _tokens);
		return true;
	}

	function approve(address _spender, uint _tokens) public returns (bool _success) {
		allowed[msg.sender][_spender] = _tokens;
		emit Approval(msg.sender, _spender, _tokens);
		return true;
	}

	function transferFrom(address _from, address _to, uint _tokens) public returns (bool _success) {
		balances[_from] = balances[_from].sub(_tokens);
		allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_tokens);
		balances[_to] = balances[_to].add(_tokens);
		emit Transfer(_from, _to, _tokens);
		return true;
	}

	function allowance(address _tokenOwner, address _spender) public view returns (uint remaining) {
		return allowed[_tokenOwner][_spender];
	}

	/*
		 function approveAndCall(address _spender, uint _tokens, bytes memory _data) public returns (bool _success) {
		 allowed[msg.sender][_spender] = _tokens;
		 emit Approval(msg.sender, _spender, _tokens);
		 ApproveAndCallFallBack(_spender).receiveApproval(msg.sener, _tokens, this, _data);
		 return true;
		 }
	 */

	function () payable external {
		revert();
		/*
			 uint amount = msg.value;
			 balanceOf[msg.sender] += amount;
			 emit TokenTransfer(msg.sender, amount);
		 */
	}

		// ------------------------------------------------------------------------
		// Owner can transfer out any accidentally sent ERC20 tokens
		// ------------------------------------------------------------------------
		function transferAnyERC20Token(address _tokenAddress, uint _tokens) public onlyOwner returns (bool _success) {
			return ERC20Interface(_tokenAddress).transfer(owner, _tokens);
		}
	}
