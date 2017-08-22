require 'digest'
require 'date'
require 'json'
require 'sinatra'
require 'open-uri'
require 'net/http'

class Blockchain
  attr_accessor :index, :timestamp, :data, :previous_hash, :hash

  def initialize(block, index, timestamp, data, previous_hash)
    @index = index
    @timestamp = timestamp
    @data = data
    @previous_hash = previous_hash
    @hash = block.nil? ? hash_block(self) : hash_block(block)
  end

  def hash_block(hash)
    sha = Digest::SHA256.new
    str = "#{hash.index}#{hash.timestamp}#{hash.data}#{hash.previous_hash}".to_s
    sha.update(str)
    sha.hexdigest
  end

  def as_json(options={})
    {
      index: @index,
      timestamp: @timestamp,
      data: @data,
      previous_hash: @previous_hash,
      hash: @hash
    }
  end

  def to_json(*options)
      as_json(*options).to_json(*options)
  end
end

def create_genesis_block
  # Manually construct a block with
  # index zero and arbitrary previous hash
  Blockchain.new(nil, 0, DateTime.now.to_time, {proof_of_work: 9, transactions: nil}, "")
end

# This node's blockchain copy
$blockchain = Array.new
$blockchain << create_genesis_block
# A completely random address of the owner of this node
$miner_address = "q3nf394hjg-random-miner-address-34nf3i4nflkn3oi"
# Store the transactions that
# this node has in a list
$this_nodes_transactions = Array.new
# Store the url data of every
# other node in the network
# so that we can communicate
# with them
$peer_nodes = Array.new
# A variable to deciding if we're mining or not
$mining = true

def transactions
  # On each new POST request,
  # we extract the transaction data
  request.body.rewind
  @request_payload = JSON.parse request.body.read
  $this_nodes_transactions << @request_payload
  print "New Transaction \n"
  print "FROM: #{@request_payload['from']}\n"
  print "TO: #{@request_payload['to']}\n"
  print "AMOUNT: #{@request_payload['amount']}\n"
  return {status: :success, message: "Transaction submission successful"}.to_json
end

def get_blocks
  chain_to_send = []
  # Convert our blocks into dictionaries
  # so we can send them as json objects later
  $blockchain.each do |chain|
    chain_to_send << {
      index: chain.index,
      timestamp: chain.timestamp,
      data: chain.data,
      hash: chain.hash
    }
  end
  return {status: :success, blocks: chain_to_send}.to_json
end

def find_new_chains
  # Get the blockchains of every
  # other node
  other_chains = Array.new
  $peer_nodes.each do |node_url|
    body = URI.parse('http://localhost:4567/blocks').read
    json = JSON::parse(body)
    block = Blockchain.new(index: json['index'], timestamp: json['timestamp'], data: json['data'], previous_hash: json['previous_hash'], hash: json['hash'])
    other_chains << block
  end
  other_chains
end

def consensus
  # Get the blocks from other nodes
  other_chains = find_new_chains
  # If our chain isn't longest,
  # then we store the longest chain
  longest_chain = $blockchain
  other_chains.each do |chain|
    longest_chain = chain if longest_chain.size < chain.size
  end
  # If the longest chain isn't ours,
  # then we stop mining and set
  # our chain to the longest one
  $blockchain = longest_chain
end

def proof_of_work(last_proof)
  # Create a variable that we will use to find
  # our next proof of work
  incrementor = last_proof + 1
  # Keep incrementing the incrementor until
  # it's equal to a number divisible by 9
  # and the proof of work of the previous
  # block in the chain
  while not (incrementor % 9 == 0 && incrementor % last_proof == 0)
    incrementor += 1
  end
  # Once that number is found,
  # we can return it as a proof
  # of our work
  incrementor
end

def mine
  # Get the last proof of work
  last_block = $blockchain.last
  last_proof = last_block.data[:proof_of_work]
  # Find the proof of work for
  # the current block being mined
  # Note: The program will hang here until a new
  #       proof of work is found
  proof = proof_of_work(last_proof)
  # Once we find a valid proof of work,
  # we know we can mine a block so
  # we reward the miner by adding a transaction
  $this_nodes_transactions << {from: "network", to: $miner_address, amount: 1}
  new_block_data = {
    proof_of_work: proof,
    transactions: $this_nodes_transactions
  }
  new_block_index = last_block.index + 1
  new_block_timestamp = this_timestamp = DateTime.now.to_time
  last_block_hash = last_block.hash
  # Empty transaction list
  $this_nodes_transactions = []
  mined_block = Blockchain.new(last_block, new_block_index, new_block_timestamp, new_block_data, last_block_hash)
  $blockchain << mined_block
  # Let the client know we mined a block
  return {
    index: mined_block.index,
    timestamp: mined_block.timestamp,
    data: mined_block.data,
    hash: mined_block.hash
  }.to_json
end


get '/' do
  'Hello world!'
end

post '/txion' do
  transactions
end

get '/blocks' do
  get_blocks
end

get '/mine' do
  mine
end
