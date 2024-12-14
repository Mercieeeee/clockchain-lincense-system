;; Licensing System - A License Management System
;; This contract allows content owners to grant, revoke, and transfer licenses for digital assets.
;; It supports both single and batch license grants with metadata validation.
;; - Licenses are represented as non-fungible tokens (NFTs).
;; - Admins can grant, revoke, and transfer licenses, while metadata can be updated by the license owner.
;; - Batch functionality allows up to 50 licenses to be granted in one transaction.
;; - It ensures security through ownership validation and metadata checks.

;; Constants
(define-constant admin tx-sender) ;; Defines the administrator as the transaction sender
(define-constant max-license-batch u50) ;; Maximum number of licenses that can be granted in one batch
(define-constant err-unauthorized (err u200)) ;; Error for unauthorized actions
(define-constant err-license-exists (err u201)) ;; Error if license already exists
(define-constant err-license-not-found (err u202)) ;; Error if license is not found
(define-constant err-invalid-license-id (err u203)) ;; Error for invalid license ID
(define-constant err-invalid-metadata (err u204)) ;; Error for invalid license metadata
(define-constant err-license-revoked (err u205)) ;; Error if the license has been revoked
(define-constant err-batch-limit-exceeded (err u206)) ;; Error if batch size exceeds the limit
(define-constant err-empty-metadata (err u207)) ;; Error for empty metadata

;; Data Variables
(define-non-fungible-token license-token uint) ;; Non-fungible token for managing licenses
(define-data-var last-license-id uint u0) ;; Tracks the last issued license ID

;; Maps to store data
(define-map license-metadata uint (string-ascii 512)) ;; Metadata associated with each license
(define-map revoked-licenses uint bool) ;; Keeps track of revoked licenses
(define-map batch-license-metadata uint (string-ascii 512)) ;; Metadata for batch licenses

;; Private Helper Functions
(define-private (is-license-holder (license-id uint) (holder principal))
    ;; Checks if the specified holder is the owner of the license
    (is-eq holder (unwrap! (nft-get-owner? license-token license-id) false)))

(define-private (is-valid-metadata (metadata (string-ascii 512)))
    ;; Validates that the metadata is not empty and within length constraints
    (let 
        (
            (metadata-len (len metadata))
        )
        (and 
            (> metadata-len u0) 
            (<= metadata-len u512)
            (not (is-eq metadata ""))
        )
    ))

(define-private (is-license-revoked (license-id uint))
    ;; Checks if the license has been revoked
    (default-to false (map-get? revoked-licenses license-id)))

;; Core Functionality

(define-private (verify-metadata-length (metadata (string-ascii 512)))
;; Verifies that the metadata length is between 1 and 512 characters
(let
    (
        (metadata-len (len metadata))
    )
    (ok (and (> metadata-len u0) (<= metadata-len u512)))))

(define-private (grant-license-single (metadata (string-ascii 512)))
    ;; Grants a single license with specified metadata
    (let 
        (
            (new-license-id (+ (var-get last-license-id) u1)) ;; Increment the last license ID
        )
        (asserts! (is-valid-metadata metadata) err-invalid-metadata) ;; Ensure metadata is valid
        (try! (nft-mint? license-token new-license-id tx-sender)) ;; Mint new NFT for the license
        (map-set license-metadata new-license-id metadata) ;; Store metadata for the new license
        (var-set last-license-id new-license-id) ;; Update last license ID
        (ok new-license-id))) ;; Return the new license ID

;; Public License Functions

(define-public (grant-license (metadata (string-ascii 512)))
    ;; Grants a license by calling the private function for a single license
    (begin
        (asserts! (is-eq tx-sender admin) err-unauthorized) ;; Only admin can grant licenses
        (asserts! (is-valid-metadata metadata) err-invalid-metadata) ;; Validate metadata
        (grant-license-single metadata))) ;; Call core function to mint license

(define-public (batch-grant-license (metadatas (list 50 (string-ascii 512))))
    ;; Grants a batch of licenses with metadata validation
    (let 
        (
            (batch-size (len metadatas)) ;; Get the size of the batch
        )
        (begin
            (asserts! (is-eq tx-sender admin) err-unauthorized) ;; Only admin can batch grant licenses
            (asserts! (<= batch-size max-license-batch) err-batch-limit-exceeded) ;; Ensure batch size is within limit
            (asserts! (fold check-metadata metadatas true) err-invalid-metadata) ;; Validate all metadata entries in the batch
            (ok (fold grant-in-batch metadatas (list)))))) ;; Grant licenses in batch

(define-private (check-metadata (metadata (string-ascii 512)) (valid bool))
    ;; Helper function to check metadata validity for batch processing
    (and valid (is-valid-metadata metadata)))

(define-private (grant-in-batch (metadata (string-ascii 512)) (previous-results (list 50 uint)))
    ;; Helper function for granting licenses in batch, accumulating results
    (match (grant-license-single metadata)
        success (unwrap-panic (as-max-len? (append previous-results success) u50))
        error previous-results)) ;; Return previous successful results if error occurs

(define-public (check-admin)
;; Checks if the transaction sender is the admin
(ok (is-eq tx-sender admin)))

(define-public (revoke-license (license-id uint))
    ;; Revokes a specific license and updates the revoked licenses map
    (let 
        (
            (current-holder (unwrap! (nft-get-owner? license-token license-id) err-license-not-found)) ;; Get current license holder
        )
        (asserts! (is-eq tx-sender current-holder) err-unauthorized) ;; Ensure only the holder can revoke
        (asserts! (not (is-license-revoked license-id)) err-license-revoked) ;; Ensure license isn't already revoked
        (try! (nft-burn? license-token license-id current-holder)) ;; Burn the NFT for the license
        (map-set revoked-licenses license-id true) ;; Mark the license as revoked
        (ok true))) ;; Return success


(define-public (check-license-exists (license-id uint))
;; Checks if a license exists by looking up its metadata
(ok (is-some (map-get? license-metadata license-id))))

(define-public (does-license-exist (license-id uint))
;; Checks if the license exists by its ID
(ok (is-some (map-get? license-metadata license-id))))

(define-public (increment-last-license-id)
;; Increments the last issued license ID by 1
(let 
    (
        (new-id (+ (var-get last-license-id) u1))
    )
    (var-set last-license-id new-id)
    (ok new-id)))

(define-public (update-license-metadata-simple (license-id uint) (new-metadata (string-ascii 512)))
;; Allows the owner to update the metadata of a license
(begin
    (let 
        (
            (license-owner (unwrap! (nft-get-owner? license-token license-id) err-license-not-found)) ;; Get the current license owner
        )
        (asserts! (is-eq license-owner tx-sender) err-unauthorized) ;; Ensure only the owner can update
        (asserts! (is-valid-metadata new-metadata) err-invalid-metadata) ;; Validate the new metadata
        (map-set license-metadata license-id new-metadata) ;; Update the metadata for the license
        (ok true))))

(define-public (check-license-valid (license-id uint))
;; Checks if a license is valid (not revoked and metadata is valid)
(let 
    (
        (metadata (map-get? license-metadata license-id)) ;; Get the license metadata
    )
    (begin
        (asserts! (is-some metadata) err-license-not-found) ;; Ensure license exists
        (let
            (
                (is-revoked (is-license-revoked license-id)) ;; Check if license is revoked
            )
            (ok (and (not is-revoked) (is-some metadata)))))))

(define-public (check-license-holder (license-id uint))
;; Checks the holder of a specific license
(ok (nft-get-owner? license-token license-id)))


(define-public (transfer-license (license-id uint) (sender principal) (recipient principal))
    ;; Transfers a license from one user to another
    (begin
        (asserts! (is-eq recipient tx-sender) err-unauthorized) ;; Ensure the sender is the transaction sender
        (asserts! (not (is-license-revoked license-id)) err-license-revoked) ;; Ensure license isn't revoked
        (let 
            (
                (actual-sender (unwrap! (nft-get-owner? license-token license-id) err-license-not-found)) ;; Get actual sender of the license
            )
            (asserts! (is-eq actual-sender sender) err-unauthorized) ;; Ensure the sender matches the license holder
            (try! (nft-transfer? license-token license-id sender recipient)) ;; Transfer the license NFT
            (ok true)))) ;; Return success

(define-public (update-license-metadata (license-id uint) (new-metadata (string-ascii 512)))
    ;; Updates the metadata for an existing license
    (begin
        (let 
            (
                (license-owner (unwrap! (nft-get-owner? license-token license-id) err-license-not-found)) ;; Get the current license owner
            )
            (asserts! (is-eq license-owner tx-sender) err-unauthorized) ;; Ensure only the owner can update
            (asserts! (is-valid-metadata new-metadata) err-invalid-metadata) ;; Validate the new metadata
            (map-set license-metadata license-id new-metadata) ;; Update the metadata for the license
            (ok true)))) ;; Return success

;; Read-Only Functions

(define-read-only (get-license-metadata (license-id uint))
    ;; Retrieves the metadata for a specific license
    (ok (map-get? license-metadata license-id)))

(define-read-only (get-license-holder (license-id uint))
    ;; Retrieves the current holder of a license
    (ok (nft-get-owner? license-token license-id)))

(define-read-only (get-license-owner (license-id uint))
;; Retrieves the owner of a license
(ok (nft-get-owner? license-token license-id)))

(define-read-only (verify-license-existence (license-id uint))
;; Verifies if the license exists by checking if it has metadata
(ok (is-some (map-get? license-metadata license-id))))

(define-read-only (get-license-owner-simple (license-id uint))
;; Retrieves the owner of a specific license
(ok (nft-get-owner? license-token license-id)))

(define-read-only (get-license-metadata-simple (license-id uint))
;; Retrieves the metadata for a specific license, returns null if not found
(ok (map-get? license-metadata license-id)))

(define-read-only (is-license-revoked-simple (license-id uint))
;; Checks if a specific license is revoked
(ok (is-license-revoked license-id)))

(define-read-only (get-license-holder-simple (license-id uint))
;; Retrieves the holder of a license (simplified return)
(ok (unwrap! (nft-get-owner? license-token license-id) err-license-not-found)))

(define-read-only (get-last-license-id-simple)
;; Retrieves the last issued license ID
(ok (var-get last-license-id)))

(define-read-only (get-last-license-id)
    ;; Retrieves the ID of the most recently issued license
    (ok (var-get last-license-id)))

(define-read-only (check-license-valid-simple (license-id uint))
;; Checks if a license exists and is valid (not revoked)
(let 
    (
        (metadata (map-get? license-metadata license-id)) ;; Get the license metadata
    )
    (ok (and (is-some metadata) (not (is-license-revoked license-id))))))

(define-read-only (check-license-exists-simple (license-id uint))
;; Checks if a license exists by its ID
(ok (is-some (map-get? license-metadata license-id))))

(define-read-only (check-license-revoked-simple (license-id uint))
;; Checks if a license has been revoked and returns true/false
(ok (is-license-revoked license-id)))

(define-read-only (is-license-id-valid (license-id uint))
;; Validates if a license ID is within the range of issued licenses
(ok (and (> license-id u0) (<= license-id (var-get last-license-id)))))


(define-read-only (get-total-licenses-issued)
;; Returns the last issued license ID, representing total licenses issued
(ok (var-get last-license-id)))

(define-read-only (is-license-revoked-light (license-id uint))
;; Returns true if the license has been revoked, false otherwise
(ok (default-to false (map-get? revoked-licenses license-id))))

(define-read-only (get-revocation-status (license-id uint))
;; Checks if a specific license has been revoked
(ok (is-license-revoked license-id)))

(define-read-only (is-admin)
;; Verifies if the transaction sender is the admin
(ok (is-eq tx-sender admin)))

(define-read-only (retrieve-metadata (license-id uint))
;; Retrieves metadata directly for a license or returns none
(ok (map-get? license-metadata license-id)))

(define-read-only (get-license-status (license-id uint))
;; Retrieves the status of a license
(if (is-some (map-get? license-metadata license-id))
    (if (is-license-revoked license-id)
        (ok "Revoked")
        (ok "Valid"))
    (ok "Not Found")))

(define-read-only (get-total-licenses)
;; Retrieves the total number of licenses issued so far
(ok (var-get last-license-id)))

;; Contract Initialization

(begin
    ;; Initializes the contract by setting the last issued license ID to 0
    (var-set last-license-id u0))
