pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";

contract CryptArtifacts is Ownable {
  uint32 constant REST_PERIOD = 60 minutes;
  uint8 constant MAX_FIELDS = 20; //Change Artifacts.fields accordinaly  
  uint8 constant INITIAL_FIELD_VALUE = 7;
  uint8 constant INITIAL_LEVEL_VALUE = 1; //must be > 0
  uint8 constant INITIAL_WEIGHT_VALUE = 1;
  uint8 constant INITIAL_SIZE_VALUE = 1;
  uint16 constant NEXT_LEVEL_EXPERIENCE = 999;
  uint8 constant UNIQUE_FROM_LEVEL = 20;
  uint8 constant BLOCK_NUMBER_FOR_RANDOM = 4;

  uint8 constant ART_LEVEL_RND_IDX = 0;

  struct Artifact {
    bool trading;
    uint16 level;
    uint16 artModifier;
    uint16 weight;
    uint16 size;
    uint16[20] fields; 
  }

  struct Master {
    address source;
    string name;
    uint16 experience;
    uint16 level;
    uint32 restUntil;
    mapping(bytes32 => uint16) stash;
  }

  Master[] private masters;
  mapping(address => uint) addressToMaster;

  bytes32[] artsInTrading;
  mapping(bytes32 => Artifact) artifacts;
  mapping(bytes32 => uint[]) artifactToMaster;

  event ArtOrdered(address indexed sender, bytes32 indexed artId);
  event ArtDestroyed(bytes32 indexed artId);
  event ArtMixed(address indexed sender, bytes32 indexed artId);
  event MasterCreated(address indexed sender, uint masterId);

  function CryptArtifacts() public {
    regMaster("Guest");
  }

  modifier isRegistered() {
    require(addressToMaster[msg.sender] > 0);
    _;
  }

  function orderArt(uint16 _fieldId) public payable isRegistered returns(bytes32) {
    require(_fieldId < MAX_FIELDS);
    require(masterExist[msg.sender]);

    bytes32 artId;
    Artifact memory art;
    uint16[20] memory fields;
    fields[_fieldId] = INITIAL_FIELD_VALUE;


    (artId,art) = _createArt(
      INITIAL_LEVEL_VALUE,
      8,
      INITIAL_WEIGHT_VALUE,
      INITIAL_SIZE_VALUE,
      fields
    );

    ArtOrdered(msg.sender, artId);
    return artId;
  }

  function _createArt(
    uint16 level, 
    uint16 artModifier,
    uint16 weight,
    uint16 size,
    uint16[20] fields) 
    internal 
    returns(bytes32 artId, Artifact art) 
  {
    //Artifact memory art;
    art.level = level;
    art.artModifier = artModifier;
    art.weight = weight;
    art.size = size;  
    art.fields = fields;  
    art.trading = false;

    artId = _artifactHash(art);
    if (artifacts[artId].level == 0) {
      artifacts[artId] = art; 
    } 

    uint masterId = addressToMaster[msg.sender];
    artifactToMaster[artId].push(masterId);
    masters[masterId].stash[artId]++; 
  }

  function regMaster(string _name) public {
    Master memory master;
    master.name = _name;

    uint masterId = masters.push(master) - 1;
    addressToMaster[msg.sender] = masterId;

    MasterCreated(msg.sender, masterId);
  }

  function _artifactHash(Artifact art) private pure returns(bytes32) {
    return keccak256(
      uint16(art.level),
      uint16(art.artModifier),
      uint16(art.weight),
      uint16(art.size),
      art.fields);
  }

  function mixArts(bytes32 _artId1, bytes32 _artId2) public isRegistered returns(bytes32) {
    require(artifacts[_artId1].level > 0);
    require(artifacts[_artId2].level > 0);

    uint masterId = addressToMaster[msg.sender];
    require(artifacts[_artId1].level <= masters[masterId].level);
    require(artifacts[_artId2].level <= masters[masterId].level);
    require(masters[masterId].restUntil < now);
    require(masters[masterId].stash[_artId1] > 0);
    require(masters[masterId].stash[_artId2] > 0);
    require((_artId1 != _artId2) || (masters[masterId].stash[_artId1] > 1));

    var art1 = artifacts[_artId1];
    var art2 = artifacts[_artId2];

    bytes32 artId;
    Artifact memory art;
    uint16[20] memory fields;

    for (uint8 i = 0; i < MAX_FIELDS; i++) {
      fields[i] = art1.fields[i] + art2.fields[i];  
    }

    var newArtLevel = _levelRndVal(art1.level, art2.level, masters[masterId].level);
    
    (artId,art) = _createArt(
      art1.level + art2.level,
      art1.artModifier + art2.artModifier,
      art1.weight + art2.weight,
      art1.size + art2.size,
      fields
    );

    if (masters[masterId].experience == NEXT_LEVEL_EXPERIENCE) {
      masters[masterId].experience = 0;
      masters[masterId].level++;
    } else {
      masters[masterId].experience++;
    }
    

    masters[masterId].restUntil = now + 10 minutes;

    _destroyArtifact(_artId1, masters[masterId]);
    _destroyArtifact(_artId2, masters[masterId]);

    ArtMixed(msg.sender, artId);
    return artId;
  }

  function _levelRndVal(uint16 level1, uint16 level2, uint16 masterLevel) internal returns(uint16) {
    var levelRnd = getRandValue(ART_LEVEL_RND_IDX);
    var levelMin = level1;
    var levelMax = level2;
    if (levelMin > levelMax) {
      levelMin = level2;
      levelMax = level1;  
    }
    var levelDiff = (levelMax - levelMin) - masterLevel;
    if (levelDiff == 0) {
      return 
    }
  }

  function _destroyArtifact(bytes32 _artId, Master storage _master) internal {
    _master.stash[_artId]--;
    if (0 == _master.stash[_artId]) {
      delete(_master.stash[_artId]);
    }    
    delete(artifactToMaster[_artId]);
    delete(artifacts[_artId]);   

    ArtDestroyed(_artId);
  }

  function getRandValue(uint8 idx) public view returns(uint8) {
    Master memory master = masters[addressToMaster[msg.sender]];
    bytes32 val = keccak256(block.blockhash(4), msg.sender, master.name, artsInTrading);
    //bytes32 val = 0xafd0ecb8cf5be84065c75db7381d239b6f8b9924ec67711556c20d436e8375cb;
    uint256 mask = uint256(0xff) << (idx * 8);
    uint256 maskedVal = uint256(val) & mask;
    uint8 output = uint8(maskedVal >> (idx * 8));
    return output;
  }

  /*function getArtifact(uint _artId) 
    public 
    view 
    returns(
      uint16 level,
      uint16 artModifier,
      uint16 weight,
      uint16 size,
      uint16[20] fields) 
  {
    Artifact storage art = artifactsArr[_artId];
    level = art.level;
    artModifier = art.artModifier;
    weight = art.weight;
    size = art.size;
    fields = art.fields;
  }*/

  /*function getArtifact(uint _artId) 
    external 
    view
    returns(bytes32) 
  {
    Artifact memory art = artifactsArr[_artId];
    bytes32 artHash = _artifactHash(art);
    return artHash;
  }*/

  /*function getArtModifier(uint _artId) 
    external 
    view
    returns(uint16) 
  {
    Artifact memory art = artifactsArr[_artId];
    return art.artModifier;
  }*/

  function getArtifactField(bytes32 _artId, uint8 _fieldId) public view returns(uint16) {
    require(_fieldId < MAX_FIELDS);
    return artifacts[_artId].fields[_fieldId];
  }

}