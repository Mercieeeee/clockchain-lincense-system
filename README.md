# License Management System Smart Contract

## Overview

The **License Management System** is a smart contract designed to manage licenses for digital assets. It allows content owners and administrators to grant, revoke, transfer, and update licenses, which are represented as non-fungible tokens (NFTs). The contract supports both single and batch license grants with metadata validation to ensure correct information management.

This system is built to:

- Grant, revoke, and transfer licenses for digital assets.
- Allow metadata validation during license creation and updates.
- Support batch processing to grant up to 50 licenses in a single transaction.
- Provide security by validating license ownership and ensuring the integrity of metadata.

## Features

### Core Features:
- **Single License Grants:** Allows the admin to grant a single license to a user with metadata attached.
- **Batch License Grants:** Enables the admin to grant up to 50 licenses in one transaction, with metadata validation for each.
- **License Revocation:** Supports revocation of licenses by their holders, preventing further use.
- **License Transfer:** Facilitates the transfer of licenses between users.
- **Metadata Validation:** Ensures that the metadata for each license is valid before being granted or updated.
- **License Updates:** Allows license holders to update their license metadata.

### Error Handling:
- **Unauthorized Access:** Only the administrator can grant licenses, and only the owner can revoke or transfer their license.
- **License Validation:** Ensures licenses are valid before performing any actions.
- **Metadata Checks:** Prevents invalid or empty metadata from being added to licenses.

## License Token

Licenses are represented by NFTs (Non-Fungible Tokens) using the `license-token` contract, where each license is represented by a unique ID and metadata. This contract tracks and manages these tokens.

## Functions

### Admin Functions:
- **grant-license(metadata):** Grants a single license with the specified metadata.
- **batch-grant-license(metadatas):** Grants a batch of licenses (up to 50) with specified metadata for each.
- **revoke-license(license-id):** Revokes a specific license by ID.
- **transfer-license(license-id, sender, recipient):** Transfers a license from the sender to the recipient.

### Read-Only Functions:
- **get-license-metadata(license-id):** Retrieves metadata for a specific license.
- **get-license-holder(license-id):** Retrieves the current holder of a license.
- **verify-license-existence(license-id):** Verifies whether a license exists by checking if it has associated metadata.

### Private Functions:
- **is-license-holder(license-id, holder):** Verifies if the specified holder owns the license.
- **is-valid-metadata(metadata):** Validates the metadata format (non-empty and within the allowed character limit).
- **is-license-revoked(license-id):** Checks if the license has been revoked.

## Error Constants

- **err-unauthorized:** Raised when an unauthorized action is attempted.
- **err-license-exists:** Raised if the license already exists.
- **err-license-not-found:** Raised if the license ID does not exist.
- **err-invalid-license-id:** Raised if the provided license ID is invalid.
- **err-invalid-metadata:** Raised if the metadata is invalid.
- **err-license-revoked:** Raised if the license has already been revoked.
- **err-batch-limit-exceeded:** Raised if the batch size exceeds the maximum limit.
- **err-empty-metadata:** Raised if the metadata is empty.

## Usage

### Granting a License

To grant a single license to a user, the admin can call the `grant-license` function with the desired metadata.

```clojure
(grant-license "This is the metadata for the license.")
```

### Batch Granting Licenses

To grant multiple licenses in one transaction, use the `batch-grant-license` function with a list of metadata entries.

```clojure
(batch-grant-license ["Metadata 1" "Metadata 2" "Metadata 3" ...])
```

### Revoking a License

A license holder can revoke their license using the `revoke-license` function. Only the owner of the license can revoke it.

```clojure
(revoke-license license-id)
```

### Transferring a License

To transfer a license to another user, the license holder can use the `transfer-license` function.

```clojure
(transfer-license license-id sender recipient)
```

### Metadata Validation

Ensure that the metadata for a license is valid before granting or updating it.

```clojure
(validate-simple-metadata "Valid Metadata")
```

## Contract Architecture

- **License Metadata:** Stored in the `license-metadata` map, which associates a license ID with its metadata.
- **Revoked Licenses:** Tracked in the `revoked-licenses` map to indicate which licenses have been revoked.
- **License IDs:** The last issued license ID is tracked in the `last-license-id` variable to ensure unique license IDs.

## Security Considerations

- Only the **admin** (defined as the transaction sender) can grant licenses, batch grant licenses, or perform other administrative actions.
- **License owners** can update their own license metadata or revoke their license, but cannot perform these actions on others' licenses.
- **Revoked licenses** are flagged and cannot be used or transferred after revocation.
- **Metadata validation** ensures that metadata is non-empty and within the allowed size limit.

## Error Handling

The contract contains predefined error messages to ensure that actions are only performed under the correct conditions. Unauthorized actions, invalid metadata, and exceeded batch limits are handled with specific error codes.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.
```
