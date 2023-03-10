// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract PHKG_Contract {
    mapping(uint => bytes32) roleMapping;
    address owner;

    constructor() {
        owner = msg.sender;
    }

    //Token Event
    event tokenEvent(
        string roleType,
        address dataConsumer,
        bytes32 token,
        string role
    );

    // Register Patient event
    event registeredPatientEvent(address patientAddress, string param);

    event roleToDataAllowedEvent(string role, string typeOfdataAllowed);

    //mapping Patient(Data Owner) to data Consumer(doctor) mapping-1
    mapping(address => address[]) public patientToDataConsumerMapping;

    //mapping Patient(Data Owner) to  Hospital(Data Producer)  mapping-2
    mapping(address => address[]) public patientToDataProducerMapping;

    //nonce for helping in generating token through hashing
    uint nonce = 1;

    struct dataConsumerDetails {
        bytes32 token;
        string role;
    }

    struct dataProducerDetails {
        bytes32 token;
        string role;
    }

    //mapping between data Consumer to dataConsumer Details mapping-1_2
    mapping(address => dataConsumerDetails)
        public dataConsumerAddressToConsumerDetailsMapping;

    //mapping between data Producer to data Producer Details mapping 2_2
    mapping(address => dataProducerDetails)
        public dataProducerAddressToProducerDetailMapping;

    address[] public registeredPatient;

    uint256 public constant patientRegisterAmount = 1000000000000000000 wei;

    mapping(string => string) public roleToAllowedDataMapping;

    address[] public registeredDataProducer;

    //Owner is the one who puts contract on the ethereum and is different from Data Owner
    modifier ownerOnly() {
        if (owner == msg.sender) {
            _;
        }
    }

    //patient registration
    function registerDataOwner() external payable {
        require(
            msg.value == patientRegisterAmount,
            "Please send exactly the desired amount"
        );

        registeredPatient.push(msg.sender);
        emit registeredPatientEvent(msg.sender, "New patient was registed");
    }

    modifier authorizedDataOwner() {
        bool isUserAuthorizedPatient = false;
        for (uint i = 0; i < registeredPatient.length; i++) {
            if (registeredPatient[i] == msg.sender) {
                isUserAuthorizedPatient = true;
            }
        }

        if (isUserAuthorizedPatient) {
            _;
        }
    }

    function addANewRole(
        string memory role,
        string memory typeOfAllowedData
    ) public ownerOnly {
        //assuming the mapping has role to typeOfAllowedData is already populated by owner
        roleToAllowedDataMapping[role] = typeOfAllowedData;
        emit roleToDataAllowedEvent(role, typeOfAllowedData);
    }

    function registerDataProducer(
        address _dataProducerAddress,
        string memory role
    ) public authorizedDataOwner {
        address patient = msg.sender;
        address dataProducer = _dataProducerAddress;
        //update mapping-2
        patientToDataProducerMapping[patient].push(dataProducer);

        //struct object created with empty token field
        dataProducerDetails
            memory dataProducerDetailsObject = dataProducerDetails(
                bytes32(0),
                role
            );

        //update mapping-2_2
        dataProducerAddressToProducerDetailMapping[
            dataProducer
        ] = dataProducerDetailsObject;
    }

    function registerDataConsumer(
        address _dataConsumerAddress,
        string memory role
    ) public authorizedDataOwner {
        address patient = msg.sender;
        address dataConsumer = _dataConsumerAddress;
        //update mapping-1
        patientToDataConsumerMapping[patient].push(dataConsumer);

        //struct object created with empty token field
        dataConsumerDetails
            memory dataConsumerDetailsObject = dataConsumerDetails(
                bytes32(0),
                role
            );

        //update mapping-1_2
        dataConsumerAddressToConsumerDetailsMapping[
            dataConsumer
        ] = dataConsumerDetailsObject;
    }

    //data producers call this function to get token
    function getAccess_Producer(address _patientAddress) public {
        bool isRequestingDataProducerAuthorized = false;

        for (
            uint i = 0;
            i < patientToDataProducerMapping[_patientAddress].length;
            i++
        ) {
            if (
                patientToDataProducerMapping[_patientAddress][i] == msg.sender
            ) {
                isRequestingDataProducerAuthorized = true;
            }
        }

        if (isRequestingDataProducerAuthorized == true) {
            bytes32 token = keccak256(abi.encodePacked(nonce, msg.sender));
            nonce++;

            dataProducerDetails
                memory obj = dataProducerAddressToProducerDetailMapping[
                    msg.sender
                ];
            obj.token = token;
            dataProducerAddressToProducerDetailMapping[msg.sender] = obj;

            //emit token here
            emit tokenEvent("Data Producer", msg.sender, token, obj.role);
        } else {
            revert("Unauthorized Data Producer");
        }
    }

    //data consumers call this function to get token
    function getAccess_Consumer(address _patientAddress) public {
        bool isRequestingDataConsumerAuthorized = false;

        for (
            uint i = 0;
            i < patientToDataConsumerMapping[_patientAddress].length;
            i++
        ) {
            if (
                patientToDataConsumerMapping[_patientAddress][i] == msg.sender
            ) {
                isRequestingDataConsumerAuthorized = true;
            }
        }

        if (isRequestingDataConsumerAuthorized == true) {
            bytes32 token = keccak256(abi.encodePacked(nonce, msg.sender));
            nonce++;

            dataConsumerDetails
                memory obj = dataConsumerAddressToConsumerDetailsMapping[
                    msg.sender
                ];
            obj.token = token;
            dataConsumerAddressToConsumerDetailsMapping[msg.sender] = obj;

            //emit token here
            emit tokenEvent("Data Consumer", msg.sender, token, obj.role);
        } else {
            revert("Unauthorized Data Consumer");
        }
    }

    //this is for the resource system to check the requesting users token and role
    function verifyAccess(
        address _Address,
        string memory _typeOfRequest
    ) public view returns (bytes32, string memory, string memory) {
        bool isConsumer = false;
        bool isProducer = false;
        string memory read = "read";
        string memory write = "write";

        if (
            keccak256(abi.encodePacked(_typeOfRequest)) ==
            keccak256(abi.encodePacked(read))
        ) {
            isConsumer = true;
        }

        if (
            keccak256(abi.encodePacked(_typeOfRequest)) ==
            keccak256(abi.encodePacked(write))
        ) {
            isProducer = true;
        }

        if (isConsumer) {
            dataConsumerDetails
                memory dataConsumerDetailsObject = dataConsumerAddressToConsumerDetailsMapping[
                    _Address
                ];

            bytes32 token = dataConsumerDetailsObject.token;
            string memory role = dataConsumerDetailsObject.role;
            string memory typeOfDataAllowed = roleToAllowedDataMapping[role];

            return (token, role, typeOfDataAllowed);
        }

        if (isProducer) {
            dataProducerDetails
                memory dataProducerDetailsObject = dataProducerAddressToProducerDetailMapping[
                    _Address
                ];

            bytes32 token = dataProducerDetailsObject.token;
            string memory role = dataProducerDetailsObject.role;
            string memory typeOfDataAllowed = roleToAllowedDataMapping[role];

            return (token, role, typeOfDataAllowed);
        } else {
            revert("Unauthorized");
        }
    }

    function removeDataConsumer(
        address _dataConsumerAddress
    ) public authorizedDataOwner {
        for (
            uint i = 0;
            i < patientToDataConsumerMapping[msg.sender].length;
            i++
        ) {
            if (
                patientToDataConsumerMapping[msg.sender][i] ==
                _dataConsumerAddress
            ) {
                patientToDataConsumerMapping[msg.sender][i] = address(0);
                break;
            }
        }
    }

    function removeDataProducer(
        address _dataProducerAddress
    ) public authorizedDataOwner {
        for (
            uint i = 0;
            i < patientToDataProducerMapping[msg.sender].length;
            i++
        ) {
            if (
                patientToDataProducerMapping[msg.sender][i] ==
                _dataProducerAddress
            ) {
                patientToDataProducerMapping[msg.sender][i] = address(0);
                break;
            }
        }
    }

    function removeDataOwner(address _registeredPatient) public ownerOnly {
        for (uint i = 0; i < registeredPatient.length; i++) {
            if (registeredPatient[i] == _registeredPatient) {
                registeredPatient[i] = address(0);
                break;
            }
        }
    }
}
